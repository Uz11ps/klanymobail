import 'dart:async';

import '../../core/api_client.dart';
import '../../core/sdk.dart';
import 'device_identity.dart';

class ChildAccessPollResult {
  ChildAccessPollResult({
    required this.requestId,
    required this.status,
    this.familyId,
    this.childId,
    this.childDisplayName,
    this.accessToken,
    this.avatarObjectKey,
  });

  final String requestId;
  final String status;
  final String? familyId;
  final String? childId;
  final String? childDisplayName;
  final String? accessToken;
  final String? avatarObjectKey;
}

class ChildRestoreSessionResult {
  ChildRestoreSessionResult({
    required this.childId,
    required this.familyId,
    required this.childDisplayName,
    required this.accessToken,
    this.avatarObjectKey,
  });

  final String childId;
  final String familyId;
  final String childDisplayName;
  final String accessToken;
  final String? avatarObjectKey;
}

class PasswordlessChildRepository {
  Future<String> submitAccessRequest({
    required String phone,
    required String email,
    required String childFirstName,
    required String password,
    String? familyCode,
    String? parentContact,
    required DeviceIdentity device,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) throw Exception('API не настроен');

    final data = await api.postJson(
      '/child/access-request',
      body: <String, dynamic>{
        'phone': phone.trim(),
        'email': email.trim().toLowerCase(),
        'firstName': childFirstName.trim(),
        'password': password,
        if ((familyCode ?? '').trim().isNotEmpty)
          'familyCode': familyCode!.trim().toUpperCase(),
        if ((parentContact ?? '').trim().isNotEmpty)
          'parentContact': parentContact!.trim(),
        'deviceId': device.deviceId,
        'deviceKey': device.deviceKey,
      },
    );
    return (data['requestId'] ?? '').toString();
  }

  Future<ChildAccessPollResult?> pollAccessRequest({
    required String requestId,
    required DeviceIdentity device,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) return null;

    final data = await api.getJson(
      '/child/access-request/$requestId/poll',
      query: <String, String>{
        'deviceId': device.deviceId,
        'deviceKey': device.deviceKey,
      },
    );
    return ChildAccessPollResult(
      requestId: requestId,
      status: (data['status'] ?? '').toString(),
      familyId: data['familyId']?.toString(),
      childId: data['childId']?.toString(),
      childDisplayName: data['childDisplayName']?.toString(),
      accessToken: data['accessToken']?.toString(),
      avatarObjectKey: data['avatarObjectKey']?.toString(),
    );
  }

  Future<ChildRestoreSessionResult?> restoreSession(DeviceIdentity device) async {
    final api = Sdk.apiOrNull;
    if (api == null) return null;

    try {
      final data = await api.postJson(
        '/child/restore-session',
        body: <String, dynamic>{
          'deviceId': device.deviceId,
          'deviceKey': device.deviceKey,
        },
      );

      return ChildRestoreSessionResult(
        childId: (data['childId'] ?? '').toString(),
        familyId: (data['familyId'] ?? '').toString(),
        childDisplayName: (data['childDisplayName'] ?? '').toString(),
        accessToken: (data['accessToken'] ?? '').toString(),
        avatarObjectKey: data['avatarObjectKey']?.toString(),
      );
    } on TimeoutException {
      // Важно: [Future.timeout] на вызывающей стороне не отменяет HTTP — иначе позже
      // вылетает необработанный TimeoutException в зоне JS (Chrome).
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) rethrow;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ChildRestoreSessionResult> signInWithPassword({
    required String login,
    required String password,
    required DeviceIdentity device,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) throw Exception('API не настроен');

    final data = await api.postJson(
      '/child/sign-in',
      body: <String, dynamic>{
        'login': login.trim(),
        'password': password,
        'deviceId': device.deviceId,
        'deviceKey': device.deviceKey,
      },
    );

    return ChildRestoreSessionResult(
      childId: (data['childId'] ?? '').toString(),
      familyId: (data['familyId'] ?? '').toString(),
      childDisplayName: (data['childDisplayName'] ?? '').toString(),
      accessToken: (data['accessToken'] ?? '').toString(),
      avatarObjectKey: data['avatarObjectKey']?.toString(),
    );
  }

  Future<ChildRestoreSessionResult> signInWithAuthCode({
    required String authCode,
    required DeviceIdentity device,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) throw Exception('API не настроен');

    final data = await api.postJson(
      '/child/sign-in-code',
      body: <String, dynamic>{
        'authCode': authCode.trim(),
        'deviceId': device.deviceId,
        'deviceKey': device.deviceKey,
      },
    );

    return ChildRestoreSessionResult(
      childId: (data['childId'] ?? '').toString(),
      familyId: (data['familyId'] ?? '').toString(),
      childDisplayName: (data['childDisplayName'] ?? '').toString(),
      accessToken: (data['accessToken'] ?? '').toString(),
      avatarObjectKey: data['avatarObjectKey']?.toString(),
    );
  }

  Future<String?> getMyAuthCode({required String accessToken}) async {
    final api = Sdk.apiOrNull;
    if (api == null) return null;
    final data = await api.getJson(
      '/child/me/auth-code',
      accessToken: accessToken,
    );
    final code = (data['authCode'] ?? '').toString().trim();
    return code.isEmpty ? null : code;
  }
}

