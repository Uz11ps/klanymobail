import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_identity.dart';
import 'passwordless_child_repository.dart';

class ChildSession {
  ChildSession({
    required this.childId,
    required this.familyId,
    required this.childDisplayName,
    required this.accessToken,
  });

  final String childId;
  final String familyId;
  final String childDisplayName;
  final String accessToken;
}

final passwordlessChildRepositoryProvider = Provider<PasswordlessChildRepository>(
  (ref) => PasswordlessChildRepository(),
);

final childSessionProvider =
    AsyncNotifierProvider<ChildSessionNotifier, ChildSession?>(
  ChildSessionNotifier.new,
);

class ChildSessionNotifier extends AsyncNotifier<ChildSession?> {
  static const _kChildId = 'child_session_child_id';
  static const _kFamilyId = 'child_session_family_id';
  static const _kChildDisplayName = 'child_session_child_display_name';
  static const _kAccessToken = 'child_session_access_token';

  @override
  Future<ChildSession?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final savedChildId = prefs.getString(_kChildId);
    final savedFamilyId = prefs.getString(_kFamilyId);
    final savedDisplayName = prefs.getString(_kChildDisplayName);
    final savedAccessToken = prefs.getString(_kAccessToken);

    if ((savedChildId ?? '').isNotEmpty &&
        (savedFamilyId ?? '').isNotEmpty &&
        (savedAccessToken ?? '').isNotEmpty) {
      return ChildSession(
        childId: savedChildId!,
        familyId: savedFamilyId!,
        childDisplayName: savedDisplayName ?? '',
        accessToken: savedAccessToken!,
      );
    }

    final device = await DeviceIdentityStore.getOrCreate();
    final restored = await ref
        .read(passwordlessChildRepositoryProvider)
        .restoreSession(device);
    if (restored == null) return null;

    final session = ChildSession(
      childId: restored.childId,
      familyId: restored.familyId,
      childDisplayName: restored.childDisplayName,
      accessToken: restored.accessToken,
    );
    await _save(session);
    return session;
  }

  Future<void> activateFromApproval({
    required String childId,
    required String familyId,
    required String childDisplayName,
    required String accessToken,
  }) async {
    final session = ChildSession(
      childId: childId,
      familyId: familyId,
      childDisplayName: childDisplayName,
      accessToken: accessToken,
    );
    await _save(session);
    state = AsyncData(session);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kChildId);
    await prefs.remove(_kFamilyId);
    await prefs.remove(_kChildDisplayName);
    await prefs.remove(_kAccessToken);
    state = const AsyncData(null);
  }

  Future<bool> validateStillActive() async {
    final device = await DeviceIdentityStore.getOrCreate();
    final restored = await ref
        .read(passwordlessChildRepositoryProvider)
        .restoreSession(device);
    if (restored == null) {
      await clear();
      return false;
    }

    final current = state.asData?.value;
    if (current == null || current.childId != restored.childId) {
      await activateFromApproval(
        childId: restored.childId,
        familyId: restored.familyId,
        childDisplayName: restored.childDisplayName,
        accessToken: restored.accessToken,
      );
    }
    return true;
  }

  Future<void> _save(ChildSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kChildId, session.childId);
    await prefs.setString(_kFamilyId, session.familyId);
    await prefs.setString(_kChildDisplayName, session.childDisplayName);
    await prefs.setString(_kAccessToken, session.accessToken);
  }
}

