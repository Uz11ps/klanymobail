import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => (_read('SUPABASE_URL') ?? '').trim();
  static String get supabaseAnonKey => (_read('SUPABASE_ANON_KEY') ?? '').trim();
  static String get apiBaseUrl {
    final value = (_read('API_BASE_URL') ?? '').trim();
    return value.isEmpty ? 'https://klanymobail.ru/api' : value;
  }

  static bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static void validate() {
    if (!hasSupabaseConfig) {
      throw StateError('Missing SUPABASE_URL / SUPABASE_ANON_KEY in .env');
    }
  }

  static String? _read(String key) {
    // In tests (or if dotenv.load wasn't called yet) dotenv throws NotInitializedError.
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}

