// Content Filter Service for TALOWA Messaging System
import 'dart:async';
import 'package:flutter/foundation.dart';

class ContentFilterService {
  static const List<String> _inappropriateWords = [
    // Add inappropriate words in Telugu, Hindi, and English
    'spam', 'scam', 'fake', 'fraud',
    // Telugu inappropriate words (examples)
    'దుర్మార్గుడు', 'మోసగాడు',
    // Hindi inappropriate words (examples)  
    'धोखाधड़ी', 'झूठा',
  ];

  static const List<String> _spamPatterns = [
    r'\b(?:call|contact|whatsapp)\s*(?:me|us)\s*(?:at|on)\s*[\d\s\-\+\(\)]+',
    r'\b(?:visit|check)\s*(?:our|my)\s*(?:website|site|link)',
    r'\b(?:click|tap)\s*(?:here|link|below)',
    r'\b(?:free|offer|discount|sale)\s*(?:now|today|limited)',
  ];

  static const int _maxMessageLength = 2000;
  static const int _maxMessagesPerMinute = 10;
  static const int _maxIdenticalMessages = 3;

  // Rate limiting storage
  static final Map<String, List<DateTime>> _userMessageTimes = {};
  static final Map<String, List<String>> _userRecentMessages = {};

  /// Check if message content is appropriate
  static ContentFilterResult filterMessage(String content, String userId) {
    try {
      // Check message length
      if (content.length > _maxMessageLength) {
        return ContentFilterResult(
          isAllowed: false,
          reason: 'Message too long',
          severity: FilterSeverity.medium,
          action: FilterAction.reject,
        );
      }

      // Check for inappropriate words
      final inappropriateCheck = _checkInappropriateContent(content);
      if (!inappropriateCheck.isAllowed) {
        return inappropriateCheck;
      }

      // Check for spam patterns
      final spamCheck = _checkSpamPatterns(content);
      if (!spamCheck.isAllowed) {
        return spamCheck;
      }

      // Check rate limiting
      final rateLimitCheck = _checkRateLimit(userId, content);
      if (!rateLimitCheck.isAllowed) {
        return rateLimitCheck;
      }

      // Message is clean
      return ContentFilterResult(
        isAllowed: true,
        reason: 'Content approved',
        severity: FilterSeverity.none,
        action: FilterAction.allow,
      );
    } catch (e) {
      debugPrint('Error in content filtering: $e');
      // In case of error, allow message but log for review
      return ContentFilterResult(
        isAllowed: true,
        reason: 'Filter error - manual review needed',
        severity: FilterSeverity.low,
        action: FilterAction.allowWithReview,
      );
    }
  }

  /// Check for inappropriate content
  static ContentFilterResult _checkInappropriateContent(String content) {
    final lowerContent = content.toLowerCase();
    
    for (final word in _inappropriateWords) {
      if (lowerContent.contains(word.toLowerCase())) {
        return ContentFilterResult(
          isAllowed: false,
          reason: 'Contains inappropriate content',
          severity: FilterSeverity.high,
          action: FilterAction.reject,
          flaggedContent: word,
        );
      }
    }

    return ContentFilterResult(
      isAllowed: true,
      reason: 'No inappropriate content detected',
      severity: FilterSeverity.none,
      action: FilterAction.allow,
    );
  }

  /// Check for spam patterns
  static ContentFilterResult _checkSpamPatterns(String content) {
    for (final pattern in _spamPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      if (regex.hasMatch(content)) {
        return ContentFilterResult(
          isAllowed: false,
          reason: 'Detected spam pattern',
          severity: FilterSeverity.medium,
          action: FilterAction.reject,
          flaggedContent: regex.firstMatch(content)?.group(0),
        );
      }
    }

    return ContentFilterResult(
      isAllowed: true,
      reason: 'No spam patterns detected',
      severity: FilterSeverity.none,
      action: FilterAction.allow,
    );
  }

  /// Check rate limiting for user
  static ContentFilterResult _checkRateLimit(String userId, String content) {
    final now = DateTime.now();
    
    // Initialize user data if not exists
    _userMessageTimes.putIfAbsent(userId, () => []);
    _userRecentMessages.putIfAbsent(userId, () => []);

    // Clean old message times (older than 1 minute)
    _userMessageTimes[userId]!.removeWhere(
      (time) => now.difference(time).inMinutes >= 1,
    );

    // Check messages per minute limit
    if (_userMessageTimes[userId]!.length >= _maxMessagesPerMinute) {
      return ContentFilterResult(
        isAllowed: false,
        reason: 'Rate limit exceeded - too many messages per minute',
        severity: FilterSeverity.medium,
        action: FilterAction.temporaryBlock,
      );
    }

    // Clean old recent messages (older than 5 minutes)
    if (_userRecentMessages[userId]!.length > 10) {
      _userRecentMessages[userId]!.removeRange(0, _userRecentMessages[userId]!.length - 10);
    }

    // Check for identical messages (spam detection)
    final identicalCount = _userRecentMessages[userId]!
        .where((msg) => msg == content)
        .length;

    if (identicalCount >= _maxIdenticalMessages) {
      return ContentFilterResult(
        isAllowed: false,
        reason: 'Spam detected - identical messages repeated',
        severity: FilterSeverity.high,
        action: FilterAction.temporaryBlock,
      );
    }

    // Add current message to tracking
    _userMessageTimes[userId]!.add(now);
    _userRecentMessages[userId]!.add(content);

    return ContentFilterResult(
      isAllowed: true,
      reason: 'Rate limit check passed',
      severity: FilterSeverity.none,
      action: FilterAction.allow,
    );
  }

  /// Clear rate limiting data for user (for testing or admin override)
  static void clearUserRateLimit(String userId) {
    _userMessageTimes.remove(userId);
    _userRecentMessages.remove(userId);
  }

  /// Get user's current rate limit status
  static RateLimitStatus getUserRateLimitStatus(String userId) {
    final now = DateTime.now();
    final messageTimes = _userMessageTimes[userId] ?? [];
    
    // Clean old message times
    messageTimes.removeWhere(
      (time) => now.difference(time).inMinutes >= 1,
    );

    return RateLimitStatus(
      messagesInLastMinute: messageTimes.length,
      maxMessagesPerMinute: _maxMessagesPerMinute,
      remainingMessages: _maxMessagesPerMinute - messageTimes.length,
      nextResetTime: messageTimes.isNotEmpty 
          ? messageTimes.first.add(const Duration(minutes: 1))
          : now,
    );
  }

  /// Check if user is currently blocked
  static bool isUserBlocked(String userId) {
    // This would typically check against a database of blocked users
    // For now, we'll implement a simple in-memory check
    return _blockedUsers.contains(userId);
  }

  // Temporary blocked users storage (in production, this would be in database)
  static final Set<String> _blockedUsers = {};

  /// Temporarily block user
  static void temporaryBlockUser(String userId, Duration duration) {
    _blockedUsers.add(userId);
    Timer(duration, () {
      _blockedUsers.remove(userId);
    });
  }
}

/// Result of content filtering
class ContentFilterResult {
  final bool isAllowed;
  final String reason;
  final FilterSeverity severity;
  final FilterAction action;
  final String? flaggedContent;

  ContentFilterResult({
    required this.isAllowed,
    required this.reason,
    required this.severity,
    required this.action,
    this.flaggedContent,
  });

  @override
  String toString() {
    return 'ContentFilterResult(isAllowed: $isAllowed, reason: $reason, severity: ${severity.name})';
  }
}

/// Filter severity levels
enum FilterSeverity {
  none,
  low,
  medium,
  high,
  critical,
}

/// Filter actions
enum FilterAction {
  allow,
  allowWithReview,
  reject,
  temporaryBlock,
  permanentBlock,
}

/// Rate limit status for a user
class RateLimitStatus {
  final int messagesInLastMinute;
  final int maxMessagesPerMinute;
  final int remainingMessages;
  final DateTime nextResetTime;

  RateLimitStatus({
    required this.messagesInLastMinute,
    required this.maxMessagesPerMinute,
    required this.remainingMessages,
    required this.nextResetTime,
  });

  bool get isLimited => remainingMessages <= 0;

  @override
  String toString() {
    return 'RateLimitStatus(messages: $messagesInLastMinute/$maxMessagesPerMinute, remaining: $remainingMessages)';
  }
}