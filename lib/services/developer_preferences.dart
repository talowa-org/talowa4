import 'package:shared_preferences/shared_preferences.dart';

class DeveloperPreferences {
  static const _keyDeveloperMode = 'developer_mode_enabled';

  static Future<bool> isDeveloperMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyDeveloperMode) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setDeveloperMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDeveloperMode, enabled);
    } catch (_) {
      // ignore
    }
  }
}

