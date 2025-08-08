// Security Service for TALOWA
// Reference: privacy-contact-visibility-system.md - Security Features

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Store data securely
  static Future<void> storeSecurely(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error storing secure data: $e');
    }
  }

  /// Retrieve secure data
  static Future<String?> getSecurely(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint('Error reading secure data: $e');
      return null;
    }
  }

  /// Delete secure data
  static Future<void> deleteSecurely(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('Error deleting secure data: $e');
    }
  }

  /// Clear all secure data
  static Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('Error clearing secure data: $e');
    }
  }
}