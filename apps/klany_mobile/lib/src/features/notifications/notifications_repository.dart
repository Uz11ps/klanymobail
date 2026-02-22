import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sdk.dart';
import '../auth/child_session.dart';
import '../auth/parent_session.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref),
);

class InAppNotificationItem {
  InAppNotificationItem({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.payload,
  });

  final String id;
  final String type;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
}

class NotificationsRepository {
  NotificationsRepository(this.ref);
  final Ref ref;

  String? get _token {
    final p = ref.read(parentSessionProvider).asData?.value?.accessToken;
    if (p != null && p.isNotEmpty) return p;
    return ref.read(childSessionProvider).asData?.value?.accessToken;
  }

  Future<void> registerDevice({
    required String platform,
    required String pseudoPushToken,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson(
      '/notifications/devices/register',
      accessToken: token,
      body: <String, dynamic>{
        'platform': platform,
        'pushToken': pseudoPushToken,
      },
    );
  }

  Future<List<InAppNotificationItem>> listFamilyNotifications(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/notifications', accessToken: token);
    final rows = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return rows.map((row) {
      return InAppNotificationItem(
        id: row['id'].toString(),
        type: (row['nType'] ?? '').toString(),
        status: (row['isRead'] == true) ? 'read' : 'new',
        createdAt: DateTime.tryParse((row['createdAt'] ?? '').toString()) ?? DateTime.now(),
        payload: (row['payload'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      );
    }).toList();
  }

  Future<void> markRead(String id) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson('/notifications/$id/read', accessToken: token);
  }
}

