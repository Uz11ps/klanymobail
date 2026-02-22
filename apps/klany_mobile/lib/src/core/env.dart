import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl => (_read('API_BASE_URL') ?? '').trim();

  static String get kidsEmailDomain =>
      ((_read('KIDS_EMAIL_DOMAIN') ?? '').trim().isNotEmpty)
          ? (_read('KIDS_EMAIL_DOMAIN') ?? '').trim()
          : 'kids.klany.local';

  static bool get hasApiConfig => apiBaseUrl.isNotEmpty;

  static void validate() {
    // In debug we warn loudly; in release we just allow demo mode.
    if (!hasApiConfig && kDebugMode) {
      // ignore: avoid_print
      print(
        '[Env] API_BASE_URL is empty. App runs in demo mode.',
      );
    }
  }

  static String? _read(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      // In tests dotenv may be not initialized.
      return null;
    }
  }
}

