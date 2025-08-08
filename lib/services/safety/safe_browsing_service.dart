// Safe Browsing Service for TALOWA
// Implements Task 19: Build user safety features - Safe Browsing

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SafeBrowsingService {
  static final SafeBrowsingService _instance = SafeBrowsingService._internal();
  factory SafeBrowsingService() => _instance;
  SafeBrowsingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Known malicious domains and patterns
  final Set<String> _blockedDomains = {
    'malware.com',
    'phishing.net',
    'scam.org',
    'fake-bank.com',
    'suspicious-site.in',
  };

  final List<RegExp> _suspiciousPatterns = [
    RegExp(r'bit\.ly/[a-zA-Z0-9]+'), // Shortened URLs
    RegExp(r'tinyurl\.com/[a-zA-Z0-9]+'),
    RegExp(r'[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'), // IP addresses
    RegExp(r'(free|win|prize|lottery|urgent|click|now)', caseSensitive: false),
  ];

  /// Check if a URL is safe to browse
  Future<SafeBrowsingResult> checkUrlSafety(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        return SafeBrowsingResult(
          url: url,
          isSafe: false,
          riskLevel: RiskLevel.high,
          warnings: ['Invalid URL format'],
          blockedReason: 'Malformed URL',
        );
      }

      // Check against blocked domains
      if (_blockedDomains.contains(uri.host.toLowerCase())) {
        return SafeBrowsingResult(
          url: url,
          isSafe: false,
          riskLevel: RiskLevel.critical,
          warnings: ['Known malicious domain'],
          blockedReason: 'Domain is on blocklist',
        );
      }

      // Check for suspicious patterns
      final suspiciousWarnings = <String>[];
      for (final pattern in _suspiciousPatterns) {
        if (pattern.hasMatch(url)) {
          suspiciousWarnings.add('Suspicious URL pattern detected');
          break;
        }
      }

      // Check against our database of reported URLs
      final reportedUrl = await _checkReportedUrl(url);
      if (reportedUrl != null) {
        return SafeBrowsingResult(
          url: url,
          isSafe: false,
          riskLevel: RiskLevel.high,
          warnings: ['URL has been reported by users'],
          blockedReason: 'User-reported malicious content',
          reportCount: reportedUrl['reportCount'] ?? 0,
        );
      }

      // Check URL reputation (simplified version)
      final reputationCheck = await _checkUrlReputation(uri);
      
      return SafeBrowsingResult(
        url: url,
        isSafe: reputationCheck.isSafe,
        riskLevel: reputationCheck.riskLevel,
        warnings: [...suspiciousWarnings, ...reputationCheck.warnings],
        blockedReason: reputationCheck.blockedReason,
      );
    } catch (e) {
      debugPrint('Error checking URL safety: $e');
      return SafeBrowsingResult(
        url: url,
        isSafe: false,
        riskLevel: RiskLevel.medium,
        warnings: ['Unable to verify URL safety'],
        blockedReason: 'Safety check failed',
      );
    }
  }

  /// Launch URL with safety checks
  Future<bool> launchUrlSafely(String url, {bool forceCheck = true}) async {
    try {
      if (forceCheck) {
        final safetyResult = await checkUrlSafety(url);
        if (!safetyResult.isSafe) {
          // Log unsafe URL attempt
          await _logUnsafeUrlAttempt(url, safetyResult);
          return false;
        }
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        // Log successful safe browsing
        await _logSafeBrowsing(url);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error launching URL safely: $e');
      return false;
    }
  }

  /// Report a malicious URL
  Future<void> reportMaliciousUrl({
    required String url,
    required String reporterId,
    required String reason,
    String? description,
  }) async {
    try {
      await _firestore.collection('reported_urls').add({
        'url': url,
        'reporterId': reporterId,
        'reason': reason,
        'description': description,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Update URL report count
      final urlDoc = _firestore.collection('url_safety').doc(_getUrlHash(url));
      await urlDoc.set({
        'url': url,
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
        'isBlocked': false,
      }, SetOptions(merge: true));

      // Auto-block if multiple reports
      await _checkAutoBlockUrl(url);
    } catch (e) {
      debugPrint('Error reporting malicious URL: $e');
      rethrow;
    }
  }

  /// Get safe browsing statistics
  Future<SafeBrowsingStats> getSafeBrowsingStats() async {
    try {
      // Get blocked URLs count
      final blockedUrlsSnapshot = await _firestore
          .collection('url_safety')
          .where('isBlocked', isEqualTo: true)
          .get();

      // Get reported URLs count
      final reportedUrlsSnapshot = await _firestore
          .collection('reported_urls')
          .get();

      // Get safe browsing events count
      final safeBrowsingSnapshot = await _firestore
          .collection('safe_browsing_logs')
          .get();

      return SafeBrowsingStats(
        blockedUrls: blockedUrlsSnapshot.docs.length,
        reportedUrls: reportedUrlsSnapshot.docs.length,
        safeBrowsingEvents: safeBrowsingSnapshot.docs.length,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting safe browsing stats: $e');
      return SafeBrowsingStats(
        blockedUrls: 0,
        reportedUrls: 0,
        safeBrowsingEvents: 0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Extract URLs from text content
  List<String> extractUrlsFromText(String text) {
    final urlPattern = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^\s]*',
      caseSensitive: false,
    );
    
    return urlPattern.allMatches(text).map((match) {
      String url = match.group(0)!;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      return url;
    }).toList();
  }

  /// Check content for unsafe URLs
  Future<ContentSafetyResult> checkContentUrls(String content) async {
    final urls = extractUrlsFromText(content);
    if (urls.isEmpty) {
      return ContentSafetyResult(
        isSafe: true,
        unsafeUrls: [],
        warnings: [],
      );
    }

    final unsafeUrls = <String>[];
    final warnings = <String>[];

    for (final url in urls) {
      final safetyResult = await checkUrlSafety(url);
      if (!safetyResult.isSafe) {
        unsafeUrls.add(url);
        warnings.addAll(safetyResult.warnings);
      }
    }

    return ContentSafetyResult(
      isSafe: unsafeUrls.isEmpty,
      unsafeUrls: unsafeUrls,
      warnings: warnings,
    );
  }

  // Private helper methods

  Future<Map<String, dynamic>?> _checkReportedUrl(String url) async {
    try {
      final doc = await _firestore
          .collection('url_safety')
          .doc(_getUrlHash(url))
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final reportCount = data['reportCount'] as int? ?? 0;
        if (reportCount > 0) {
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking reported URL: $e');
      return null;
    }
  }

  Future<SafeBrowsingResult> _checkUrlReputation(Uri uri) async {
    try {
      // Simplified reputation check - in production, integrate with services like:
      // Google Safe Browsing API, VirusTotal, etc.
      
      // Check for common suspicious indicators
      final warnings = <String>[];
      var riskLevel = RiskLevel.low;
      
      // Check for suspicious TLD
      final suspiciousTlds = ['.tk', '.ml', '.ga', '.cf', '.click', '.download'];
      if (suspiciousTlds.any((tld) => uri.host.endsWith(tld))) {
        warnings.add('Suspicious domain extension');
        riskLevel = RiskLevel.medium;
      }
      
      // Check for excessive subdomains
      if (uri.host.split('.').length > 4) {
        warnings.add('Suspicious subdomain structure');
        riskLevel = RiskLevel.medium;
      }
      
      // Check for URL shorteners
      final shorteners = ['bit.ly', 'tinyurl.com', 't.co', 'goo.gl'];
      if (shorteners.contains(uri.host)) {
        warnings.add('Shortened URL - destination unknown');
        riskLevel = RiskLevel.medium;
      }
      
      return SafeBrowsingResult(
        url: uri.toString(),
        isSafe: riskLevel == RiskLevel.low,
        riskLevel: riskLevel,
        warnings: warnings,
        blockedReason: warnings.isNotEmpty ? 'Suspicious indicators detected' : null,
      );
    } catch (e) {
      debugPrint('Error checking URL reputation: $e');
      return SafeBrowsingResult(
        url: uri.toString(),
        isSafe: false,
        riskLevel: RiskLevel.medium,
        warnings: ['Unable to verify URL reputation'],
        blockedReason: 'Reputation check failed',
      );
    }
  }

  Future<void> _checkAutoBlockUrl(String url) async {
    try {
      final urlDoc = await _firestore
          .collection('url_safety')
          .doc(_getUrlHash(url))
          .get();
      
      if (urlDoc.exists) {
        final data = urlDoc.data()!;
        final reportCount = data['reportCount'] as int? ?? 0;
        
        // Auto-block if 3 or more reports
        if (reportCount >= 3) {
          await urlDoc.reference.update({
            'isBlocked': true,
            'blockedAt': FieldValue.serverTimestamp(),
            'blockReason': 'Multiple user reports',
          });
          
          // Add to blocked domains
          final uri = Uri.parse(url);
          _blockedDomains.add(uri.host);
        }
      }
    } catch (e) {
      debugPrint('Error checking auto-block URL: $e');
    }
  }

  Future<void> _logUnsafeUrlAttempt(String url, SafeBrowsingResult result) async {
    try {
      await _firestore.collection('unsafe_url_attempts').add({
        'url': url,
        'riskLevel': result.riskLevel.toString(),
        'warnings': result.warnings,
        'blockedReason': result.blockedReason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging unsafe URL attempt: $e');
    }
  }

  Future<void> _logSafeBrowsing(String url) async {
    try {
      await _firestore.collection('safe_browsing_logs').add({
        'url': url,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging safe browsing: $e');
    }
  }

  String _getUrlHash(String url) {
    return url.hashCode.abs().toString();
  }
}

// Data models for safe browsing

enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

class SafeBrowsingResult {
  final String url;
  final bool isSafe;
  final RiskLevel riskLevel;
  final List<String> warnings;
  final String? blockedReason;
  final int? reportCount;

  SafeBrowsingResult({
    required this.url,
    required this.isSafe,
    required this.riskLevel,
    required this.warnings,
    this.blockedReason,
    this.reportCount,
  });
}

class ContentSafetyResult {
  final bool isSafe;
  final List<String> unsafeUrls;
  final List<String> warnings;

  ContentSafetyResult({
    required this.isSafe,
    required this.unsafeUrls,
    required this.warnings,
  });
}

class SafeBrowsingStats {
  final int blockedUrls;
  final int reportedUrls;
  final int safeBrowsingEvents;
  final DateTime lastUpdated;

  SafeBrowsingStats({
    required this.blockedUrls,
    required this.reportedUrls,
    required this.safeBrowsingEvents,
    required this.lastUpdated,
  });
}