import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sdk.dart';
import 'child_session.dart';
import 'parent_session.dart';

final authActionsProvider = Provider<AuthActions>((ref) => AuthActions(ref));

class AuthActions {
  AuthActions(this.ref);

  final Ref ref;

  Future<void> signOut() async {
    await ref.read(parentSessionProvider.notifier).clear();
    await ref.read(childSessionProvider.notifier).clear();
  }

  Future<void> parentSignIn({
    required String email,
    required String password,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) return;

    final data = await api.postJson(
      '/auth/sign-in',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
      },
    );
    await ref.read(parentSessionProvider.notifier).setSession(
          ParentSession(
            accessToken: data['accessToken']?.toString() ?? '',
            userId: (data['user']?['id'] ?? '').toString(),
            familyId: (data['profile']?['familyId'] ?? '').toString(),
            role: (data['profile']?['role'] ?? 'parent').toString(),
          ),
        );
  }

  Future<void> parentSignUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) return;

    final data = await api.postJson(
      '/auth/sign-up',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'displayName': displayName?.trim(),
      },
    );
    await ref.read(parentSessionProvider.notifier).setSession(
          ParentSession(
            accessToken: data['accessToken']?.toString() ?? '',
            userId: (data['user']?['id'] ?? '').toString(),
            familyId: (data['profile']?['familyId'] ?? '').toString(),
            role: (data['profile']?['role'] ?? 'parent').toString(),
          ),
        );
  }
}

