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
  });

  final String requestId;
  final String status;
  final String? familyId;
  final String? childId;
  final String? childDisplayName;
  final String? accessToken;
}

class ChildRestoreSessionResult {
  ChildRestoreSessionResult({
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

class PasswordlessChildRepository {
  Future<String> submitAccessRequest({
    required String familyCode,
    required String childFirstName,
    required String childLastName,
    required DeviceIdentity device,
  }) async {
    final api = Sdk.apiOrNull;
    if (api == null) throw Exception('API не настроен');

    final data = await api.postJson(
      '/child/access-request',
      body: <String, dynamic>{
        'familyCode': familyCode.trim(),
        'firstName': childFirstName.trim(),
        'lastName': childLastName.trim(),
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
    );
  }

  Future<ChildRestoreSessionResult?> restoreSession(DeviceIdentity device) async {
    final api = Sdk.apiOrNull;
    if (api == null) return null;

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
    );
  }
}

