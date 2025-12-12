// Web-Safe Storage Utility
// Implements fixes from talowa_social_feed_fix.md

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class WebSafeStorage {
  /// Get application documents directory (web-safe)
  static Future<String?> getDocumentsDirectory() async {
    if (kIsWeb) {
      // Web doesn't have a documents directory
      debugPrint('Documents directory not available on web');
      return null;
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      debugPrint('Error getting documents directory: $e');
      return null;
    }
  }
  
  /// Get temporary directory (web-safe)
  static Future<String?> getTemporaryDirectory() async {
    if (kIsWeb) {
      // Web doesn't have a temporary directory
      debugPrint('Temporary directory not available on web');
      return null;
    }
    
    try {
      final directory = await getTemporaryDirectory();
      return directory.path;
    } catch (e) {
      debugPrint('Error getting temporary directory: $e');
      return null;
    }
  }
  
  /// Check if file operations are supported
  static bool get isFileOperationsSupported => !kIsWeb;
  
  /// Get cache directory (web-safe)
  static Future<String?> getCacheDirectory() async {
    if (kIsWeb) {
      debugPrint('Cache directory not available on web');
      return null;
    }
    
    try {
      final directory = await getTemporaryDirectory();
      return directory.path;
    } catch (e) {
      debugPrint('Error getting cache directory: $e');
      return null;
    }
  }
}
