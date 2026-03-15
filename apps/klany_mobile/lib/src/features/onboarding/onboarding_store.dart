import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  static const _kParentTourSeen = 'onboarding_parent_seen';
  static const _kChildTourSeen = 'onboarding_child_seen';

  static Future<bool> isParentTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kParentTourSeen) ?? false;
  }

  static Future<void> setParentTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kParentTourSeen, true);
  }

  static Future<bool> isChildTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kChildTourSeen) ?? false;
  }

  static Future<void> setChildTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kChildTourSeen, true);
  }
}
