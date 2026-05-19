import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sdk.dart';
import '../../core/storage_presign.dart';
import 'child_session.dart';
import 'parent_session.dart';

final authActionsProvider = Provider<AuthActions>((ref) => AuthActions(ref));

class AuthActions {
  AuthActions(this.ref);

  final Ref ref;

  Future<void> signOut() async {
    await ref.read(parentSessionProvider.notifier).clear();
    await ref.read(childSessionProvider.notifier).clear();
    clearPresignStorageDownloadCache();
  }

  Future<void> parentSignIn({
    required String login,
    required String password,
    String? inviteToken,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) return;

    final data = await api.postJson(
      '/auth/sign-in',
      body: <String, dynamic>{
        'login': login.trim(),
        'password': password,
      },
    );

    final accessToken = data['accessToken']?.toString() ?? '';
    String familyId = (data['profile']?['familyId'] ?? '').toString();
    final token = (inviteToken ?? '').trim();
    if (token.isNotEmpty && accessToken.isNotEmpty) {
      final inviteRes = await api.postJson(
        '/auth/accept-invite',
        accessToken: accessToken,
        body: <String, dynamic>{'inviteToken': token},
      );
      familyId = (inviteRes['profile']?['familyId'] ?? familyId).toString();
    }

    await ref.read(parentSessionProvider.notifier).setSession(
          ParentSession(
            accessToken: accessToken,
            userId: (data['user']?['id'] ?? '').toString(),
            familyId: familyId,
            role: (data['profile']?['role'] ?? 'parent').toString(),
          ),
        );
  }

  Future<void> parentSignInByCode({
    required String code,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) return;
    final data = await api.postJson(
      '/auth/sign-in-code',
      body: <String, dynamic>{'code': code.trim()},
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
    required String phone,
    required String password,
    String? displayName,
    String? recoveryEmail,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) return;

    final data = await api.postJson(
      '/auth/sign-up',
      body: <String, dynamic>{
        'email': recoveryEmail?.trim(),
        'phone': phone.trim(),
        'password': password,
        'displayName': displayName?.trim(),
        'recoveryEmail': recoveryEmail?.trim(),
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

  Future<void> requestRecovery({
    required String phone,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) return;
    await api.postJson(
      '/auth/recover',
      body: <String, dynamic>{
        'phone': phone.trim(),
      },
    );
  }
}

