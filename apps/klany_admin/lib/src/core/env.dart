import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => (_read('SUPABASE_URL') ?? '').trim();
  static String get supabaseAnonKey => (_read('SUPABASE_ANON_KEY') ?? '').trim();

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static void validate() {
    if (!hasSupabaseConfig && kDebugMode) {
      // ignore: avoid_print
      print(
        '[Env] SUPABASE_URL / SUPABASE_ANON_KEY are empty. Admin runs in demo mode.',
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

