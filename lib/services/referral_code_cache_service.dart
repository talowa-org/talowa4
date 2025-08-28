// Referral Code Caching Service for TALOWA
// Ensures referral codes are cached locally and never show "Loading..."

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'referral/referral_code_generator.dart';

class ReferralCodeCacheService {
  static const String _cacheKey = 'myReferralCode';
  static const String _lastFetchKey = 'lastReferralCodeFetch';
  static const Duration _cacheExpiry = Duration(hours: 24);
  
  static String? _memoryCache;
  static final StreamController<String?> _codeController = StreamController<String?>.broadcast();
  
  /// Stream of referral code updates
  static Stream<String?> get codeStream => _codeController.stream;
  
  /// Get current cached referral code (never returns null)
  static String get currentCode => _memoryCache ?? 'TAL---';
  
  /// Initialize cache on app start
  static Future<void> initialize(String uid) async {
    try {
      // Load from local storage first
      await _loadFromLocalStorage();

      // Fetch from server and update cache
      await _fetchAndCache(uid);
    } catch (e) {
      debugPrint('Error initializing referral code cache: $e');
    }
  }

  /// Initialize cache with a known referral code (for registration)
  static Future<void> initializeWithCode(String uid, String referralCode) async {
    try {
      // Immediately update cache with the known code
      await _updateCache(referralCode);

      // Also load from local storage for any existing data
      await _loadFromLocalStorage();

      // If the provided code is better than cached, use it
      if (ReferralCodeGenerator.hasValidTALPrefix(referralCode) && referralCode != 'TAL---') {
        await _updateCache(referralCode);
      } else {
        // Fetch from server to get the real code
        await _fetchAndCache(uid);
      }
    } catch (e) {
      debugPrint('Error initializing referral code cache with code: $e');
    }
  }
  
  /// Fetch referral code from server with retry logic
  static Future<void> _fetchAndCache(String uid) async {
    const maxRetries = 3;
    const baseDelay = Duration(milliseconds: 200);
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        
        if (userDoc.exists) {
          final referralCode = userDoc.data()?['referralCode'] as String?;
          
          if (referralCode != null && referralCode.isNotEmpty) {
            await _updateCache(referralCode);
            return;
          }
        }
        
        // If no code found, wait and retry
        if (attempt < maxRetries - 1) {
          final delay = Duration(milliseconds: baseDelay.inMilliseconds * (1 << attempt));
          await Future.delayed(delay);
        }
      } catch (e) {
        debugPrint('Attempt ${attempt + 1} failed to fetch referral code: $e');
        
        if (attempt < maxRetries - 1) {
          final delay = Duration(milliseconds: baseDelay.inMilliseconds * (1 << attempt));
          await Future.delayed(delay);
        }
      }
    }
    
    // If all retries failed, show placeholder and continue background fetch
    debugPrint('All attempts to fetch referral code failed, using placeholder');
    _scheduleBackgroundRefresh(uid);
  }
  
  /// Update cache in memory and local storage
  static Future<void> _updateCache(String referralCode) async {
    try {
      _memoryCache = referralCode;
      _codeController.add(referralCode);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, referralCode);
      await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('Referral code cached: $referralCode');
    } catch (e) {
      debugPrint('Error updating referral code cache: $e');
    }
  }
  
  /// Load referral code from local storage
  static Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCode = prefs.getString(_cacheKey);
      final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
      
      if (cachedCode != null && cachedCode.isNotEmpty) {
        _memoryCache = cachedCode;
        _codeController.add(cachedCode);
        
        // Check if cache is still valid
        final cacheAge = DateTime.now().millisecondsSinceEpoch - lastFetch;
        if (cacheAge > _cacheExpiry.inMilliseconds) {
          debugPrint('Cached referral code expired, will refresh from server');
        } else {
          debugPrint('Loaded referral code from cache: $cachedCode');
        }
      }
    } catch (e) {
      debugPrint('Error loading referral code from cache: $e');
    }
  }
  
  /// Schedule background refresh if initial fetch failed
  static void _scheduleBackgroundRefresh(String uid) {
    Timer(const Duration(seconds: 5), () async {
      try {
        await _fetchAndCache(uid);
      } catch (e) {
        debugPrint('Background referral code refresh failed: $e');
      }
    });
  }
  
  /// Force refresh referral code from server
  static Future<void> refresh(String uid) async {
    await _fetchAndCache(uid);
  }
  
  /// Clear cache (for logout)
  static Future<void> clear() async {
    try {
      _memoryCache = null;
      _codeController.add(null);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastFetchKey);
    } catch (e) {
      debugPrint('Error clearing referral code cache: $e');
    }
  }
  
  /// Dispose resources
  static void dispose() {
    _codeController.close();
  }
}
