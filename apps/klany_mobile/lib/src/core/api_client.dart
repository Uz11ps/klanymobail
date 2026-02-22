import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final Object? body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl;

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
    final res = await http.get(
      _uri(path, query),
      headers: <String, String>{
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    String? accessToken,
    Map<String, String>? query,
    Object? body,
  }) async {
    final res = await http.post(
      _uri(path, query),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body ?? <String, dynamic>{}),
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
    throw ApiException(res.statusCode, parsed);
  }
}

