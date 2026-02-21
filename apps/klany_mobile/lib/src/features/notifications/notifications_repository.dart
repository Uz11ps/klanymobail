import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sdk.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(),
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
  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<void> registerDevice({
    String? userId,
    String? childId,
    required String platform,
    required String pseudoPushToken,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.from('notification_devices').upsert(
      <String, dynamic>{
        'user_id': userId,
        'child_id': childId,
        'platform': platform,
        'push_token': pseudoPushToken,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'push_token',
    );
  }

  Future<List<InAppNotificationItem>> listFamilyNotifications(String familyId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('notifications')
        .select('id, n_type, status, payload, created_at')
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List<dynamic>)
        .map((dynamic e) => e as Map<String, dynamic>)
        .map(
          (row) => InAppNotificationItem(
            id: row['id'].toString(),
            type: (row['n_type'] ?? '').toString(),
            status: (row['status'] ?? '').toString(),
            createdAt:
                DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                    DateTime.now(),
            payload:
                (row['payload'] as Map<String, dynamic>? ?? <String, dynamic>{}),
          ),
        )
        .toList();
  }

  Future<void> markRead(String id) async {
    final client = _client;
    if (client == null) return;
    await client
        .from('notifications')
        .update(<String, dynamic>{'status': 'read'})
        .eq('id', id);
  }
}

