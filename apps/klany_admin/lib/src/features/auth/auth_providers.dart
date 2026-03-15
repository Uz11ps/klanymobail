import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSession {
  const AdminSession({
    required this.accessToken,
    required this.userId,
    required this.role,
  });

  final String accessToken;
  final String userId;
  final String role;
}

const _kAccessToken = 'admin_access_token';
const _kUserId = 'admin_user_id';
const _kRole = 'admin_role';

final authSessionProvider = FutureProvider<AdminSession?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final accessToken = (prefs.getString(_kAccessToken) ?? '').trim();
  final userId = (prefs.getString(_kUserId) ?? '').trim();
  final role = (prefs.getString(_kRole) ?? '').trim();

  if (accessToken.isEmpty || userId.isEmpty || (role != 'admin' && role != 'parent')) {
    return null;
  }
  return AdminSession(accessToken: accessToken, userId: userId, role: role);
});

Future<void> saveAdminSession(
  WidgetRef ref, {
  required String accessToken,
  required String userId,
  required String role,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAccessToken, accessToken);
  await prefs.setString(_kUserId, userId);
  await prefs.setString(_kRole, role);
  ref.invalidate(authSessionProvider);
}

Future<void> clearAdminSession(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kAccessToken);
  await prefs.remove(_kUserId);
  await prefs.remove(_kRole);
  ref.invalidate(authSessionProvider);
}

