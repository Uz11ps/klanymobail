import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentSession {
  ParentSession({
    required this.accessToken,
    required this.userId,
    required this.familyId,
    required this.role,
  });

  final String accessToken;
  final String userId;
  final String familyId;
  final String role; // parent/admin
}

final parentSessionProvider =
    AsyncNotifierProvider<ParentSessionNotifier, ParentSession?>(
  ParentSessionNotifier.new,
);

class ParentSessionNotifier extends AsyncNotifier<ParentSession?> {
  static const _kAccessToken = 'parent_access_token';
  static const _kUserId = 'parent_user_id';
  static const _kFamilyId = 'parent_family_id';
  static const _kRole = 'parent_role';

  @override
  Future<ParentSession?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAccessToken);
    final userId = prefs.getString(_kUserId);
    final familyId = prefs.getString(_kFamilyId);
    final role = prefs.getString(_kRole);
    if ((token ?? '').isEmpty ||
        (userId ?? '').isEmpty ||
        (familyId ?? '').isEmpty) {
      return null;
    }
    return ParentSession(
      accessToken: token!,
      userId: userId!,
      familyId: familyId!,
      role: (role ?? 'parent'),
    );
  }

  Future<void> setSession(ParentSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, session.accessToken);
    await prefs.setString(_kUserId, session.userId);
    await prefs.setString(_kFamilyId, session.familyId);
    await prefs.setString(_kRole, session.role);
    state = AsyncData(session);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kFamilyId);
    await prefs.remove(_kRole);
    state = const AsyncData(null);
  }
}

