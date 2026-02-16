import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sdk.dart';
import 'app_role.dart';
import 'phone_utils.dart';

final authActionsProvider = Provider<AuthActions>((ref) => AuthActions());

class AuthActions {
  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }

  Future<void> parentSignIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) return;

    await client.auth.signInWithPassword(email: email.trim(), password: password);
    await _setRole(AppRole.parent);
  }

  Future<void> parentSignUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final client = _client;
    if (client == null) return;

    await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: <String, dynamic>{
        'display_name': displayName?.trim(),
        'app_role': AppRole.parent.key,
      },
    );
  }

  Future<void> childSignIn({
    required String phone,
    required String password,
  }) async {
    final client = _client;
    if (client == null) return;

    final email = kidsPseudoEmailFromPhone(phone);
    await client.auth.signInWithPassword(email: email, password: password);
    await _setRole(AppRole.child);
  }

  Future<void> _setRole(AppRole role) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.auth.updateUser(
        UserAttributes(data: <String, dynamic>{'app_role': role.key}),
      );
    } catch (e) {
      // Role metadata is a convenience for routing; don't break auth if it fails.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Auth] updateUser(app_role) failed: $e');
      }
    }
  }
}

