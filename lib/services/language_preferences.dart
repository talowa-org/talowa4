// Language Preferences Service for TALOWA
// Handles persistent storage of user language preferences

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguagePreferences {
  static const String _languageKey = 'selected_language';
  static const String _firstLaunchKey = 'first_launch_completed';
  static const String _languageChangeCountKey = 'language_change_count';
  static const String _lastLanguageChangeKey = 'last_language_change';
  
  static const String defaultLanguage = 'en';
  static const int maxLanguageChangesPerDay = 10;
  
  /// Initialize language preferences
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if this is the first launch
      final isFirstLaunch = !prefs.containsKey(_firstLaunchKey);
      
      if (isFirstLaunch) {
        await _setFirstLaunchDefaults(prefs);
      }
      
      // Clean up old change count if it's a new day
      await _cleanupOldChangeCount(prefs);
      
      debugPrint('LanguagePreferences initialized successfully');
    } catch (e) {
      debugPrint('Error initializing LanguagePreferences: $e');
    }
  }
  
  /// Get the saved language preference
  static Future<String> getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageKey) ?? defaultLanguage;
    } catch (e) {
      debugPrint('Error getting language preference: $e');
      return defaultLanguage;
    }
  }
  
  /// Save language preference
  static Future<bool> setLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check rate limiting
      if (!await _canChangeLanguage(prefs)) {
        debugPrint('Language change rate limit exceeded');
        return false;
      }
      
      // Save the language
      final success = await prefs.setString(_languageKey, languageCode);
      
      if (success) {
        // Record the change
        await _recordLanguageChange(prefs);
        debugPrint('Language preference saved: $languageCode');
      }
      
      return success;
    } catch (e) {
      debugPrint('Error saving language preference: $e');
      return false;
    }
  }
  
  /// Check if language has been set before
  static Future<bool> hasLanguageBeenSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_languageKey);
    } catch (e) {
      debugPrint('Error checking language preference: $e');
      return false;
    }
  }
  
  /// Get language change statistics
  static Future<Map<String, dynamic>> getLanguageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'current_language': prefs.getString(_languageKey) ?? defaultLanguage,
        'changes_today': prefs.getInt(_languageChangeCountKey) ?? 0,
        'last_change': prefs.getString(_lastLanguageChangeKey),
        'first_launch_completed': prefs.getBool(_firstLaunchKey) ?? false,
      };
    } catch (e) {
      debugPrint('Error getting language stats: $e');
      return {
        'current_language': defaultLanguage,
        'changes_today': 0,
        'last_change': null,
        'first_launch_completed': false,
      };
    }
  }
  
  /// Reset language preferences (for testing or troubleshooting)
  static Future<bool> resetPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_languageKey);
      await prefs.remove(_languageChangeCountKey);
      await prefs.remove(_lastLanguageChangeKey);
      await prefs.remove(_firstLaunchKey);
      
      debugPrint('Language preferences reset successfully');
      return true;
    } catch (e) {
      debugPrint('Error resetting language preferences: $e');
      return false;
    }
  }
  
  /// Validate language code
  static bool isValidLanguageCode(String languageCode) {
    const validLanguages = ['en', 'hi', 'te', 'ur', 'ar'];
    return validLanguages.contains(languageCode);
  }
  
  /// Set defaults for first launch
  static Future<void> _setFirstLaunchDefaults(SharedPreferences prefs) async {
    try {
      await prefs.setString(_languageKey, defaultLanguage);
      await prefs.setBool(_firstLaunchKey, true);
      await prefs.setInt(_languageChangeCountKey, 0);
      
      debugPrint('First launch defaults set');
    } catch (e) {
      debugPrint('Error setting first launch defaults: $e');
    }
  }
  
  /// Check if user can change language (rate limiting)
  static Future<bool> _canChangeLanguage(SharedPreferences prefs) async {
    try {
      final changesCount = prefs.getInt(_languageChangeCountKey) ?? 0;
      return changesCount < maxLanguageChangesPerDay;
    } catch (e) {
      debugPrint('Error checking language change limit: $e');
      return true; // Allow change if there's an error
    }
  }
  
  /// Record a language change
  static Future<void> _recordLanguageChange(SharedPreferences prefs) async {
    try {
      final currentCount = prefs.getInt(_languageChangeCountKey) ?? 0;
      await prefs.setInt(_languageChangeCountKey, currentCount + 1);
      await prefs.setString(_lastLanguageChangeKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error recording language change: $e');
    }
  }
  
  /// Clean up old change count if it's a new day
  static Future<void> _cleanupOldChangeCount(SharedPreferences prefs) async {
    try {
      final lastChangeStr = prefs.getString(_lastLanguageChangeKey);
      
      if (lastChangeStr != null) {
        final lastChange = DateTime.parse(lastChangeStr);
        final now = DateTime.now();
        
        // If it's a new day, reset the count
        if (now.day != lastChange.day || 
            now.month != lastChange.month || 
            now.year != lastChange.year) {
          await prefs.setInt(_languageChangeCountKey, 0);
          debugPrint('Language change count reset for new day');
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old change count: $e');
    }
  }
  
  /// Export preferences for backup
  static Future<Map<String, dynamic>> exportPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'language': prefs.getString(_languageKey),
        'first_launch_completed': prefs.getBool(_firstLaunchKey),
        'language_change_count': prefs.getInt(_languageChangeCountKey),
        'last_language_change': prefs.getString(_lastLanguageChangeKey),
        'export_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error exporting preferences: $e');
      return {};
    }
  }
  
  /// Import preferences from backup
  static Future<bool> importPreferences(Map<String, dynamic> backup) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (backup['language'] != null && isValidLanguageCode(backup['language'])) {
        await prefs.setString(_languageKey, backup['language']);
      }
      
      if (backup['first_launch_completed'] != null) {
        await prefs.setBool(_firstLaunchKey, backup['first_launch_completed']);
      }
      
      debugPrint('Language preferences imported successfully');
      return true;
    } catch (e) {
      debugPrint('Error importing preferences: $e');
      return false;
    }
  }
}