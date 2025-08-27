import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import '../test_utils/security_test_helpers.dart';
import '../test_utils/mock_services.dart';
import 'package:talowa/services/messaging/encryption_service.dart';
import 'package:talowa/services/auth/authentication_service.dart';
import 'package:talowa/services/messaging/websocket_service.dart';
import 'package:talowa/services/messaging/file_service.dart';

/// Comprehensive security audit and penetration testing suite
/// Tests all security aspects of the TALOWA messaging system
class ComprehensiveSecurityAudit {
  static Future<void> runSecurityAudit() async {
    group('Security Audit and Penetration Testing', () {
      late MockEncryptionService encryptionService;
      late MockAuthenticationService authService;
      late MockWebSocketService websocketService;
      late MockFileService fileService;

      setUp(() async {
        encryptionService = MockEncryptionService();
        authService = MockAuthenticationService();
        websocketService = MockWebSocketService();
        fileService = MockFileService();
      });

      group('1. Authentication Security Tests', () {
        test('should prevent brute force attacks on login', () async {
          const phoneNumber = '+919876543210';
          
          // Attempt multiple failed logins
          for (int i = 0; i < 6; i++) {
            final result = await authService.login(
              phoneNumber: phoneNumber,
              pin: 'wrong_pin_$i',
            );
            
            if (i < 5) {
              expect(result.success, isFalse);
              expect(result.attemptsRemaining, equals(4 - i));
            } else {
              // 6th attempt should be blocked
              expect(result.success, isFalse);
              expect(result.isBlocked, isTrue);
              expect(result.blockDuration, greaterThan(const Duration(minutes: 15)));
            }
          }
        });

        test('should validate phone number format and prevent injection', () async {
          final maliciousInputs = [
            '+91\'; DROP TABLE users; --',
            '+91<script>alert("xss")</script>',
            '+91${String.fromCharCodes(List.filled(1000, 65))}', // Buffer overflow attempt
            '+91\x00\x01\x02', // Null byte injection
            '+91\n\r\t', // Control characters
          ];

          for (final input in maliciousInputs) {
            final result = await authService.validatePhoneNumber(input);
            expect(result.isValid, isFalse);
            expect(result.sanitizedInput, isNot(contains(RegExp(r'[<>\'";]'))));
          }
        });

        test('should implement secure session management', () async {
          final user = await SecurityTestHelpers.createTestUser();
          final session = await authService.createSession(user.id);

          // Verify session token properties
          expect(session.token.length, greaterThanOrEqualTo(32));
          expect(session.expiresAt.isAfter(DateTime.now()), isTrue);
          expect(session.isSecure, isTrue);
          expect(session.httpOnly, isTrue);

          // Test session rotation
          final newSession = await authService.rotateSession(session.token);
          expect(newSession.token, isNot(equals(session.token)));
          
          // Old session should be invalidated
          final oldSessionValid = await authService.validateSession(session.token);
          expect(oldSessionValid, isFalse);
        });

        test('should prevent session fixation attacks', () async {
          final user = await SecurityTestHelpers.createTestUser();
          
          // Attacker provides session ID
          const attackerSessionId = 'attacker_controlled_session_123';
          
          // System should reject pre-set session IDs
          final result = await authService.loginWithSessionId(
            user.phoneNumber,
            'correct_pin',
            attackerSessionId,
          );
          
          expect(result.success, isTrue);
          expect(result.sessionId, isNot(equals(attackerSessionId)));
          expect(result.sessionId, isNot(isEmpty));
        });
      });

      group('2. Encryption Security Tests', () {
        test('should use strong encryption algorithms', () async {
          final keyPair = await encryptionService.generateKeyPair('test_user');
          
          // Verify RSA key strength
          expect(keyPair.publicKey.length, greaterThanOrEqualTo(512)); // RSA-4096
          expect(keyPair.privateKey.length, greaterThanOrEqualTo(512));
          
          // Test AES encryption
          const plaintext = 'Sensitive land rights information';
          final encrypted = await encryptionService.encryptMessage(
            plaintext,
            keyPair.publicKey,
          );
          
          expect(encrypted.algorithm, equals('AES-256-GCM'));
          expect(encrypted.iv.length, equals(16)); // 128-bit IV
          expect(encrypted.data, isNot(contains(plaintext)));
          
          // Verify decryption
          final decrypted = await encryptionService.decryptMessage(
            encrypted,
            keyPair.privateKey,
          );
          expect(decrypted, equals(plaintext));
        });

        test('should prevent cryptographic attacks', () async {
          final keyPair = await encryptionService.generateKeyPair('test_user');
          const plaintext = 'Test message';

          // Test against padding oracle attacks
          final encrypted = await encryptionService.encryptMessage(
            plaintext,
            keyPair.publicKey,
          );

          // Modify ciphertext to test padding validation
          final modifiedCiphertext = encrypted.copyWith(
            data: encrypted.data.substring(0, encrypted.data.length - 1) + 'X',
          );

          expect(
            () => encryptionService.decryptMessage(modifiedCiphertext, keyPair.privateKey),
            throwsA(isA<CryptographicException>()),
          );

          // Test against timing attacks
          final startTime = DateTime.now();
          try {
            await encryptionService.decryptMessage(modifiedCiphertext, keyPair.privateKey);
          } catch (e) {
            // Expected to fail
          }
          final endTime = DateTime.now();
          
          // Decryption should take consistent time regardless of error type
          final decryptionTime = endTime.difference(startTime);
          expect(decryptionTime.inMilliseconds, lessThan(100));
        });

        test('should implement secure key management', () async {
          const userId = 'test_user_123';
          
          // Generate initial key pair
          final keyPair1 = await encryptionService.generateKeyPair(userId);
          
          // Rotate keys
          await encryptionService.rotateKeys(userId);
          final keyPair2 = await encryptionService.getKeyPair(userId);
          
          // New keys should be different
          expect(keyPair2.publicKey, isNot(equals(keyPair1.publicKey)));
          expect(keyPair2.privateKey, isNot(equals(keyPair1.privateKey)));
          
          // Old keys should still be accessible for decryption of old messages
          final oldKeyPair = await encryptionService.getHistoricalKeyPair(
            userId,
            keyPair1.keyId,
          );
          expect(oldKeyPair.publicKey, equals(keyPair1.publicKey));
        });

        test('should protect against key extraction attacks', () async {
          final keyPair = await encryptionService.generateKeyPair('test_user');
          
          // Private key should never be exposed in logs or error messages
          final logOutput = await SecurityTestHelpers.captureLogOutput(() async {
            try {
              await encryptionService.decryptMessage(
                EncryptedContent(
                  data: 'invalid_data',
                  iv: 'invalid_iv',
                  algorithm: 'AES-256-GCM',
                  keyFingerprint: 'invalid',
                ),
                keyPair.privateKey,
              );
            } catch (e) {
              // Expected to fail
            }
          });
          
          expect(logOutput, isNot(contains(keyPair.privateKey)));
          expect(logOutput, isNot(contains('BEGIN PRIVATE KEY')));
        });
      });

      group('3. WebSocket Security Tests', () {
        test('should validate WebSocket authentication', () async {
          // Test connection without authentication
          final unauthenticatedResult = await websocketService.connect(
            userId: 'test_user',
            authToken: '',
          );
          expect(unauthenticatedResult.success, isFalse);
          expect(unauthenticatedResult.error, contains('authentication'));

          // Test connection with invalid token
          final invalidTokenResult = await websocketService.connect(
            userId: 'test_user',
            authToken: 'invalid_token_123',
          );
          expect(invalidTokenResult.success, isFalse);
          expect(invalidTokenResult.error, contains('invalid token'));

          // Test connection with expired token
          final expiredToken = await SecurityTestHelpers.createExpiredToken('test_user');
          final expiredTokenResult = await websocketService.connect(
            userId: 'test_user',
            authToken: expiredToken,
          );
          expect(expiredTokenResult.success, isFalse);
          expect(expiredTokenResult.error, contains('expired'));
        });

        test('should prevent WebSocket injection attacks', () async {
          final validToken = await SecurityTestHelpers.createValidToken('test_user');
          final connection = await websocketService.connect(
            userId: 'test_user',
            authToken: validToken,
          );

          final maliciousPayloads = [
            '{"type":"message","content":"<script>alert(\\"xss\\")</script>"}',
            '{"type":"message","content":"\\"; DROP TABLE messages; --"}',
            '{"type":"message","content":"${String.fromCharCodes(List.filled(10000, 65))}"}',
            '{"type":"message","content":"\\x00\\x01\\x02"}',
          ];

          for (final payload in maliciousPayloads) {
            final result = await websocketService.sendRawMessage(
              connection.connectionId,
              payload,
            );
            
            expect(result.success, isFalse);
            expect(result.error, contains('validation failed'));
          }
        });

        test('should implement rate limiting', () async {
          final validToken = await SecurityTestHelpers.createValidToken('test_user');
          final connection = await websocketService.connect(
            userId: 'test_user',
            authToken: validToken,
          );

          // Send messages rapidly to trigger rate limiting
          final results = <MessageResult>[];
          for (int i = 0; i < 100; i++) {
            final result = await websocketService.sendMessage(
              connection.connectionId,
              MessagePayload(
                id: 'msg_$i',
                type: 'text',
                content: 'Test message $i',
                recipientId: 'recipient_123',
                timestamp: DateTime.now().millisecondsSinceEpoch,
                clientId: 'client_123',
                encryptionLevel: 'standard',
                isAnonymous: false,
              ),
            );
            results.add(result);
          }

          // Should have rate limiting after certain threshold
          final rateLimitedResults = results.where((r) => 
            !r.success && r.error.contains('rate limit')).toList();
          expect(rateLimitedResults.length, greaterThan(0));
        });

        test('should prevent connection hijacking', () async {
          final user1Token = await SecurityTestHelpers.createValidToken('user_1');
          final user2Token = await SecurityTestHelpers.createValidToken('user_2');

          final connection1 = await websocketService.connect(
            userId: 'user_1',
            authToken: user1Token,
          );

          // User 2 tries to use User 1's connection ID
          final hijackResult = await websocketService.sendMessage(
            connection1.connectionId,
            MessagePayload(
              id: 'hijack_msg',
              type: 'text',
              content: 'Hijacked message',
              recipientId: 'victim',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              clientId: 'user_2_client',
              encryptionLevel: 'standard',
              isAnonymous: false,
            ),
            authToken: user2Token,
          );

          expect(hijackResult.success, isFalse);
          expect(hijackResult.error, contains('unauthorized'));
        });
      });

      group('4. File Upload Security Tests', () {
        test('should validate file types and prevent malicious uploads', () async {
          final maliciousFiles = [
            {'name': 'malware.exe', 'content': 'MZ\x90\x00', 'mimeType': 'application/octet-stream'},
            {'name': 'script.php', 'content': '<?php system($_GET["cmd"]); ?>', 'mimeType': 'application/x-php'},
            {'name': 'fake.pdf.exe', 'content': 'MZ\x90\x00', 'mimeType': 'application/pdf'},
            {'name': 'huge_file.txt', 'content': 'A' * (50 * 1024 * 1024), 'mimeType': 'text/plain'}, // 50MB
          ];

          for (final file in maliciousFiles) {
            final result = await fileService.uploadFile(
              File.fromRawPath(file['content'] as String),
              FileMetadata(
                id: 'test_file',
                originalName: file['name'] as String,
                mimeType: file['mimeType'] as String,
                size: (file['content'] as String).length,
                uploadedBy: 'test_user',
                uploadedAt: DateTime.now().millisecondsSinceEpoch,
                isEncrypted: false,
                tags: [],
                accessLevel: 'private',
              ),
            );

            expect(result.success, isFalse);
            expect(result.error, anyOf([
              contains('file type not allowed'),
              contains('file too large'),
              contains('malware detected'),
              contains('suspicious extension'),
            ]));
          }
        });

        test('should scan files for malware', () async {
          final testFiles = [
            {'name': 'clean_document.pdf', 'content': '%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog', 'isMalicious': false},
            {'name': 'eicar_test.txt', 'content': 'X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*', 'isMalicious': true},
          ];

          for (final file in testFiles) {
            final scanResult = await fileService.scanFileForMalware(
              file['content'] as String,
            );

            if (file['isMalicious'] as bool) {
              expect(scanResult.isMalicious, isTrue);
              expect(scanResult.threats, isNotEmpty);
            } else {
              expect(scanResult.isMalicious, isFalse);
              expect(scanResult.threats, isEmpty);
            }
          }
        });

        test('should prevent path traversal attacks', () async {
          final maliciousPaths = [
            '../../../etc/passwd',
            '..\\..\\..\\windows\\system32\\config\\sam',
            '/etc/shadow',
            'C:\\Windows\\System32\\config\\SAM',
            '....//....//....//etc/passwd',
          ];

          for (final path in maliciousPaths) {
            final result = await fileService.getFileUrl(path);
            expect(result.success, isFalse);
            expect(result.error, contains('invalid file path'));
          }
        });

        test('should implement secure file access controls', () async {
          final user1 = await SecurityTestHelpers.createTestUser(id: 'user_1');
          final user2 = await SecurityTestHelpers.createTestUser(id: 'user_2');

          // User 1 uploads a private file
          final uploadResult = await fileService.uploadFile(
            File.fromRawPath('Private document content'),
            FileMetadata(
              id: 'private_file_123',
              originalName: 'private_document.pdf',
              mimeType: 'application/pdf',
              size: 100,
              uploadedBy: user1.id,
              uploadedAt: DateTime.now().millisecondsSinceEpoch,
              isEncrypted: true,
              tags: ['private'],
              accessLevel: 'private',
            ),
          );

          expect(uploadResult.success, isTrue);

          // User 2 tries to access User 1's private file
          final accessResult = await fileService.downloadFile(
            'private_file_123',
            requestingUserId: user2.id,
          );

          expect(accessResult.success, isFalse);
          expect(accessResult.error, contains('access denied'));
        });
      });

      group('5. Anonymous Messaging Security Tests', () {
        test('should protect sender identity in anonymous messages', () async {
          final sender = await SecurityTestHelpers.createTestUser();
          final recipient = await SecurityTestHelpers.createTestUser();

          final anonymousMessage = await websocketService.sendAnonymousMessage(
            content: 'Anonymous report about land grabbing',
            recipientId: recipient.id,
            senderId: sender.id,
          );

          expect(anonymousMessage.success, isTrue);
          expect(anonymousMessage.anonymousId, isNotEmpty);
          expect(anonymousMessage.anonymousId, isNot(equals(sender.id)));

          // Verify recipient cannot determine sender identity
          final receivedMessage = await websocketService.getMessage(
            anonymousMessage.messageId,
            requestingUserId: recipient.id,
          );

          expect(receivedMessage.senderId, isEmpty);
          expect(receivedMessage.anonymousId, isNotEmpty);
          expect(receivedMessage.senderName, equals('Anonymous'));
        });

        test('should prevent anonymous message correlation attacks', () async {
          final sender = await SecurityTestHelpers.createTestUser();
          final recipient = await SecurityTestHelpers.createTestUser();

          // Send multiple anonymous messages
          final messages = <AnonymousMessage>[];
          for (int i = 0; i < 10; i++) {
            final message = await websocketService.sendAnonymousMessage(
              content: 'Anonymous message $i',
              recipientId: recipient.id,
              senderId: sender.id,
            );
            messages.add(message);
          }

          // Verify each message has different anonymous ID
          final anonymousIds = messages.map((m) => m.anonymousId).toSet();
          expect(anonymousIds.length, equals(messages.length));

          // Verify timing analysis protection
          final timestamps = messages.map((m) => m.timestamp).toList();
          for (int i = 1; i < timestamps.length; i++) {
            final timeDiff = timestamps[i] - timestamps[i-1];
            expect(timeDiff, greaterThan(1000)); // At least 1 second delay
          }
        });

        test('should implement secure anonymous response system', () async {
          final reporter = await SecurityTestHelpers.createTestUser();
          final coordinator = await SecurityTestHelpers.createTestUser(role: 'coordinator');

          // Send anonymous report
          final report = await websocketService.sendAnonymousMessage(
            content: 'Land grabbing incident at Survey No. 123',
            recipientId: coordinator.id,
            senderId: reporter.id,
          );

          // Coordinator responds anonymously
          final response = await websocketService.respondToAnonymousMessage(
            originalMessageId: report.messageId,
            response: 'We have received your report and will investigate',
            responderId: coordinator.id,
          );

          expect(response.success, isTrue);
          expect(response.isAnonymous, isTrue);

          // Verify reporter receives response without coordinator identity
          final receivedResponse = await websocketService.getMessage(
            response.messageId,
            requestingUserId: reporter.id,
          );

          expect(receivedResponse.senderId, isEmpty);
          expect(receivedResponse.senderName, equals('Coordinator'));
          expect(receivedResponse.senderRole, equals('coordinator'));
        });
      });

      group('6. Data Privacy and GDPR Compliance Tests', () {
        test('should implement data minimization', () async {
          final user = await SecurityTestHelpers.createTestUser();
          
          // Send message with location data
          final message = await websocketService.sendMessage(
            'connection_id',
            MessagePayload(
              id: 'msg_with_location',
              type: 'text',
              content: 'Message with location',
              recipientId: 'recipient_123',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              clientId: 'client_123',
              encryptionLevel: 'standard',
              isAnonymous: false,
              location: {
                'latitude': 17.4239,
                'longitude': 78.3776,
                'accuracy': 10.0,
              },
            ),
          );

          // Verify location is generalized for privacy
          final storedMessage = await websocketService.getMessage(
            message.messageId,
            requestingUserId: user.id,
          );

          expect(storedMessage.location['latitude'], isNot(equals(17.4239)));
          expect(storedMessage.location['longitude'], isNot(equals(78.3776)));
          expect(storedMessage.location['accuracy'], greaterThan(100)); // Generalized
        });

        test('should support data export (right to portability)', () async {
          final user = await SecurityTestHelpers.createTestUser();
          
          // Create some user data
          await SecurityTestHelpers.createTestMessages(user.id, count: 10);
          await SecurityTestHelpers.createTestFiles(user.id, count: 5);
          await SecurityTestHelpers.createTestGroups(user.id, count: 3);

          // Request data export
          final exportResult = await websocketService.exportUserData(user.id);

          expect(exportResult.success, isTrue);
          expect(exportResult.exportFile, isNotEmpty);

          // Verify export contains all user data
          final exportData = await SecurityTestHelpers.parseExportFile(exportResult.exportFile);
          expect(exportData['messages'], hasLength(10));
          expect(exportData['files'], hasLength(5));
          expect(exportData['groups'], hasLength(3));
          expect(exportData['profile'], isNotEmpty);
        });

        test('should support data deletion (right to erasure)', () async {
          final user = await SecurityTestHelpers.createTestUser();
          
          // Create user data
          await SecurityTestHelpers.createTestMessages(user.id, count: 5);
          await SecurityTestHelpers.createTestFiles(user.id, count: 3);

          // Request data deletion
          final deletionResult = await websocketService.deleteUserData(
            user.id,
            deletionType: 'complete',
            retainLegalRecords: false,
          );

          expect(deletionResult.success, isTrue);
          expect(deletionResult.deletedRecords, greaterThan(0));

          // Verify data is actually deleted
          final remainingMessages = await SecurityTestHelpers.getUserMessages(user.id);
          expect(remainingMessages, isEmpty);

          final remainingFiles = await SecurityTestHelpers.getUserFiles(user.id);
          expect(remainingFiles, isEmpty);

          // Verify user profile is anonymized
          final userProfile = await SecurityTestHelpers.getUserProfile(user.id);
          expect(userProfile.name, equals('[Deleted User]'));
          expect(userProfile.phoneNumber, equals('[Deleted]'));
        });

        test('should implement consent management', () async {
          final user = await SecurityTestHelpers.createTestUser();

          // Check initial consent status
          final initialConsent = await websocketService.getUserConsent(user.id);
          expect(initialConsent.dataProcessing, isFalse);
          expect(initialConsent.marketing, isFalse);
          expect(initialConsent.analytics, isFalse);

          // Update consent
          final consentUpdate = await websocketService.updateUserConsent(
            user.id,
            {
              'dataProcessing': true,
              'marketing': false,
              'analytics': true,
            },
          );

          expect(consentUpdate.success, isTrue);

          // Verify consent is respected
          final updatedConsent = await websocketService.getUserConsent(user.id);
          expect(updatedConsent.dataProcessing, isTrue);
          expect(updatedConsent.marketing, isFalse);
          expect(updatedConsent.analytics, isTrue);

          // Verify marketing messages are not sent
          final marketingResult = await websocketService.sendMarketingMessage(
            user.id,
            'Marketing message',
          );
          expect(marketingResult.success, isFalse);
          expect(marketingResult.error, contains('consent'));
        });
      });

      group('7. Infrastructure Security Tests', () {
        test('should validate SSL/TLS configuration', () async {
          final sslConfig = await SecurityTestHelpers.getSSLConfiguration();

          expect(sslConfig.protocol, equals('TLSv1.3'));
          expect(sslConfig.cipherSuites, contains('TLS_AES_256_GCM_SHA384'));
          expect(sslConfig.certificateValidation, isTrue);
          expect(sslConfig.hsts, isTrue);
          expect(sslConfig.certificateTransparency, isTrue);
        });

        test('should implement proper CORS configuration', () async {
          final corsConfig = await SecurityTestHelpers.getCORSConfiguration();

          expect(corsConfig.allowedOrigins, isNot(contains('*')));
          expect(corsConfig.allowedMethods, containsAll(['GET', 'POST', 'PUT', 'DELETE']));
          expect(corsConfig.allowCredentials, isTrue);
          expect(corsConfig.maxAge, lessThanOrEqualTo(86400)); // 24 hours max
        });

        test('should validate security headers', () async {
          final headers = await SecurityTestHelpers.getSecurityHeaders();

          expect(headers['X-Content-Type-Options'], equals('nosniff'));
          expect(headers['X-Frame-Options'], equals('DENY'));
          expect(headers['X-XSS-Protection'], equals('1; mode=block'));
          expect(headers['Strict-Transport-Security'], contains('max-age='));
          expect(headers['Content-Security-Policy'], isNotEmpty);
          expect(headers['Referrer-Policy'], equals('strict-origin-when-cross-origin'));
        });

        test('should implement proper database security', () async {
          final dbConfig = await SecurityTestHelpers.getDatabaseConfiguration();

          expect(dbConfig.encryptionAtRest, isTrue);
          expect(dbConfig.encryptionInTransit, isTrue);
          expect(dbConfig.accessLogging, isTrue);
          expect(dbConfig.connectionPooling, isTrue);
          expect(dbConfig.queryParameterization, isTrue);
        });
      });
    });
  }
}

/// Security test result aggregation and reporting
class SecurityAuditReport {
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final List<SecurityVulnerability> vulnerabilities;
  final List<SecurityRecommendation> recommendations;
  final DateTime auditDate;

  SecurityAuditReport({
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.vulnerabilities,
    required this.recommendations,
    required this.auditDate,
  });

  double get successRate => passedTests / totalTests;
  
  String get riskLevel {
    if (vulnerabilities.any((v) => v.severity == 'critical')) return 'Critical';
    if (vulnerabilities.any((v) => v.severity == 'high')) return 'High';
    if (vulnerabilities.any((v) => v.severity == 'medium')) return 'Medium';
    return 'Low';
  }

  Map<String, dynamic> toJson() => {
    'totalTests': totalTests,
    'passedTests': passedTests,
    'failedTests': failedTests,
    'successRate': successRate,
    'riskLevel': riskLevel,
    'vulnerabilities': vulnerabilities.map((v) => v.toJson()).toList(),
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
    'auditDate': auditDate.toIso8601String(),
  };
}

class SecurityVulnerability {
  final String id;
  final String title;
  final String description;
  final String severity; // critical, high, medium, low
  final String category;
  final String affectedComponent;
  final String remediation;

  SecurityVulnerability({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.category,
    required this.affectedComponent,
    required this.remediation,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'severity': severity,
    'category': category,
    'affectedComponent': affectedComponent,
    'remediation': remediation,
  };
}

class SecurityRecommendation {
  final String id;
  final String title;
  final String description;
  final String priority; // high, medium, low
  final String category;
  final String implementation;

  SecurityRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
    required this.implementation,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'priority': priority,
    'category': category,
    'implementation': implementation,
  };
}