import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sdk.dart';
import 'parent_session.dart';

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
  (ref) => ParentAccessRepository(ref),
);

final parentFamilyContextProvider = FutureProvider<ParentFamilyContext?>((ref) async {
  return ref.read(parentAccessRepositoryProvider).getFamilyContext();
});

class ParentAccessRepository {
  ParentAccessRepository(this.ref);
  final Ref ref;

  String? get _token => ref.read(parentSessionProvider).asData?.value?.accessToken;
  String? get _familyId => ref.read(parentSessionProvider).asData?.value?.familyId;

  Future<ParentFamilyContext?> getFamilyContext() async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return null;

    final data = await api.getJson('/family/context', accessToken: token);
    return ParentFamilyContext(
      familyId: (data['familyId'] ?? _familyId ?? '').toString(),
      familyCode: (data['familyCode'] ?? '').toString(),
      clanName: data['clanName']?.toString(),
    );
  }

  Future<List<ChildAccessRequestItem>> getPendingRequests(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return const [];

    final data = await api.getJson('/parent/access-requests', accessToken: token);
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return items.map((row) {
      return ChildAccessRequestItem(
        id: row['id'].toString(),
        childFirstName: (row['firstName'] ?? '').toString(),
        childLastName: (row['lastName'] ?? '').toString(),
        deviceId: (row['deviceId'] ?? '').toString(),
        createdAt: DateTime.tryParse((row['createdAt'] ?? '').toString()) ?? DateTime.now(),
      );
    }).toList();
  }

  Future<void> approveRequest(String requestId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson('/parent/access-requests/$requestId/approve', accessToken: token);
  }

  Future<void> rejectRequest(String requestId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson(
      '/parent/access-requests/$requestId/reject',
      accessToken: token,
      body: <String, dynamic>{'reason': 'Отклонено родителем'},
    );
  }

  Future<List<ParentMemberItem>> getParentMembers(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return const [];

    final data = await api.getJson('/parent/members', accessToken: token);
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return items.map((row) {
      return ParentMemberItem(
        userId: row['userId'].toString(),
        displayName: (row['displayName'] ?? 'Без имени').toString(),
        role: row['role'].toString(),
      );
    }).toList();
  }

  Future<List<ChildMemberItem>> getChildren(String familyId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return const [];

    final data = await api.getJson('/parent/children', accessToken: token);
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return items.map((row) {
      return ChildMemberItem(
        childId: row['childId'].toString(),
        displayName: (row['displayName'] ?? '').toString(),
        isActive: row['isActive'] == true,
      );
    }).toList();
  }

  Future<String> createParentInvite(String email) async {
    throw UnimplementedError('Инвайты будут добавлены следующим шагом');
  }

  Future<void> acceptParentInvite(String token) async {
    throw UnimplementedError('Инвайты будут добавлены следующим шагом');
  }

  Future<void> grantAdmin(String targetUserId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson(
      '/parent/grant-admin',
      accessToken: token,
      body: <String, dynamic>{'targetUserId': targetUserId},
    );
  }

  Future<void> revokeChildDevices(String childId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson('/parent/children/$childId/revoke-devices', accessToken: token);
  }

  Future<void> deactivateChild(String childId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson('/parent/children/$childId/deactivate', accessToken: token);
  }
}

