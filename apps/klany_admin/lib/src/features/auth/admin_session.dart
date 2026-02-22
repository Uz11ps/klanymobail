import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSession {
  AdminSession({
    required this.accessToken,
    required this.userId,
    required this.role,
  });

  final String accessToken;
  final String userId;
  final String role; // admin
}

final adminSessionProvider =
    AsyncNotifierProvider<AdminSessionNotifier, AdminSession?>(
  AdminSessionNotifier.new,
);

class AdminSessionNotifier extends AsyncNotifier<AdminSession?> {
  static const _kAccessToken = 'admin_access_token';
  static const _kUserId = 'admin_user_id';
  static const _kRole = 'admin_role';

  @override
  Future<AdminSession?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAccessToken);
    final userId = prefs.getString(_kUserId);
    final role = prefs.getString(_kRole);
    if ((token ?? '').isEmpty || (userId ?? '').isEmpty) return null;
    return AdminSession(
      accessToken: token!,
      userId: userId!,
      role: (role ?? 'admin'),
    );
  }

  Future<void> setSession(AdminSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, session.accessToken);
    await prefs.setString(_kUserId, session.userId);
    await prefs.setString(_kRole, session.role);
    state = AsyncData(session);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kRole);
    state = const AsyncData(null);
  }
}

