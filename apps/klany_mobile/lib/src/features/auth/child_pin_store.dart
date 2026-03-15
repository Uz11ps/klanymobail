import 'package:shared_preferences/shared_preferences.dart';

class ChildPinStore {
  static const _kPin = 'child_pin_code';

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_kPin) ?? '';
    return pin.length == 6;
  }

  static Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_kPin) ?? '') == pin;
  }

  static Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('PIN должен состоять из 6 цифр');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPin, pin);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPin);
  }
}
