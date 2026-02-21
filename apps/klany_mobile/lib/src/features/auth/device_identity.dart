import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentity {
  DeviceIdentity({
    required this.deviceId,
    required this.deviceKey,
  });

  final String deviceId;
  final String deviceKey;
}

class DeviceIdentityStore {
  static const _kDeviceId = 'device_id';
  static const _kDeviceKey = 'device_key';
  static const _uuid = Uuid();

  static Future<DeviceIdentity> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_kDeviceId);
    var deviceKey = prefs.getString(_kDeviceKey);

    if ((deviceId ?? '').isEmpty) {
      deviceId = _uuid.v4();
      await prefs.setString(_kDeviceId, deviceId);
    }
    if ((deviceKey ?? '').isEmpty) {
      deviceKey = _uuid.v4() + _uuid.v4();
      await prefs.setString(_kDeviceKey, deviceKey);
    }

    return DeviceIdentity(deviceId: deviceId!, deviceKey: deviceKey!);
  }
}

