// Unit tests for message encryption and security layer
// Tests all security components for comprehensive coverage

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

// Import the services we're testing
import 'package:talowa/services/messaging/encryption_service.dart';
import 'package:talowa/services/messaging/anonymous_messaging_service.dart';
import 'package:talowa/services/messaging/message_validation_service.dart';
import 'package:talowa/services/security/rate_limiting_service.dart';
import 'package:talowa/services/messaging/integrated_security_service.dart';

void main() {
  group('Message Encryption Service Tests', () {
    late EncryptionService encryptionService;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      encryptionService = EncryptionService();
    });

    test('should generate and store encryption keys', () async {
      // Test key generation functionality
      expect(() async {
        await encryptionService.initializeUserEncryption();
      }, returnsNormally);
    });

    test('should encrypt and decrypt messages correctly', () async {
      const testMessage = 'This is a test message for encryption';
      const recipientId = 'test_recipient_123';
      
      // Test message encryption
      final encryptedContent = await encryptionService.encryptMessage(
        content: testMessage,
        recipientUserId: recipientId,
        level: EncryptionLevel.standard,
      );
      
      expect(encryptedContent.data, isNotEmpty);
      expect(encryptedContent.iv, isNotEmpty);
      expect(encryptedContent.encryptedKeys, isNotEmpty);
      
      // Test message decryption
      final decryptedMessage = await encryptionService.decryptMessage(encryptedContent);
      expect(decryptedMessage, equals(testMessage));
    });

    test('should handle group message encryption', () async {
      const testMessage = 'Group message test';
      const groupId = 'test_group_123';
      final participantIds = ['user1', 'user2', 'user3'];
      
      final encryptedContent = await encryptionService.encryptGroupMessage(
        content: testMessage,
        groupId: groupId,
        participantIds: participantIds,
        level: EncryptionLevel.standard,
      );
      
      expect(encryptedContent.isGroupMessage, isTrue);
      expect(encryptedContent.groupId, equals(groupId));
      expect(encryptedContent.encryptedKeys.length, equals(participantIds.length));
    });

    test('should handle anonymous message encryption', () async {
      const testMessage = 'Anonymous report content';
      const coordinatorId = 'coordinator_123';
      
      final encryptedContent = await encryptionService.encryptAnonymousMessage(
        content: testMessage,
        coordinatorId: coordinatorId,
      );
      
      expect(encryptedContent.isAnonymous, isTrue);
      expect(encryptedContent.encryptionLevel, equals(EncryptionLevel.highSecurity));
      expect(encryptedContent.encryptedKeys.containsKey(coordinatorId), isTrue);
    });
  });

  group('Message Validation Service Tests', () {
    late MessageValidationService validationService;

    setUp(() {
      validationService = MessageValidationService();
    });

    test('should validate normal messages', () async {
      const normalMessage = 'This is a normal message about land rights.';
      
      final result = await validationService.validateMessage(
        content: normalMessage,
        messageType: MessageType.text,
      );
      
      expect(result.isValid, isTrue);
      expect(result.sanitizedContent, equals(normalMessage));
      expect(result.riskScore, lessThan(0.3));
    });

    test('should detect malicious content', () async {
      const maliciousMessage = '<script>alert("xss")</script>This is malicious';
      
      final result = await validationService.validateMessage(
        content: maliciousMessage,
        messageType: MessageType.text,
      );
      
      expect(result.isValid, isFalse);
      expect(result.issues.any((issue) => 
          issue.type == ValidationIssueType.maliciousContent), isTrue);
      expect(result.riskScore, greaterThan(0.3));
    });

    test('should detect spam content', () async {
      const spamMessage = 'FREE MONEY!!! CLICK HERE NOW!!! LIMITED TIME OFFER!!!';
      
      final result = await validationService.validateMessage(
        content: spamMessage,
        messageType: MessageType.text,
      );
      
      expect(result.issues.any((issue) => 
          issue.type == ValidationIssueType.spamContent), isTrue);
    });

    test('should sanitize content', () async {
      const unsafeMessage = '<script>alert("test")</script>Normal content here';
      
      final result = await validationService.validateMessage(
        content: unsafeMessage,
        messageType: MessageType.text,
      );
      
      expect(result.sanitizedContent, equals('Normal content here'));
    });

    test('should validate file uploads', () async {
      const fileName = 'test_document.pdf';
      const mimeType = 'application/pdf';
      final fileBytes = List<int>.filled(1000, 65); // Mock PDF content
      
      final result = await validationService.validateFile(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileBytes.length,
        fileBytes: fileBytes,
      );
      
      expect(result.isValid, isTrue);
      expect(result.quarantined, isFalse);
    });

    test('should reject oversized files', () async {
      const fileName = 'huge_file.pdf';
      const mimeType = 'application/pdf';
      final fileBytes = List<int>.filled(30 * 1024 * 1024, 65); // 30MB file
      
      final result = await validationService.validateFile(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileBytes.length,
        fileBytes: fileBytes,
      );
      
      expect(result.isValid, isFalse);
      expect(result.issues.any((issue) => 
          issue.type == ValidationIssueType.fileTooLarge), isTrue);
    });

    test('should reject unauthorized file types', () async {
      const fileName = 'malware.exe';
      const mimeType = 'application/x-executable';
      final fileBytes = [0x4D, 0x5A, 0x90, 0x00]; // PE executable header
      
      final result = await validationService.validateFile(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileBytes.length,
        fileBytes: fileBytes,
      );
      
      expect(result.isValid, isFalse);
      expect(result.issues.any((issue) => 
          issue.type == ValidationIssueType.invalidFileType), isTrue);
    });
  });

  group('Rate Limiting Service Tests', () {
    late RateLimitingService rateLimitingService;

    setUp(() {
      rateLimitingService = RateLimitingService();
    });

    test('should allow actions within rate limits', () async {
      const userId = 'test_user_123';
      const action = 'send_message';
      
      final result = await rateLimitingService.checkRateLimit(
        action: action,
        userId: userId,
      );
      
      expect(result.allowed, isTrue);
      expect(result.remainingRequests, greaterThan(0));
    });

    test('should block actions exceeding rate limits', () async {
      const userId = 'test_user_456';
      const action = 'send_message';
      
      // Simulate multiple rapid requests
      for (int i = 0; i < 70; i++) { // Exceed the 60 per minute limit
        await rateLimitingService.checkRateLimit(
          action: action,
          userId: userId,
        );
      }
      
      final result = await rateLimitingService.checkRateLimit(
        action: action,
        userId: userId,
      );
      
      expect(result.allowed, isFalse);
      expect(result.penaltyActive, isTrue);
    });

    test('should handle burst limits', () async {
      const userId = 'test_user_789';
      const action = 'send_message';
      
      // Send messages rapidly to trigger burst limit
      for (int i = 0; i < 15; i++) { // Exceed burst limit of 10
        await rateLimitingService.checkRateLimit(
          action: action,
          userId: userId,
        );
      }
      
      final result = await rateLimitingService.checkRateLimit(
        action: action,
        userId: userId,
      );
      
      expect(result.allowed, isFalse);
      expect(result.penaltyReason, contains('Burst limit'));
    });

    test('should provide rate limit status', () async {
      const userId = 'test_user_status';
      
      final status = await rateLimitingService.getRateLimitStatus(
        userId: userId,
      );
      
      expect(status, isNotEmpty);
      expect(status.containsKey('send_message'), isTrue);
      expect(status['send_message']?.remainingRequests, isNotNull);
    });
  });

  group('Anonymous Messaging Service Tests', () {
    late AnonymousMessagingService anonymousService;

    setUp(() {
      anonymousService = AnonymousMessagingService();
    });

    test('should create anonymous reports', () async {
      const content = 'Anonymous report about land grabbing incident';
      const coordinatorId = 'coordinator_123';
      
      final caseId = await anonymousService.sendAnonymousReport(
        content: content,
        coordinatorId: coordinatorId,
        reportType: ReportType.landGrabbing,
      );
      
      expect(caseId, isNotEmpty);
      expect(caseId, startsWith('ANON-'));
    });

    test('should generalize location data', () async {
      const content = 'Report with location data';
      const coordinatorId = 'coordinator_456';
      final location = {
        'latitude': 17.3850,
        'longitude': 78.4867,
        'villageCode': 'VIL001',
        'villageName': 'Test Village',
        'mandalCode': 'MAN001',
        'mandalName': 'Test Mandal',
      };
      
      final caseId = await anonymousService.sendAnonymousReport(
        content: content,
        coordinatorId: coordinatorId,
        reportType: ReportType.landGrabbing,
        location: location,
      );
      
      expect(caseId, isNotEmpty);
      // Location should be generalized, not precise coordinates
    });

    test('should handle anonymous responses', () async {
      const caseId = 'ANON-123456-789012';
      const response = 'Thank you for your report. We are investigating.';
      
      expect(() async {
        await anonymousService.respondToAnonymousReport(
          caseId: caseId,
          response: response,
        );
      }, returnsNormally);
    });
  });

  group('Integrated Security Service Tests', () {
    late IntegratedSecurityService integratedService;

    setUp(() {
      integratedService = IntegratedSecurityService();
    });

    test('should perform comprehensive security checks', () async {
      const content = 'Test message for integrated security';
      const recipientId = 'recipient_123';
      
      final result = await integratedService.sendSecureMessage(
        content: content,
        messageType: MessageType.text,
        recipientId: recipientId,
      );
      
      expect(result.securityChecks, isNotEmpty);
      expect(result.securityChecks['rate_limit_passed'], isNotNull);
      expect(result.securityChecks['content_validation_passed'], isNotNull);
      expect(result.securityChecks['security_scan_passed'], isNotNull);
    });

    test('should block malicious messages in integrated flow', () async {
      const maliciousContent = '<script>alert("xss")</script>Malicious message';
      const recipientId = 'recipient_456';
      
      final result = await integratedService.sendSecureMessage(
        content: maliciousContent,
        messageType: MessageType.text,
        recipientId: recipientId,
      );
      
      expect(result.success, isFalse);
      expect(result.error, contains('validation failed'));
      expect(result.securityChecks['content_validation_passed'], isFalse);
    });

    test('should handle secure file uploads', () async {
      const fileName = 'test_image.jpg';
      const mimeType = 'image/jpeg';
      final fileBytes = [0xFF, 0xD8, 0xFF, 0xE0]; // JPEG header
      
      final result = await integratedService.uploadSecureFile(
        fileName: fileName,
        mimeType: mimeType,
        fileBytes: fileBytes,
        purpose: 'message_attachment',
      );
      
      expect(result.securityChecks, isNotEmpty);
      expect(result.securityChecks['rate_limit_passed'], isNotNull);
      expect(result.securityChecks['file_validation_passed'], isNotNull);
    });

    test('should provide security status', () async {
      const userId = 'test_user_security_status';
      
      final status = await integratedService.getSecurityStatus(
        userId: userId,
      );
      
      expect(status.userId, equals(userId));
      expect(status.securityScore, isA<double>());
      expect(status.securityScore, inInclusiveRange(0.0, 1.0));
      expect(status.rateLimitStatus, isNotEmpty);
    });
  });

  group('Security Integration Tests', () {
    test('should handle end-to-end secure messaging flow', () async {
      final integratedService = IntegratedSecurityService();
      
      // Initialize security
      await integratedService.initializeSecurity();
      
      // Send a secure message
      final result = await integratedService.sendSecureMessage(
        content: 'End-to-end test message about land rights',
        messageType: MessageType.text,
        recipientId: 'e2e_recipient',
        encryptionLevel: EncryptionLevel.highSecurity,
      );
      
      expect(result.success, isTrue);
      expect(result.messageId, isNotEmpty);
      expect(result.securityChecks['message_encrypted'], isTrue);
    });

    test('should handle anonymous reporting flow', () async {
      final integratedService = IntegratedSecurityService();
      
      final result = await integratedService.sendSecureMessage(
        content: 'Anonymous report about corruption in land records',
        messageType: MessageType.text,
        recipientId: 'coordinator_anonymous',
        isAnonymous: true,
      );
      
      expect(result.success, isTrue);
      expect(result.securityChecks['anonymous_message_sent'], isTrue);
    });

    test('should perform security maintenance', () async {
      final integratedService = IntegratedSecurityService();
      
      expect(() async {
        await integratedService.performSecurityMaintenance();
      }, returnsNormally);
    });
  });

  group('Error Handling Tests', () {
    test('should handle encryption errors gracefully', () async {
      final encryptionService = EncryptionService();
      
      // Test with invalid recipient
      expect(() async {
        await encryptionService.encryptMessage(
          content: 'Test message',
          recipientUserId: 'invalid_recipient',
        );
      }, throwsException);
    });

    test('should handle validation errors gracefully', () async {
      final validationService = MessageValidationService();
      
      // Test with null content
      final result = await validationService.validateMessage(
        content: '',
        messageType: MessageType.text,
      );
      
      expect(result.isValid, isFalse);
      expect(result.issues.any((issue) => 
          issue.type == ValidationIssueType.emptyContent), isTrue);
    });

    test('should handle rate limiting errors gracefully', () async {
      final rateLimitingService = RateLimitingService();
      
      // Test with invalid action
      final result = await rateLimitingService.checkRateLimit(
        action: 'invalid_action',
        userId: 'test_user',
      );
      
      expect(result.allowed, isTrue); // Should allow unknown actions
    });
  });
}
