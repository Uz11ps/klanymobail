import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sdk.dart';

class ParentFamilyContext {
  ParentFamilyContext({
    required this.familyId,
    required this.familyCode,
    this.clanName,
  });

  final String familyId;
  final String familyCode;
  final String? clanName;
}

class ChildAccessRequestItem {
  ChildAccessRequestItem({
    required this.id,
    required this.childFirstName,
    required this.childLastName,
    required this.deviceId,
    required this.createdAt,
  });

  final String id;
  final String childFirstName;
  final String childLastName;
  final String deviceId;
  final DateTime createdAt;
}

class ParentMemberItem {
  ParentMemberItem({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String role;
}

class ChildMemberItem {
  ChildMemberItem({
    required this.childId,
    required this.displayName,
    required this.isActive,
  });

  final String childId;
  final String displayName;
  final bool isActive;
}

final parentAccessRepositoryProvider = Provider<ParentAccessRepository>(
  (ref) => ParentAccessRepository(),
);

final parentFamilyContextProvider = FutureProvider<ParentFamilyContext?>((ref) async {
  return ref.read(parentAccessRepositoryProvider).getFamilyContext();
});

class ParentAccessRepository {
  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<ParentFamilyContext?> getFamilyContext() async {
    final client = _client;
    if (client == null) return null;

    final response = await client.rpc('parent_get_family_context');
    if (response is! List || response.isEmpty) return null;
    final row = response.first as Map<String, dynamic>;

    return ParentFamilyContext(
      familyId: row['family_id'].toString(),
      familyCode: row['family_code'].toString(),
      clanName: row['clan_name']?.toString(),
    );
  }

  Future<List<ChildAccessRequestItem>> getPendingRequests(String familyId) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('child_access_requests')
        .select('id, child_first_name, child_last_name, device_id, created_at')
        .eq('family_id', familyId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (rows as List<dynamic>).map((dynamic item) {
      final row = item as Map<String, dynamic>;
      return ChildAccessRequestItem(
        id: row['id'].toString(),
        childFirstName: row['child_first_name'].toString(),
        childLastName: row['child_last_name'].toString(),
        deviceId: row['device_id'].toString(),
        createdAt: DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now(),
      );
    }).toList();
  }

  Future<void> approveRequest(String requestId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_approve_child_request',
      params: <String, dynamic>{'p_request_id': requestId},
    );
  }

  Future<void> rejectRequest(String requestId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_reject_child_request',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_reason': 'Отклонено родителем',
      },
    );
  }

  Future<List<ParentMemberItem>> getParentMembers(String familyId) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('profiles')
        .select('user_id, display_name, role')
        .eq('family_id', familyId)
        .inFilter('role', ['parent', 'admin'])
        .order('created_at');

    return (rows as List<dynamic>).map((dynamic item) {
      final row = item as Map<String, dynamic>;
      return ParentMemberItem(
        userId: row['user_id'].toString(),
        displayName: (row['display_name'] ?? 'Без имени').toString(),
        role: row['role'].toString(),
      );
    }).toList();
  }

  Future<List<ChildMemberItem>> getChildren(String familyId) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('children')
        .select('id, display_name, is_active')
        .eq('family_id', familyId)
        .order('created_at');

    return (rows as List<dynamic>).map((dynamic item) {
      final row = item as Map<String, dynamic>;
      return ChildMemberItem(
        childId: row['id'].toString(),
        displayName: (row['display_name'] ?? '').toString(),
        isActive: row['is_active'] == true,
      );
    }).toList();
  }

  Future<String> createParentInvite(String email) async {
    final client = _client;
    if (client == null) throw Exception('Supabase не настроен');
    final token = await client.rpc(
      'parent_create_invite',
      params: <String, dynamic>{'p_email': email.trim().toLowerCase()},
    );
    return token.toString();
  }

  Future<void> acceptParentInvite(String token) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'accept_parent_invite',
      params: <String, dynamic>{'p_token': token.trim()},
    );
  }

  Future<void> grantAdmin(String targetUserId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_grant_admin',
      params: <String, dynamic>{'p_target_user_id': targetUserId},
    );
  }

  Future<void> revokeChildDevices(String childId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_revoke_child_devices',
      params: <String, dynamic>{'p_child_id': childId},
    );
  }

  Future<void> deactivateChild(String childId) async {
    final client = _client;
    if (client == null) return;
    await client.rpc(
      'parent_deactivate_child',
      params: <String, dynamic>{'p_child_id': childId},
    );
  }
}

