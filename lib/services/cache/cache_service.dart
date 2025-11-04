import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Generic cache service for storing and retrieving data
class CacheService {
  static final CacheService _instance = CacheService._internal();
  static CacheService get instance => _instance;
  
  SharedPreferences? _prefs;
  
  CacheService._internal();

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<CacheService> getInstance() async {
    await _instance.initialize();
    return _instance;
  }

  /// Store string data in cache
  Future<bool> setString(String key, String value) async {
    try {
      await initialize();
      return await _prefs!.setString(key, value);
    } catch (e) {
      debugPrint('Error storing string in cache: $e');
      return false;
    }
  }

  /// Retrieve string data from cache
  String? getString(String key) {
    try {
      return _prefs?.getString(key);
    } catch (e) {
      debugPrint('Error retrieving string from cache: $e');
      return null;
    }
  }

  /// Store JSON data in cache
  Future<bool> setJson(String key, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      return await setString(key, jsonString);
    } catch (e) {
      debugPrint('Error storing JSON in cache: $e');
      return false;
    }
  }

  /// Retrieve JSON data from cache
  Map<String, dynamic>? getJson(String key) {
    try {
      final jsonString = getString(key);
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving JSON from cache: $e');
      return null;
    }
  }

  /// Store boolean data in cache
  Future<bool> setBool(String key, bool value) async {
    try {
      await initialize();
      return await _prefs!.setBool(key, value);
    } catch (e) {
      debugPrint('Error storing boolean in cache: $e');
      return false;
    }
  }

  /// Retrieve boolean data from cache
  bool? getBool(String key) {
    try {
      return _prefs?.getBool(key);
    } catch (e) {
      debugPrint('Error retrieving boolean from cache: $e');
      return null;
    }
  }

  /// Store integer data in cache
  Future<bool> setInt(String key, int value) async {
    try {
      await initialize();
      return await _prefs!.setInt(key, value);
    } catch (e) {
      debugPrint('Error storing integer in cache: $e');
      return false;
    }
  }

  /// Retrieve integer data from cache
  int? getInt(String key) {
    try {
      return _prefs?.getInt(key);
    } catch (e) {
      debugPrint('Error retrieving integer from cache: $e');
      return null;
    }
  }

  /// Store double data in cache
  Future<bool> setDouble(String key, double value) async {
    try {
      await initialize();
      return await _prefs!.setDouble(key, value);
    } catch (e) {
      debugPrint('Error storing double in cache: $e');
      return false;
    }
  }

  /// Retrieve double data from cache
  double? getDouble(String key) {
    try {
      return _prefs?.getDouble(key);
    } catch (e) {
      debugPrint('Error retrieving double from cache: $e');
      return null;
    }
  }

  /// Store list of strings in cache
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      await initialize();
      return await _prefs!.setStringList(key, value);
    } catch (e) {
      debugPrint('Error storing string list in cache: $e');
      return false;
    }
  }

  /// Retrieve list of strings from cache
  List<String>? getStringList(String key) {
    try {
      return _prefs?.getStringList(key);
    } catch (e) {
      debugPrint('Error retrieving string list from cache: $e');
      return null;
    }
  }

  /// Remove data from cache
  Future<bool> remove(String key) async {
    try {
      await initialize();
      return await _prefs!.remove(key);
    } catch (e) {
      debugPrint('Error removing data from cache: $e');
      return false;
    }
  }

  /// Clear all cache data
  Future<bool> clear() async {
    try {
      await initialize();
      return await _prefs!.clear();
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      return false;
    }
  }

  /// Check if key exists in cache
  bool containsKey(String key) {
    try {
      return _prefs?.containsKey(key) ?? false;
    } catch (e) {
      debugPrint('Error checking key existence in cache: $e');
      return false;
    }
  }

  /// Get all keys from cache
  Set<String> getKeys() {
    try {
      return _prefs?.getKeys() ?? <String>{};
    } catch (e) {
      debugPrint('Error getting keys from cache: $e');
      return <String>{};
    }
  }

  /// Store data with expiration time
  Future<bool> setWithExpiry(String key, String value, Duration expiry) async {
    try {
      final expiryTime = DateTime.now().add(expiry).millisecondsSinceEpoch;
      final data = {
        'value': value,
        'expiry': expiryTime,
      };
      return await setJson('${key}_expiry', data);
    } catch (e) {
      debugPrint('Error storing data with expiry: $e');
      return false;
    }
  }

  /// Retrieve data with expiration check
  String? getWithExpiry(String key) {
    try {
      final data = getJson('${key}_expiry');
      if (data != null) {
        final expiryTime = data['expiry'] as int;
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        
        if (currentTime < expiryTime) {
          return data['value'] as String;
        } else {
          // Data has expired, remove it
          remove('${key}_expiry');
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving data with expiry: $e');
      return null;
    }
  }
}