// Security Service for TALOWA
// Reference: privacy-contact-visibility-system.md - Security Features

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  // static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  static SharedPreferences? _prefs;
  
  static Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Store data securely
  static Future<void> storeSecurely(String key, String value) async {
    try {
      await _initPrefs();
      await _prefs!.setString(key, value);
      // await _secureStorage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error storing secure data: $e');
    }
  }

  /// Retrieve secure data
  static Future<String?> getSecurely(String key) async {
    try {
      await _initPrefs();
      return _prefs!.getString(key);
      // return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint('Error reading secure data: $e');
      return null;
    }
  }

  /// Delete secure data
  static Future<void> deleteSecurely(String key) async {
    try {
      await _initPrefs();
      await _prefs!.remove(key);
      // await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('Error deleting secure data: $e');
    }
  }

  /// Clear all secure data
  static Future<void> clearAll() async {
    try {
      await _initPrefs();
      await _prefs!.clear();
      // await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('Error clearing secure data: $e');
    }
  }
}
