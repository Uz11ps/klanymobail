import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sdk.dart';
import 'device_identity.dart';

class ChildAccessPollResult {
  ChildAccessPollResult({
    required this.requestId,
    required this.status,
    this.familyId,
    this.childId,
    this.childDisplayName,
  });

  final String requestId;
  final String status;
  final String? familyId;
  final String? childId;
  final String? childDisplayName;
}

class ChildRestoreSessionResult {
  ChildRestoreSessionResult({
    required this.childId,
    required this.familyId,
    required this.childDisplayName,
  });

  final String childId;
  final String familyId;
  final String childDisplayName;
}

class PasswordlessChildRepository {
  SupabaseClient? get _client => Sdk.supabaseOrNull;

  Future<String> submitAccessRequest({
    required String familyCode,
    required String childFirstName,
    required String childLastName,
    required DeviceIdentity device,
  }) async {
    final client = _client;
    if (client == null) throw Exception('Supabase не настроен');

    final response = await client.rpc(
      'child_submit_access_request',
      params: <String, dynamic>{
        'p_family_code': familyCode.trim(),
        'p_child_first_name': childFirstName.trim(),
        'p_child_last_name': childLastName.trim(),
        'p_device_id': device.deviceId,
        'p_device_key': device.deviceKey,
      },
    );
    return response.toString();
  }

  Future<ChildAccessPollResult?> pollAccessRequest({
    required String requestId,
    required DeviceIdentity device,
  }) async {
    final client = _client;
    if (client == null) return null;

    final response = await client.rpc(
      'child_poll_access_request',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_device_id': device.deviceId,
        'p_device_key': device.deviceKey,
      },
    );

    if (response is! List || response.isEmpty) return null;
    final row = response.first as Map<String, dynamic>;

    return ChildAccessPollResult(
      requestId: row['request_id'].toString(),
      status: (row['status'] ?? '').toString(),
      familyId: row['family_id']?.toString(),
      childId: row['approved_child_id']?.toString(),
      childDisplayName: row['child_display_name']?.toString(),
    );
  }

  Future<ChildRestoreSessionResult?> restoreSession(DeviceIdentity device) async {
    final client = _client;
    if (client == null) return null;

    final response = await client.rpc(
      'child_restore_session',
      params: <String, dynamic>{
        'p_device_id': device.deviceId,
        'p_device_key': device.deviceKey,
      },
    );

    if (response is! List || response.isEmpty) return null;
    final row = response.first as Map<String, dynamic>;

    return ChildRestoreSessionResult(
      childId: row['child_id'].toString(),
      familyId: row['family_id'].toString(),
      childDisplayName: (row['child_display_name'] ?? '').toString(),
    );
  }
}

