import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class Sdk {
  static SupabaseClient? get supabaseOrNull {
    if (!Env.hasSupabaseConfig) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

