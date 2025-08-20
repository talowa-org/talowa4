import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:uni_links/uni_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'referral_lookup_service.dart';

/// Exception thrown when universal link handling fails
class UniversalLinkException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const UniversalLinkException(this.message, [this.code = 'UNIVERSAL_LINK_FAILED', this.context]);
  
  @override
  String toString() => 'UniversalLinkException: $message';
}

/// Service for handling universal referral links across platforms
class UniversalLinkService {
  static const String BASE_URL = 'https://talowa.web.app';
  static const String JOIN_PATH = '/join';
  static const String REFERRAL_PARAM = 'ref';
  
  static FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static AppLinks? _appLinks;
  static StreamSubscription<Uri>? _linkSubscription;
  static String? _pendingReferralCode;
  
  // Callbacks for handling different link types
  static Function(String)? _onReferralCodeReceived;
  static Function(String)? _onDeepLinkError;
  
  /// For testing purposes - allows injection of fake firestore
  static void setFirestoreInstance(FirebaseFirestore firestore) {
    _firestore = firestore;
  }
  
  /// Initialize universal link handling
  static Future<void> initialize({
    Function(String)? onReferralCodeReceived,
    Function(String)? onDeepLinkError,
  }) async {
    _onReferralCodeReceived = onReferralCodeReceived;
    _onDeepLinkError = onDeepLinkError;
    
    try {
      if (!kIsWeb) {
        _appLinks = AppLinks();
        
        // Handle initial link when app is launched from a link
        final initialLink = await _getInitialLink();
        if (initialLink != null) {
          await _handleIncomingLink(initialLink);
        }
        
        // Listen for incoming links when app is already running
        _linkSubscription = _appLinks!.uriLinkStream.listen(
          _handleIncomingLink,
          onError: (err) {
            _onDeepLinkError?.call('Link stream error: $err');
          },
        );
      }
    } catch (e) {
      _onDeepLinkError?.call('Failed to initialize universal links: $e');
    }
  }
  
  /// Dispose of link subscription
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
  
  /// Get initial link when app is launched
  static Future<Uri?> _getInitialLink() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final initialLink = await getInitialLink();
        return initialLink != null ? Uri.parse(initialLink) : null;
      }
    } catch (e) {
      // Handle platform exceptions gracefully
      return null;
    }
    return null;
  }
  
  /// Handle incoming universal link
  static Future<void> _handleIncomingLink(Uri uri) async {
    try {
      await _trackLinkClick(uri);
      
      final referralCode = _extractReferralCode(uri);
      if (referralCode != null) {
        await _handleReferralLink(referralCode);
      } else {
        _onDeepLinkError?.call('No referral code found in link: $uri');
      }
    } catch (e) {
      _onDeepLinkError?.call('Failed to handle incoming link: $e');
    }
  }
  
  /// Extract referral code from URI
  static String? _extractReferralCode(Uri uri) {
    // Check query parameters
    final referralCode = uri.queryParameters[REFERRAL_PARAM];
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      return referralCode.trim().toUpperCase();
    }

    // Check path segments for referral code
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
      final code = uri.pathSegments[1].trim();
      if (code.isNotEmpty) {
        return code.toUpperCase();
      }
    }

    return null;
  }
  
  /// Handle referral link with code validation
  static Future<void> _handleReferralLink(String referralCode) async {
    try {
      // Validate referral code format
      if (!ReferralLookupService.isValidCodeFormat(referralCode)) {
        _onDeepLinkError?.call('Invalid referral code format: $referralCode');
        return;
      }
      
      // Validate referral code exists and is active
      final isValid = await ReferralLookupService.isValidReferralCode(referralCode);
      if (!isValid) {
        _onDeepLinkError?.call('Invalid or inactive referral code: $referralCode');
        return;
      }
      
      // Store pending referral code
      _pendingReferralCode = referralCode;
      
      // Notify callback
      _onReferralCodeReceived?.call(referralCode);
      
    } catch (e) {
      _onDeepLinkError?.call('Failed to handle referral link: $e');
    }
  }
  
  /// Track link click for analytics
  static Future<void> _trackLinkClick(Uri uri) async {
    try {
      final metadata = await _collectClickMetadata(uri);
      
      final referralCode = _extractReferralCode(uri);
      if (referralCode != null) {
        await ReferralLookupService.incrementClickCount(referralCode, metadata: metadata);
      }
      
      // Log general link click
      await _firestore.collection('linkClicks').add({
        'uri': uri.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
        'referralCode': referralCode,
      });
      
    } catch (e) {
      // Don't fail the main flow for analytics errors
      print('Warning: Failed to track link click: $e');
    }
  }
  
  /// Collect click metadata for analytics
  static Future<Map<String, dynamic>> _collectClickMetadata(Uri uri) async {
    final metadata = <String, dynamic>{
      'platform': _getPlatformName(),
      'timestamp': DateTime.now().toIso8601String(),
      'uri': uri.toString(),
      'host': uri.host,
      'path': uri.path,
      'queryParameters': uri.queryParameters,
    };
    
    // Add platform-specific metadata
    if (!kIsWeb) {
      try {
        metadata['isAppInstalled'] = true;
        metadata['appVersion'] = await _getAppVersion();
      } catch (e) {
        // Handle gracefully
      }
    }
    
    return metadata;
  }
  
  /// Get platform name
  static String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
  
  /// Get app version (placeholder - would need package_info_plus)
  static Future<String> _getAppVersion() async {
    try {
      // This would require package_info_plus dependency
      // For now, return a placeholder
      return '1.0.0';
    } catch (e) {
      return 'unknown';
    }
  }
  
  /// Generate universal referral link
  static String generateReferralLink(String referralCode) {
    final uri = Uri.parse(BASE_URL).replace(
      path: JOIN_PATH,
      queryParameters: {REFERRAL_PARAM: referralCode},
    );
    return uri.toString();
  }
  
  /// Generate short referral link (for sharing)
  static String generateShortReferralLink(String referralCode) {
    // For now, return the same link. In production, you might use a URL shortener
    return generateReferralLink(referralCode);
  }
  
  /// Get pending referral code (from deep link)
  /// Note: This clears the pending code after retrieval (one-time use)
  static String? getPendingReferralCode() {
    final code = _pendingReferralCode;
    _pendingReferralCode = null; // Clear after retrieval
    return code;
  }

  /// For testing purposes - set pending referral code
  static void setPendingReferralCodeForTesting(String code) {
    _pendingReferralCode = code;
  }
  
  /// Clear pending referral code
  static void clearPendingReferralCode() {
    _pendingReferralCode = null;
  }

  /// Set pending referral code (for testing purposes)
  static void setPendingReferralCode(String referralCode) {
    _pendingReferralCode = referralCode;
  }
  
  /// Check if a URL is a valid referral link
  static bool isReferralLink(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.contains('talowa') &&
             (uri.path.contains('/join') || uri.queryParameters.containsKey(REFERRAL_PARAM)) &&
             _extractReferralCode(uri) != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Parse referral code from URL string
  static String? parseReferralCodeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return _extractReferralCode(uri);
    } catch (e) {
      return null;
    }
  }
  
  /// Test universal link handling (for development)
  static Future<void> testReferralLink(String referralCode) async {
    final testUri = Uri.parse(generateReferralLink(referralCode));
    await _handleIncomingLink(testUri);
  }
  
  /// Get link click statistics
  static Future<Map<String, dynamic>> getLinkClickStats(String referralCode) async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(Duration(days: 1));
      
      final query = await _firestore
          .collection('linkClicks')
          .where('referralCode', isEqualTo: referralCode)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .get();
      
      final clicksByPlatform = <String, int>{};
      final clicksByHour = <int, int>{};
      
      for (final doc in query.docs) {
        final data = doc.data();
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final platform = metadata['platform'] as String? ?? 'unknown';
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? now;
        
        clicksByPlatform[platform] = (clicksByPlatform[platform] ?? 0) + 1;
        clicksByHour[timestamp.hour] = (clicksByHour[timestamp.hour] ?? 0) + 1;
      }
      
      return {
        'totalClicks': query.docs.length,
        'clicksByPlatform': clicksByPlatform,
        'clicksByHour': clicksByHour,
        'period': '24h',
      };
    } catch (e) {
      throw UniversalLinkException(
        'Failed to get link click stats: $e',
        'STATS_FAILED',
        {'referralCode': referralCode}
      );
    }
  }
  
  /// Validate universal link configuration
  static Future<bool> validateConfiguration() async {
    try {
      // Test basic link generation
      final testCode = 'TAL8K9M2X';
      final link = generateReferralLink(testCode);
      final parsedCode = parseReferralCodeFromUrl(link);
      
      if (parsedCode != testCode) {
        return false;
      }
      
      // Test link validation
      if (!isReferralLink(link)) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
