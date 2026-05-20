import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/sdk.dart';
import '../../core/storage_presign.dart';
import 'parent_session.dart';

class ParentFamilyContext {
  ParentFamilyContext({
    required this.familyId,
    required this.familyCode,
    this.clanName,
    required this.goalAmount,
  });

  final String familyId;
  final String familyCode;
  final String? clanName;
  final int goalAmount;
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
    this.avatarObjectKey,
    this.avatarImageUrl,
  });

  final String childId;
  final String displayName;
  final bool isActive;
  final String? avatarObjectKey;
  final String? avatarImageUrl;
}

class FamilyMemberCodeItem {
  FamilyMemberCodeItem({
    required this.id,
    required this.role,
    required this.code,
    required this.displayName,
    required this.isActive,
    required this.createdAt,
    this.avatarObjectKey,
    this.avatarImageUrl,
  });

  final String id;
  final String role;
  final String code;
  final String displayName;
  final bool isActive;
  final DateTime createdAt;
  final String? avatarObjectKey;
  final String? avatarImageUrl;
}

String familyMemberTypeLabel(String value) {
  switch (value) {
    case 'mom':
      return 'Мама';
    case 'child':
      return 'Ребёнок';
    case 'grandma':
      return 'Бабушка';
    case 'grandpa':
      return 'Дедушка';
    case 'parent':
      return 'Взрослый';
    default:
      return value;
  }
}

final parentAccessRepositoryProvider = Provider<ParentAccessRepository>(
  (ref) => ParentAccessRepository(ref),
);

final parentFamilyContextProvider = FutureProvider<ParentFamilyContext?>((ref) async {
  return ref.read(parentAccessRepositoryProvider).getFamilyContext();
});

class ParentAccessRepository {
  static const _uuid = Uuid();

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
      goalAmount: (data['goalAmount'] as num?)?.toInt() ?? 10000,
    );
  }

  /// Имя родителя в семье (поле профиля `displayName` на сервере).
  Future<void> updateMyProfileDisplayName(String displayName) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) throw Exception('Не авторизован');
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) throw Exception('Введите имя');
    await api.patchJson(
      '/parent/me/profile',
      accessToken: token,
      body: <String, dynamic>{'displayName': trimmed},
    );
  }

  Future<void> setFamilyGoal(int goalAmount) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.postJson(
      '/family/goal',
      accessToken: token,
      body: <String, dynamic>{'goalAmount': goalAmount},
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
        displayName: (row['displayName'] ?? 'Родитель').toString(),
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
    return Future.wait(
      items.map((row) async {
        final objectKey = row['avatarObjectKey']?.toString();
        final avatarImageUrl = (objectKey != null && objectKey.isNotEmpty)
            ? await presignStorageDownload(
                accessToken: token,
                bucket: 'member-avatars',
                objectKey: objectKey,
              )
            : null;
        return ChildMemberItem(
          childId: row['childId'].toString(),
          displayName: (row['displayName'] ?? '').toString(),
          isActive: row['isActive'] == true,
          avatarObjectKey: objectKey,
          avatarImageUrl: avatarImageUrl,
        );
      }),
    );
  }

  Future<Map<String, dynamic>> getChildProfile(String childId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return <String, dynamic>{};
    return api.getJson('/parent/children/$childId/profile', accessToken: token);
  }

  Future<Map<String, dynamic>> getPremiumAnalytics({int periodDays = 30}) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return <String, dynamic>{};
    try {
      return await api.getJson(
        '/parent/analytics',
        accessToken: token,
        query: <String, String>{'periodDays': periodDays.toString()},
      );
    } catch (_) {
      // Опциональный блок UI (403 без роли parent/admin, сеть, таймаут).
      return <String, dynamic>{};
    }
  }

  Future<String> createParentInvite(String email) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) throw Exception('Не авторизован');
    final data = await api.postJson(
      '/parent/invite',
      accessToken: token,
      body: <String, dynamic>{'email': email},
    );
    final inviteToken = data['token']?.toString() ?? data['inviteToken']?.toString();
    if (inviteToken == null || inviteToken.isEmpty) {
      throw Exception('Сервер не вернул токен приглашения');
    }
    return inviteToken;
  }

  Future<void> acceptParentInvite(String token) async {
    final api = Sdk.apiOrNull;
    final accessToken = _token;
    if (api == null || accessToken == null) throw Exception('Не авторизован');
    await api.postJson(
      '/parent/invite/accept',
      accessToken: accessToken,
      body: <String, dynamic>{'token': token},
    );
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

  Future<void> deleteChild(String childId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return;
    await api.deleteJson('/parent/children/$childId', accessToken: token);
  }

  Future<List<FamilyMemberCodeItem>> getFamilyMemberCodes() async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) return const [];
    final data = await api.getJson('/parent/member-codes', accessToken: token);
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return Future.wait(
      items.map((row) async {
        final objectKey = row['avatarObjectKey']?.toString();
        final avatarImageUrl = (objectKey != null && objectKey.isNotEmpty)
            ? await presignStorageDownload(
                accessToken: token,
                bucket: 'member-avatars',
                objectKey: objectKey,
              )
            : null;
        return FamilyMemberCodeItem(
          id: (row['id'] ?? '').toString(),
          role: (row['role'] ?? '').toString(),
          code: (row['code'] ?? '').toString(),
          displayName: (row['displayName'] ?? '').toString(),
          isActive: row['isActive'] != false,
          createdAt: DateTime.tryParse((row['createdAt'] ?? '').toString()) ?? DateTime.now(),
          avatarObjectKey: objectKey,
          avatarImageUrl: avatarImageUrl,
        );
      }),
    );
  }

  /// Загружает фото в MinIO и сохраняет ключ в профиле ребёнка / взрослого по коду участника.
  Future<void> uploadMemberCodeAvatar({
    required String familyId,
    required String memberCodeId,
    required XFile imageFile,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) throw Exception('Не авторизован');

    final Uint8List bytes = await imageFile.readAsBytes();
    var ext = imageFile.path.split('.').last.toLowerCase();
    if (ext.length > 5) ext = 'jpg';
    final key =
        'avatars/families/$familyId/members/$memberCodeId/${_uuid.v4()}.$ext';

    final presign = await api.postJson(
      '/storage/presign-upload',
      accessToken: token,
      body: <String, dynamic>{
        'bucket': 'member-avatars',
        'objectKey': key,
      },
    );
    final url = presign['url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Не удалось получить ссылку загрузки');

    final put = await http.put(Uri.parse(url), body: bytes);
    ApiClient.notifyUnauthorizedFromStatusCode(put.statusCode);
    if (put.statusCode < 200 || put.statusCode >= 300) {
      throw Exception('Загрузка файла: ${put.statusCode}');
    }

    await api.patchJson(
      '/parent/member-codes/$memberCodeId/avatar',
      accessToken: token,
      body: <String, dynamic>{'objectKey': key},
    );
  }

  /// Пресет из assets: загружает PNG на сервер.
  Future<void> uploadMemberCodeAvatarFromAsset({
    required String familyId,
    required String memberCodeId,
    required Uint8List pngBytes,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) throw Exception('Не авторизован');

    final key =
        'avatars/families/$familyId/members/$memberCodeId/${_uuid.v4()}.png';
    final presign = await api.postJson(
      '/storage/presign-upload',
      accessToken: token,
      body: <String, dynamic>{
        'bucket': 'member-avatars',
        'objectKey': key,
      },
    );
    final url = presign['url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Не удалось получить ссылку загрузки');

    final put = await http.put(Uri.parse(url), body: pngBytes);
    ApiClient.notifyUnauthorizedFromStatusCode(put.statusCode);
    if (put.statusCode < 200 || put.statusCode >= 300) {
      throw Exception('Загрузка файла: ${put.statusCode}');
    }

    await api.patchJson(
      '/parent/member-codes/$memberCodeId/avatar',
      accessToken: token,
      body: <String, dynamic>{'objectKey': key},
    );
  }

  Future<FamilyMemberCodeItem> _familyCodeItemFromResponse(
    Map<String, dynamic> data,
  ) async {
    final token = _token;
    final objectKey = data['avatarObjectKey']?.toString();
    final avatarImageUrl =
        (token != null && objectKey != null && objectKey.isNotEmpty)
        ? await presignStorageDownload(
            accessToken: token,
            bucket: 'member-avatars',
            objectKey: objectKey,
          )
        : null;
    return FamilyMemberCodeItem(
      id: (data['id'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      code: (data['code'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
      isActive: data['isActive'] != false,
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '').toString()) ?? DateTime.now(),
      avatarObjectKey: objectKey,
      avatarImageUrl: avatarImageUrl,
    );
  }

  Future<FamilyMemberCodeItem> createFamilyMemberCode({
    required String memberType,
    required String displayName,
  }) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) {
      throw Exception('API не настроен');
    }
    final data = await api.postJson(
      '/parent/member-codes',
      accessToken: token,
      body: <String, dynamic>{
        'memberType': memberType,
        'displayName': displayName.trim(),
      },
    );
    return _familyCodeItemFromResponse(data);
  }

  Future<FamilyMemberCodeItem> regenerateFamilyMemberCode(String codeId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) throw Exception('API не настроен');
    final data = await api.postJson(
      '/parent/member-codes/$codeId/regenerate',
      accessToken: token,
    );
    return _familyCodeItemFromResponse(data);
  }

  Future<void> deactivateFamilyMemberCode(String codeId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) throw Exception('API не настроен');
    await api.postJson('/parent/member-codes/$codeId/deactivate', accessToken: token);
  }

  Future<void> deleteFamilyMemberCode(String codeId) async {
    final api = Sdk.apiOrNull;
    final token = _token;
    if (api == null || token == null) throw Exception('API не настроен');
    await api.deleteJson('/parent/member-codes/$codeId', accessToken: token);
  }
}

