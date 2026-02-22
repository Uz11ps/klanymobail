import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl {
    final raw = (_read('API_BASE_URL') ?? '').trim();
    if (raw.isNotEmpty) return raw;
    // Для прод-деплоя через nginx используем same-origin прокси.
    if (kIsWeb) return '/api';
    return '';
  }

  static bool get hasApiConfig => apiBaseUrl.isNotEmpty;

  static void validate() {
    if (!hasApiConfig && kDebugMode) {
      // ignore: avoid_print
      print(
        '[Env] API_BASE_URL is empty. Admin runs in demo mode.',
      );
    }
  }

  static String? _read(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}

