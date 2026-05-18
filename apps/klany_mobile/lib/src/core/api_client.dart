import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final Object? body;

  /// Сообщение из тела ответа (без HTTP-кода, без stack trace).
  String get message {
    final b = body;
    String? raw;
    if (b is Map) {
      final m = b['message'];
      if (m is String) {
        raw = m;
      } else if (m is List && m.isNotEmpty) {
        raw = m.first.toString();
      }
      raw ??= b['error']?.toString();
    } else if (b is String && b.isNotEmpty) {
      raw = b;
    }
    raw = (raw ?? '').trim();
    return _friendly(raw);
  }

  /// Перевод типовых API-сообщений на понятный русский.
  String _friendly(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('пользователь уже существует') ||
        lower.contains('user already exists') ||
        lower.contains('email already') ||
        lower.contains('already registered') ||
        statusCode == 409) {
      return 'Этот email уже зарегистрирован. Войдите или используйте другой.';
    }
    if (lower.contains('invalid credentials') ||
        lower.contains('invalid login') ||
        lower.contains('неверн') && lower.contains('парол')) {
      return 'Неверный email или пароль.';
    }
    if (lower.contains('not found') || statusCode == 404) {
      return 'Не найдено.';
    }
    if (lower.contains('unauthorized') || statusCode == 401) {
      return 'Нужно войти заново.';
    }
    if (lower.contains('forbidden') || statusCode == 403) {
      return 'Доступ запрещён.';
    }
    if (lower.contains('validation') || lower.contains('bad request')) {
      return raw.isEmpty ? 'Проверьте введённые данные.' : raw;
    }
    if (statusCode >= 500) {
      return 'Сервер временно недоступен. Попробуйте позже.';
    }
    return raw.isEmpty ? 'Что-то пошло не так. Попробуйте ещё раз.' : raw;
  }

  @override
  String toString() => message;
}

typedef ApiUnauthorizedCallback = Future<void> Function();

class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 4);

  /// Реакция на 401: разлогин и переход на лендинг. Ставится из корня приложения.
  static ApiUnauthorizedCallback? onUnauthorized;

  static bool _unauthorizedBusy = false;

  /// Запросы вне ApiClient (presigned PUT и т.п.): при 401 — та же реакция.
  static void notifyUnauthorizedFromStatusCode(int statusCode) {
    if (statusCode == 401) {
      _scheduleUnauthorized();
    }
  }

  static void _scheduleUnauthorized() {
    final cb = onUnauthorized;
    if (cb == null || _unauthorizedBusy) return;
    _unauthorizedBusy = true;
    scheduleMicrotask(() async {
      try {
        await cb();
      } catch (_) {
      } finally {
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          _unauthorizedBusy = false;
        });
      }
    });
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse(baseUrl).replace(
      path: '${Uri.parse(baseUrl).path}$p',
      queryParameters: query?.isEmpty == true ? null : query,
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
    Map<String, String>? query,
  }) async {
    final res = await http
        .get(
          _uri(path, query),
          headers: <String, String>{
            if (accessToken != null && accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(
          _timeout,
          onTimeout: () => throw TimeoutException('network_timeout'),
        );
    return _decode(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    String? accessToken,
    Map<String, String>? query,
    Object? body,
  }) async {
    final res = await http
        .post(
          _uri(path, query),
          headers: <String, String>{
            'Content-Type': 'application/json',
            if (accessToken != null && accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(
          _timeout,
          onTimeout: () => throw TimeoutException('network_timeout'),
        );
    return _decode(res);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    String? accessToken,
    Map<String, String>? query,
    Object? body,
  }) async {
    final res = await http
        .patch(
          _uri(path, query),
          headers: <String, String>{
            'Content-Type': 'application/json',
            if (accessToken != null && accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(
          _timeout,
          onTimeout: () => throw TimeoutException('network_timeout'),
        );
    return _decode(res);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? accessToken,
    Map<String, String>? query,
    Object? body,
  }) async {
    final res = await http
        .delete(
          _uri(path, query),
          headers: <String, String>{
            'Content-Type': 'application/json',
            if (accessToken != null && accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(
          _timeout,
          onTimeout: () => throw TimeoutException('network_timeout'),
        );
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final text = res.body;
    Object? parsed;
    try {
      parsed = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      parsed = text;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (parsed is Map<String, dynamic>) return parsed;
      return <String, dynamic>{'data': parsed};
    }
    if (res.statusCode == 401) {
      _scheduleUnauthorized();
    }
    throw ApiException(res.statusCode, parsed);
  }
}
