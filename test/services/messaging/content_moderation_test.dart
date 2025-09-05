// Test file for Content Moderation Service
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/messaging/content_filter_service.dart';
import 'package:talowa/models/messaging/content_report_model.dart';

void main() {
  group('Content Filter Service Tests', () {
    test('should allow clean message', () {
      const content = 'Hello, how are you doing today?';
      const userId = 'test_user_1';
      
      final result = ContentFilterService.filterMessage(content, userId);
      
      expect(result.isAllowed, true);
      expect(result.severity, FilterSeverity.none);
      expect(result.action, FilterAction.allow);
    });

    test('should reject message with inappropriate content', () {
      const content = 'This is spam content';
      const userId = 'test_user_2';
      
      final result = ContentFilterService.filterMessage(content, userId);
      
      expect(result.isAllowed, false);
      expect(result.severity, FilterSeverity.high);
      expect(result.action, FilterAction.reject);
      expect(result.flaggedContent, 'spam');
    });

    test('should reject message that is too long', () {
      final content = 'A' * 2001; // Exceeds max length
      const userId = 'test_user_3';
      
      final result = ContentFilterService.filterMessage(content, userId);
      
      expect(result.isAllowed, false);
      expect(result.reason, 'Message too long');
      expect(result.severity, FilterSeverity.medium);
    });

    test('should track rate limiting correctly', () {
      const userId = 'test_user_4';
      const content = 'Hello world';
      
      // Clear any existing rate limit data for this user
      ContentFilterService.clearUserRateLimit(userId);
      
      // Send multiple messages quickly (exactly at the limit)
      for (int i = 0; i < 10; i++) {
        final result = ContentFilterService.filterMessage('$content $i', userId);
        expect(result.isAllowed, true, reason: 'Message $i should be allowed');
      }
      
      // 11th message should be rate limited
      final result = ContentFilterService.filterMessage(content, userId);
      expect(result.isAllowed, false);
      expect(result.reason.contains('Rate limit exceeded'), true);
    });

    test('should detect spam patterns', () {
      const content = 'Call me at 9876543210 for amazing offers!';
      const userId = 'test_user_5';
      
      final result = ContentFilterService.filterMessage(content, userId);
      
      expect(result.isAllowed, false);
      expect(result.reason, 'Detected spam pattern');
      expect(result.severity, FilterSeverity.medium);
    });

    test('should get user rate limit status', () {
      const userId = 'test_user_6';
      
      // Send a few messages
      for (int i = 0; i < 3; i++) {
        ContentFilterService.filterMessage('Test $i', userId);
      }
      
      final status = ContentFilterService.getUserRateLimitStatus(userId);
      
      expect(status.messagesInLastMinute, 3);
      expect(status.remainingMessages, 7); // 10 - 3
      expect(status.isLimited, false);
    });

    test('should clear user rate limit', () {
      const userId = 'test_user_7';
      
      // Send messages to trigger rate limit
      for (int i = 0; i < 10; i++) {
        ContentFilterService.filterMessage('Test $i', userId);
      }
      
      // Clear rate limit
      ContentFilterService.clearUserRateLimit(userId);
      
      // Should be able to send message again
      final result = ContentFilterService.filterMessage('New message', userId);
      expect(result.isAllowed, true);
    });
  });

  group('Content Report Model Tests', () {
    test('should create report model correctly', () {
      final report = ContentReportModel(
        id: 'test_report_1',
        reporterId: 'reporter_1',
        reporterName: 'Test Reporter',
        messageId: 'message_1',
        conversationId: 'conversation_1',
        reportedUserId: 'reported_1',
        reportedUserName: 'Reported User',
        reportType: ReportType.spam,
        reason: 'This is spam',
        status: ReportStatus.pending,
        reportedAt: DateTime.now(),
        metadata: {},
      );

      expect(report.reportType, ReportType.spam);
      expect(report.status, ReportStatus.pending);
      expect(report.reason, 'This is spam');
    });

    test('should convert report type from string correctly', () {
      expect(ReportTypeExtension.fromString('spam'), ReportType.spam);
      expect(ReportTypeExtension.fromString('harassment'), ReportType.harassment);
      expect(ReportTypeExtension.fromString('violence'), ReportType.violence);
      expect(ReportTypeExtension.fromString('unknown'), ReportType.inappropriate);
    });

    test('should convert report status from string correctly', () {
      expect(ReportStatusExtension.fromString('pending'), ReportStatus.pending);
      expect(ReportStatusExtension.fromString('reviewing'), ReportStatus.reviewing);
      expect(ReportStatusExtension.fromString('resolved'), ReportStatus.resolved);
      expect(ReportStatusExtension.fromString('dismissed'), ReportStatus.dismissed);
      expect(ReportStatusExtension.fromString('unknown'), ReportStatus.pending);
    });

    test('should get display names correctly', () {
      expect(ReportType.spam.displayName, 'Spam');
      expect(ReportType.harassment.displayName, 'Harassment');
      expect(ReportStatus.pending.displayName, 'Pending Review');
      expect(ReportStatus.resolved.displayName, 'Resolved');
    });
  });

  group('Filter Result Tests', () {
    test('should create filter result correctly', () {
      final result = ContentFilterResult(
        isAllowed: false,
        reason: 'Test reason',
        severity: FilterSeverity.high,
        action: FilterAction.reject,
        flaggedContent: 'flagged',
      );

      expect(result.isAllowed, false);
      expect(result.reason, 'Test reason');
      expect(result.severity, FilterSeverity.high);
      expect(result.action, FilterAction.reject);
      expect(result.flaggedContent, 'flagged');
    });

    test('should convert to string correctly', () {
      final result = ContentFilterResult(
        isAllowed: true,
        reason: 'Clean content',
        severity: FilterSeverity.none,
        action: FilterAction.allow,
      );

      final stringResult = result.toString();
      expect(stringResult.contains('isAllowed: true'), true);
      expect(stringResult.contains('reason: Clean content'), true);
      expect(stringResult.contains('severity: none'), true);
    });
  });

  group('Rate Limit Status Tests', () {
    test('should create rate limit status correctly', () {
      final status = RateLimitStatus(
        messagesInLastMinute: 5,
        maxMessagesPerMinute: 10,
        remainingMessages: 5,
        nextResetTime: DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(status.messagesInLastMinute, 5);
      expect(status.maxMessagesPerMinute, 10);
      expect(status.remainingMessages, 5);
      expect(status.isLimited, false);
    });

    test('should detect when user is limited', () {
      final status = RateLimitStatus(
        messagesInLastMinute: 10,
        maxMessagesPerMinute: 10,
        remainingMessages: 0,
        nextResetTime: DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(status.isLimited, true);
    });

    test('should convert to string correctly', () {
      final status = RateLimitStatus(
        messagesInLastMinute: 3,
        maxMessagesPerMinute: 10,
        remainingMessages: 7,
        nextResetTime: DateTime.now(),
      );

      final stringResult = status.toString();
      expect(stringResult.contains('messages: 3/10'), true);
      expect(stringResult.contains('remaining: 7'), true);
    });
  });
}
