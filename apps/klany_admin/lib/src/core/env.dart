import 'package:flutter_dotenv/flutter_dotenv.dart';

const kDefaultApiBaseUrl = 'http://31.31.201.32:8782/api';

class Env {
  static String get supabaseUrl => (_read('SUPABASE_URL') ?? '').trim();
  static String get supabaseAnonKey => (_read('SUPABASE_ANON_KEY') ?? '').trim();
  static String get apiBaseUrl {
    final value = (_read('API_BASE_URL') ?? '').trim();
    return value.isEmpty ? kDefaultApiBaseUrl : value;
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

