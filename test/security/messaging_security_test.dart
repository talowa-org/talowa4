// Security Tests for Messaging System
// Tests encryption validation, authentication, and security vulnerabilities

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';

// Import security services
import 'package:talowa/services/messaging/encryption_service.dart';
import 'package:talowa/services/messaging/anonymous_messaging_service.dart';
import 'package:talowa/services/messaging/message_validation_service.dart';
import 'package:talowa/services/security/rate_limiting_service.dart';
import 'package:talowa/services/security/audit_logging_service.dart';
import 'package:talowa/services/messaging/integrated_security_service.dart';

// Import models
import 'package:talowa/models/message_model.dart';

class SecurityTestUtils {
  static String generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  static Uint8List generateRandomBytes(int length) {
    final random = Random();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  static String calculateSHA256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool isValidBase64(String input) {
    try {
      base64.decode(input);
      return true;
    } catch (e) {
      return false;
    }
  }
}

void main() {
  group('Messaging Security Tests', () {
    late EncryptionService encryptionService;
    late MessageValidationService validationService;
    late RateLimitingService rateLimitingService;
    late AuditLoggingService auditService;
    late AnonymousMessagingService anonymousService;
    late IntegratedSecurityService integratedService;

    setUp(() {
      encryptionService = EncryptionService();
      validationService = MessageValidationService();
      rateLimitingService = RateLimitingService();
      auditService = AuditLoggingService();
      anonymousService = AnonymousMessagingService();
      integratedService = IntegratedSecurityService();
    });

    group('Encryption Security Tests', () {
      test('should use strong encryption algorithms', () async {
        await encryptionService.initializeUserEncryption();
        
        const testMessage = 'Sensitive land rights information';
        
        final encrypted = await encryptionService.encryptMessage(
          content: testMessage,
          recipientUserId: 'test_recipient',
          level: EncryptionLevel.highSecurity,
        );
        
        // Verify encryption algorithm
        expect(encrypted.algorithm, contains('AES-256'));
        expect(encrypted.algorithm, contains('GCM'));
        
        // Verify encrypted data is not readable
        expect(encrypted.data, isNot(contains(testMessage)));
        expect(SecurityTestUtils.isValidBase64(encrypted.data), isTrue);
        
        // Verify IV is present and unique
        expect(encrypted.iv, isNotEmpty);
        expect(encrypted.iv.length, greaterThanOrEqualTo(24)); // Base64 encoded 16-byte IV
        
        // Verify key fingerprint
        expect(encrypted.keyFingerprint, isNotEmpty);
        expect(encrypted.keyFingerprint.length, equals(64)); // SHA-256 hash
      });

      test('should generate cryptographically secure keys', () async {
        await encryptionService.initializeUserEncryption();
        
        final keyPairs = <KeyPair>[];
        
        // Generate multiple key pairs
        for (int i = 0; i < 10; i++) {
          final keyPair = await encryptionService.generateKeyPair('user_$i');
          keyPairs.add(keyPair);
        }
        
        // Verify all keys are unique
        final publicKeys = keyPairs.map((kp) => kp.publicKey).toSet();
        final privateKeys = keyPairs.map((kp) => kp.privateKey).toSet();
        
        expect(publicKeys.length, equals(keyPairs.length));
        expect(privateKeys.length, equals(keyPairs.length));
        
        // Verify key length (RSA-4096 keys should be substantial)
        for (final keyPair in keyPairs) {
          expect(keyPair.publicKey.length, greaterThan(500));
          expect(keyPair.privateKey.length, greaterThan(1000));
        }
      });

      test('should prevent key reuse vulnerabilities', () async {
        await encryptionService.initializeUserEncryption();
        
        const testMessage = 'Test message for key reuse check';
        const recipientId = 'key_reuse_test_recipient';
        
        // Encrypt same message multiple times
        final encrypted1 = await encryptionService.encryptMessage(
          content: testMessage,
          recipientUserId: recipientId,
          level: EncryptionLevel.standard,
        );
        
        final encrypted2 = await encryptionService.encryptMessage(
          content: testMessage,
          recipientUserId: recipientId,
          level: EncryptionLevel.standard,
        );
        
        // Verify different IVs are used (prevents identical ciphertext)
        expect(encrypted1.iv, isNot(equals(encrypted2.iv)));
        expect(encrypted1.data, isNot(equals(encrypted2.data)));
        
        // Verify both decrypt to same plaintext
        final decrypted1 = await encryptionService.decryptMessage(encrypted1);
        final decrypted2 = await encryptionService.decryptMessage(encrypted2);
        
        expect(decrypted1, equals(testMessage));
        expect(decrypted2, equals(testMessage));
      });

      test('should handle key rotation securely', () async {
        await encryptionService.initializeUserEncryption();
        
        const userId = 'key_rotation_test_user';
        
        // Generate initial key pair
        final initialKeyPair = await encryptionService.generateKeyPair(userId);
        
        // Encrypt message with initial key
        const testMessage = 'Message encrypted with initial key';
        final encrypted = await encryptionService.encryptMessage(
          content: testMessage,
          recipientUserId: userId,
          level: EncryptionLevel.standard,
        );
        
        // Rotate keys
        await encryptionService.rotateKeys(userId);
        final newKeyPair = await encryptionService.getKeyPair(userId);
        
        // Verify keys have changed
        expect(newKeyPair.publicKey, isNot(equals(initialKeyPair.publicKey)));
        expect(newKeyPair.privateKey, isNot(equals(initialKeyPair.privateKey)));
        
        // Verify old encrypted message can still be decrypted
        final decrypted = await encryptionService.decryptMessage(encrypted);
        expect(decrypted, equals(testMessage));
        
        // Verify new messages use new key
        const newMessage = 'Message encrypted with new key';
        final newEncrypted = await encryptionService.encryptMessage(
          content: newMessage,
          recipientUserId: userId,
          level: EncryptionLevel.standard,
        );
        
        expect(newEncrypted.keyFingerprint, isNot(equals(encrypted.keyFingerprint)));
      });

      test('should protect against timing attacks', () async {
        await encryptionService.initializeUserEncryption();
        
        const validMessage = 'Valid message content';
        const invalidMessage = 'Invalid message content with different length and special chars!@#$%';
        
        final timings = <Duration>[];
        
        // Measure encryption times for different message lengths
        for (int i = 0; i < 20; i++) {
          final stopwatch = Stopwatch()..start();
          
          await encryptionService.encryptMessage(
            content: i % 2 == 0 ? validMessage : invalidMessage,
            recipientUserId: 'timing_test_recipient',
            level: EncryptionLevel.standard,
          );
          
          stopwatch.stop();
          timings.add(stopwatch.elapsed);
        }
        
        // Calculate timing variance
        final averageTime = timings.map((t) => t.inMicroseconds).reduce((a, b) => a + b) / timings.length;
        final variance = timings.map((t) => (t.inMicroseconds - averageTime) * (t.inMicroseconds - averageTime))
            .reduce((a, b) => a + b) / timings.length;
        final standardDeviation = sqrt(variance);
        
        // Timing should be relatively consistent (low standard deviation)
        expect(standardDeviation / averageTime, lessThan(0.5)); // Less than 50% variance
      });

      test('should validate encryption integrity', () async {
        await encryptionService.initializeUserEncryption();
        
        const testMessage = 'Message for integrity testing';
        
        final encrypted = await encryptionService.encryptMessage(
          content: testMessage,
          recipientUserId: 'integrity_test_recipient',
          level: EncryptionLevel.highSecurity,
        );
        
        // Tamper with encrypted data
        final tamperedData = '${encrypted.data.substring(0, encrypted.data.length - 10)}TAMPERED!!';
        final tamperedEncrypted = EncryptedContent(
          data: tamperedData,
          iv: encrypted.iv,
          algorithm: encrypted.algorithm,
          keyFingerprint: encrypted.keyFingerprint,
        );
        
        // Attempt to decrypt tampered data should fail
        expect(() async {
          await encryptionService.decryptMessage(tamperedEncrypted);
        }, throwsException);
        
        // Original data should still decrypt correctly
        final decrypted = await encryptionService.decryptMessage(encrypted);
        expect(decrypted, equals(testMessage));
      });
    });

    group('Authentication Security Tests', () {
      test('should validate message sender authentication', () async {
        final message = MessageModel(
          id: 'auth_test_msg',
          senderId: 'authenticated_sender',
          recipientId: 'test_recipient',
          content: 'Authenticated message',
          messageType: MessageType.text,
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
        );
        
        // Test with valid authentication
        final validResult = await integratedService.validateMessageAuthentication(
          message: message,
          authToken: 'valid_auth_token',
        );
        
        expect(validResult.isValid, isTrue);
        expect(validResult.userId, equals('authenticated_sender'));
        
        // Test with invalid authentication
        final invalidResult = await integratedService.validateMessageAuthentication(
          message: message,
          authToken: 'invalid_auth_token',
        );
        
        expect(invalidResult.isValid, isFalse);
        expect(invalidResult.error, contains('authentication'));
      });

      test('should prevent session hijacking', () async {
        const userId = 'session_test_user';
        const validSessionToken = 'valid_session_token_123';
        const hijackedToken = 'hijacked_session_token_456';
        
        // Create valid session
        await integratedService.createUserSession(userId, validSessionToken);
        
        // Validate legitimate session
        final validSession = await integratedService.validateSession(validSessionToken);
        expect(validSession.isValid, isTrue);
        expect(validSession.userId, equals(userId));
        
        // Attempt to use hijacked token
        final hijackedSession = await integratedService.validateSession(hijackedToken);
        expect(hijackedSession.isValid, isFalse);
        
        // Verify session fingerprinting
        final sessionInfo = await integratedService.getSessionInfo(validSessionToken);
        expect(sessionInfo.deviceFingerprint, isNotEmpty);
        expect(sessionInfo.ipAddress, isNotEmpty);
      });

      test('should enforce token expiration', () async {
        const userId = 'token_expiry_test_user';
        
        // Create short-lived token
        final shortToken = await integratedService.createAuthToken(
          userId: userId,
          expirationDuration: const Duration(milliseconds: 100),
        );
        
        // Token should be valid initially
        final initialValidation = await integratedService.validateAuthToken(shortToken);
        expect(initialValidation.isValid, isTrue);
        
        // Wait for token to expire
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Token should be invalid after expiration
        final expiredValidation = await integratedService.validateAuthToken(shortToken);
        expect(expiredValidation.isValid, isFalse);
        expect(expiredValidation.error, contains('expired'));
      });

      test('should detect and prevent brute force attacks', () async {
        const userId = 'brute_force_test_user';
        const correctPassword = 'correct_password_123';
        const wrongPassword = 'wrong_password_456';
        
        // Simulate multiple failed login attempts
        for (int i = 0; i < 10; i++) {
          final result = await integratedService.authenticateUser(userId, wrongPassword);
          expect(result.success, isFalse);
        }
        
        // Account should be locked after multiple failures
        final lockedResult = await integratedService.authenticateUser(userId, correctPassword);
        expect(lockedResult.success, isFalse);
        expect(lockedResult.error, contains('locked'));
        
        // Verify lockout duration
        final lockoutInfo = await integratedService.getAccountLockoutInfo(userId);
        expect(lockoutInfo.isLocked, isTrue);
        expect(lockoutInfo.lockoutExpiry, isA<DateTime>());
      });
    });

    group('Input Validation Security Tests', () {
      test('should prevent XSS attacks in messages', () async {
        final xssPayloads = [
          '<script>alert("xss")</script>',
          '<img src="x" onerror="alert(1)">',
          'javascript:alert("xss")',
          '<svg onload="alert(1)">',
          '"><script>alert("xss")</script>',
          '<iframe src="javascript:alert(1)"></iframe>',
        ];
        
        for (final payload in xssPayloads) {
          final result = await validationService.validateMessage(
            content: payload,
            messageType: MessageType.text,
          );
          
          expect(result.isValid, isFalse);
          expect(result.issues.any((issue) => 
              issue.type == ValidationIssueType.maliciousContent), isTrue);
          expect(result.sanitizedContent, isNot(contains('<script')));
          expect(result.sanitizedContent, isNot(contains('javascript:')));
        }
      });

      test('should prevent SQL injection in search queries', () async {
        final sqlInjectionPayloads = [
          "'; DROP TABLE messages; --",
          "' OR '1'='1",
          "'; INSERT INTO messages VALUES ('malicious'); --",
          "' UNION SELECT * FROM users --",
          "'; UPDATE users SET password='hacked' --",
        ];
        
        for (final payload in sqlInjectionPayloads) {
          final result = await validationService.validateSearchQuery(payload);
          
          expect(result.isValid, isFalse);
          expect(result.issues.any((issue) => 
              issue.type == ValidationIssueType.sqlInjection), isTrue);
          expect(result.sanitizedQuery, isNot(contains('DROP')));
          expect(result.sanitizedQuery, isNot(contains('INSERT')));
          expect(result.sanitizedQuery, isNot(contains('UPDATE')));
        }
      });

      test('should validate file uploads for malicious content', () async {
        // Test malicious file types
        final maliciousFiles = [
          {
            'name': 'malware.exe',
            'type': 'application/x-executable',
            'content': [0x4D, 0x5A, 0x90, 0x00], // PE executable header
          },
          {
            'name': 'script.js',
            'type': 'application/javascript',
            'content': utf8.encode('alert("malicious")'),
          },
          {
            'name': 'fake_image.jpg',
            'type': 'image/jpeg',
            'content': utf8.encode('<script>alert("xss")</script>'), // Not actually JPEG
          },
        ];
        
        for (final file in maliciousFiles) {
          final result = await validationService.validateFile(
            fileName: file['name'] as String,
            mimeType: file['type'] as String,
            fileSize: (file['content'] as List<int>).length,
            fileBytes: file['content'] as List<int>,
          );
          
          expect(result.isValid, isFalse);
          expect(result.quarantined, isTrue);
          expect(result.issues.any((issue) => 
              issue.type == ValidationIssueType.maliciousFile || 
              issue.type == ValidationIssueType.invalidFileType), isTrue);
        }
      });

      test('should detect and prevent path traversal attacks', () async {
        final pathTraversalPayloads = [
          '../../../etc/passwd',
          '..\\..\\..\\windows\\system32\\config\\sam',
          '/etc/shadow',
          'C:\\Windows\\System32\\drivers\\etc\\hosts',
          '....//....//....//etc/passwd',
        ];
        
        for (final payload in pathTraversalPayloads) {
          final result = await validationService.validateFilePath(payload);
          
          expect(result.isValid, isFalse);
          expect(result.issues.any((issue) => 
              issue.type == ValidationIssueType.pathTraversal), isTrue);
          expect(result.sanitizedPath, isNot(contains('..')));
          expect(result.sanitizedPath, isNot(contains('/etc/')));
          expect(result.sanitizedPath, isNot(contains('C:\\')));
        }
      });
    });

    group('Rate Limiting Security Tests', () {
      test('should enforce message rate limits', () async {
        const userId = 'rate_limit_test_user';
        const action = 'send_message';
        
        // Send messages up to the limit
        for (int i = 0; i < 60; i++) { // Assuming 60 messages per minute limit
          final result = await rateLimitingService.checkRateLimit(
            action: action,
            userId: userId,
          );
          
          if (i < 59) {
            expect(result.allowed, isTrue);
          }
        }
        
        // Next message should be rate limited
        final limitedResult = await rateLimitingService.checkRateLimit(
          action: action,
          userId: userId,
        );
        
        expect(limitedResult.allowed, isFalse);
        expect(limitedResult.penaltyActive, isTrue);
        expect(limitedResult.retryAfter, greaterThan(0));
      });

      test('should handle burst rate limiting', () async {
        const userId = 'burst_limit_test_user';
        const action = 'send_message';
        
        // Send messages rapidly to trigger burst limit
        final futures = <Future>[];
        for (int i = 0; i < 20; i++) {
          futures.add(rateLimitingService.checkRateLimit(
            action: action,
            userId: userId,
          ));
        }
        
        final results = await Future.wait(futures);
        
        // Some requests should be blocked due to burst limit
        final blockedCount = results.where((r) => !r.allowed).length;
        expect(blockedCount, greaterThan(0));
        
        // Verify burst limit penalty
        final penalizedResults = results.where((r) => r.penaltyActive);
        expect(penalizedResults.isNotEmpty, isTrue);
      });

      test('should implement progressive penalties', () async {
        const userId = 'progressive_penalty_test_user';
        const action = 'send_message';
        
        // First violation
        await _triggerRateLimit(rateLimitingService, userId, action);
        final firstPenalty = await rateLimitingService.getPenaltyInfo(userId, action);
        
        // Second violation (should have longer penalty)
        await Future.delayed(Duration(seconds: firstPenalty.penaltyDuration + 1));
        await _triggerRateLimit(rateLimitingService, userId, action);
        final secondPenalty = await rateLimitingService.getPenaltyInfo(userId, action);
        
        expect(secondPenalty.penaltyDuration, greaterThan(firstPenalty.penaltyDuration));
        expect(secondPenalty.violationCount, equals(2));
      });
    });

    group('Anonymous Messaging Security Tests', () {
      test('should protect sender identity in anonymous messages', () async {
        const reportContent = 'Anonymous report about corruption';
        const coordinatorId = 'coordinator_security_test';
        
        final caseId = await anonymousService.sendAnonymousReport(
          content: reportContent,
          coordinatorId: coordinatorId,
          reportType: ReportType.corruption,
        );
        
        // Verify case ID doesn't contain sender information
        expect(caseId, startsWith('ANON-'));
        expect(caseId, isNot(contains('sender')));
        expect(caseId, isNot(contains('user')));
        
        // Verify message metadata doesn't leak identity
        final caseDetails = await anonymousService.getAnonymousCaseDetails(caseId);
        expect(caseDetails.senderInfo, isNull);
        expect(caseDetails.senderMetadata, isEmpty);
      });

      test('should generalize location data for privacy', () async {
        final preciseLocation = {
          'latitude': 17.385044,
          'longitude': 78.486671,
          'accuracy': 5.0,
          'address': '123 Specific Street, Exact Building',
          'villageCode': 'VIL001',
          'villageName': 'Test Village',
        };
        
        final generalizedLocation = await anonymousService.generalizeLocation(preciseLocation);
        
        // Precise coordinates should be removed
        expect(generalizedLocation['latitude'], isNull);
        expect(generalizedLocation['longitude'], isNull);
        expect(generalizedLocation['accuracy'], isNull);
        expect(generalizedLocation['address'], isNull);
        
        // Only general location should remain
        expect(generalizedLocation['villageCode'], equals('VIL001'));
        expect(generalizedLocation['villageName'], equals('Test Village'));
      });

      test('should prevent correlation attacks on anonymous messages', () async {
        const coordinatorId = 'correlation_test_coordinator';
        
        // Send multiple anonymous reports from same sender
        final caseIds = <String>[];
        for (int i = 0; i < 5; i++) {
          final caseId = await anonymousService.sendAnonymousReport(
            content: 'Anonymous report #$i with different content and timing',
            coordinatorId: coordinatorId,
            reportType: ReportType.landGrabbing,
          );
          caseIds.add(caseId);
          
          // Add random delay to prevent timing correlation
          await Future.delayed(Duration(milliseconds: Random().nextInt(1000)));
        }
        
        // Verify case IDs are not sequential or predictable
        for (int i = 1; i < caseIds.length; i++) {
          expect(caseIds[i], isNot(equals(caseIds[i-1])));
          
          // Extract timestamp parts and verify they're not sequential
          final timestamp1 = caseIds[i-1].split('-')[1];
          final timestamp2 = caseIds[i].split('-')[1];
          expect(timestamp2, isNot(equals(timestamp1)));
        }
      });
    });

    group('Audit Logging Security Tests', () {
      test('should log security-sensitive operations', () async {
        const userId = 'audit_test_user';
        
        // Perform security-sensitive operations
        await integratedService.authenticateUser(userId, 'password');
        await integratedService.createAuthToken(userId: userId);
        await encryptionService.rotateKeys(userId);
        
        // Verify audit logs were created
        final auditLogs = await auditService.getAuditLogs(
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(minutes: 1)),
          endTime: DateTime.now(),
        );
        
        expect(auditLogs.length, greaterThanOrEqualTo(3));
        
        final logTypes = auditLogs.map((log) => log.eventType).toSet();
        expect(logTypes, contains('authentication'));
        expect(logTypes, contains('token_creation'));
        expect(logTypes, contains('key_rotation'));
      });

      test('should detect suspicious activity patterns', () async {
        const userId = 'suspicious_activity_user';
        
        // Simulate suspicious activity
        for (int i = 0; i < 10; i++) {
          await integratedService.authenticateUser(userId, 'wrong_password');
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        // Check for suspicious activity detection
        final suspiciousActivity = await auditService.detectSuspiciousActivity(userId);
        
        expect(suspiciousActivity.isDetected, isTrue);
        expect(suspiciousActivity.riskScore, greaterThan(0.7));
        expect(suspiciousActivity.patterns, contains('multiple_failed_logins'));
      });

      test('should maintain audit log integrity', () async {
        const userId = 'audit_integrity_user';
        const eventType = 'test_event';
        const eventData = {'action': 'security_test', 'timestamp': DateTime.now().toIso8601String()};
        
        // Create audit log entry
        final logId = await auditService.createAuditLog(
          userId: userId,
          eventType: eventType,
          eventData: eventData,
        );
        
        // Retrieve audit log
        final auditLog = await auditService.getAuditLog(logId);
        expect(auditLog, isNotNull);
        
        // Verify integrity hash
        final expectedHash = SecurityTestUtils.calculateSHA256(
          '${auditLog!.userId}:${auditLog.eventType}:${auditLog.timestamp.toIso8601String()}:${jsonEncode(auditLog.eventData)}'
        );
        
        expect(auditLog.integrityHash, equals(expectedHash));
        
        // Attempt to tamper with audit log should be detectable
        final tamperedLog = auditLog.copyWith(eventData: {'tampered': 'data'});
        final integrityCheck = await auditService.verifyAuditLogIntegrity(tamperedLog);
        
        expect(integrityCheck.isValid, isFalse);
        expect(integrityCheck.tamperedFields, contains('eventData'));
      });
    });

    group('Penetration Testing Scenarios', () {
      test('should resist common attack vectors', () async {
        final attackVectors = [
          // Buffer overflow attempts
          'A' * 10000,
          // Format string attacks
          '%s%s%s%s%s%s%s%s%s%s',
          // Unicode attacks
          '\u0000\u0001\u0002\u0003',
          // Control character injection
          '\r\n\r\nHTTP/1.1 200 OK\r\n\r\n<script>alert(1)</script>',
        ];
        
        for (final attack in attackVectors) {
          final result = await validationService.validateMessage(
            content: attack,
            messageType: MessageType.text,
          );
          
          // All attacks should be blocked or sanitized
          expect(result.isValid || result.sanitizedContent != attack, isTrue);
          
          if (!result.isValid) {
            expect(result.issues.isNotEmpty, isTrue);
          }
        }
      });

      test('should handle resource exhaustion attacks', () async {
        // Test with extremely large messages
        final largeMessage = 'A' * (10 * 1024 * 1024); // 10MB message
        
        final result = await validationService.validateMessage(
          content: largeMessage,
          messageType: MessageType.text,
        );
        
        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => 
            issue.type == ValidationIssueType.contentTooLarge), isTrue);
        
        // Test with deeply nested JSON
        var nestedJson = '{"a":';
        for (int i = 0; i < 1000; i++) {
          nestedJson += '{"b":';
        }
        nestedJson += '"value"';
        for (int i = 0; i < 1000; i++) {
          nestedJson += '}';
        }
        nestedJson += '}';
        
        final jsonResult = await validationService.validateMessage(
          content: nestedJson,
          messageType: MessageType.text,
        );
        
        expect(jsonResult.isValid, isFalse);
        expect(jsonResult.issues.any((issue) => 
            issue.type == ValidationIssueType.complexityTooHigh), isTrue);
      });
    });
  });
}

// Helper function to trigger rate limit
Future<void> _triggerRateLimit(RateLimitingService service, String userId, String action) async {
  // Send requests until rate limited
  while (true) {
    final result = await service.checkRateLimit(action: action, userId: userId);
    if (!result.allowed) break;
    await Future.delayed(const Duration(milliseconds: 10));
  }
}