import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../test_utils/security_test_utils.dart';
import '../../lib/services/messaging/encryption_service.dart';
import '../../lib/services/messaging/anonymous_messaging_service.dart';
import '../../lib/services/auth_service.dart';
import '../../lib/services/messaging/file_sharing_service.dart';

void main() {
  group('Security Audit and Penetration Testing', () {
    late SecurityTestUtils securityUtils;
    late EncryptionService encryptionService;
    late AnonymousMessagingService anonymousService;
    late AuthService authService;
    late FileSharingService fileService;

    setUpAll(() async {
      securityUtils = SecurityTestUtils();
      await securityUtils.initialize();
      
      encryptionService = EncryptionService();
      anonymousService = AnonymousMessagingService();
      authService = AuthService();
      fileService = FileSharingService();
    });

    tearDownAll(() async {
      await securityUtils.cleanup();
    });

    group('Encryption Security Audit', () {
      test('AES-256 encryption implementation validation', () async {
        // Test AES-256-GCM encryption strength
        final testData = 'Sensitive land rights information';
        final key = securityUtils.generateSecureKey(256);
        
        final encrypted = await encryptionService.encryptWithAES256(testData, key);
        
        // Verify encryption properties
        expect(encrypted.algorithm, equals('AES-256-GCM'));
        expect(encrypted.iv.length, equals(12)); // GCM IV length
        expect(encrypted.data, isNot(contains(testData))); // No plaintext leakage
        
        // Test decryption
        final decrypted = await encryptionService.decryptWithAES256(encrypted, key);
        expect(decrypted, equals(testData));
        
        // Test with wrong key
        final wrongKey = securityUtils.generateSecureKey(256);
        expect(
          () => encryptionService.decryptWithAES256(encrypted, wrongKey),
          throwsA(isA<Exception>()),
        );
      });

      test('RSA-4096 key exchange security', () async {
        // Test RSA key pair generation
        final keyPair = await encryptionService.generateRSAKeyPair(4096);
        
        expect(keyPair.publicKey.length, greaterThan(500)); // RSA-4096 public key size
        expect(keyPair.privateKey.length, greaterThan(1500)); // RSA-4096 private key size
        
        // Test key exchange simulation
        final message = 'Secret AES key for secure communication';
        final encrypted = await encryptionService.encryptWithRSA(message, keyPair.publicKey);
        final decrypted = await encryptionService.decryptWithRSA(encrypted, keyPair.privateKey);
        
        expect(decrypted, equals(message));
        
        // Test that public key cannot decrypt
        expect(
          () => encryptionService.decryptWithRSA(encrypted, keyPair.publicKey),
          throwsA(isA<Exception>()),
        );
      });

      test('End-to-end encryption key rotation', () async {
        final userId1 = 'user1';
        final userId2 = 'user2';
        
        // Initial key exchange
        await encryptionService.initializeUserKeys(userId1);
        await encryptionService.initializeUserKeys(userId2);
        
        final message1 = 'Message before key rotation';
        final encrypted1 = await encryptionService.encryptMessage(message1, userId1, userId2);
        
        // Rotate keys
        await encryptionService.rotateUserKeys(userId1);
        await encryptionService.rotateUserKeys(userId2);
        
        // Test with new keys
        final message2 = 'Message after key rotation';
        final encrypted2 = await encryptionService.encryptMessage(message2, userId1, userId2);
        
        // Verify both messages can be decrypted with appropriate keys
        final decrypted1 = await encryptionService.decryptMessage(encrypted1, userId2);
        final decrypted2 = await encryptionService.decryptMessage(encrypted2, userId2);
        
        expect(decrypted1, equals(message1));
        expect(decrypted2, equals(message2));
        
        // Verify old keys cannot decrypt new messages
        expect(encrypted1.keyFingerprint, isNot(equals(encrypted2.keyFingerprint)));
      });

      test('Encryption performance under load', () async {
        const int messageCount = 1000;
        const int messageSize = 1024; // 1KB messages
        
        final messages = List.generate(messageCount, (i) => 
          securityUtils.generateRandomString(messageSize)
        );
        
        final stopwatch = Stopwatch()..start();
        
        final encryptedMessages = <EncryptedContent>[];
        for (final message in messages) {
          final encrypted = await encryptionService.encryptWithAES256(
            message, 
            securityUtils.generateSecureKey(256)
          );
          encryptedMessages.add(encrypted);
        }
        
        stopwatch.stop();
        
        final averageEncryptionTime = stopwatch.elapsedMilliseconds / messageCount;
        
        // Performance requirements
        expect(averageEncryptionTime, lessThan(10)); // < 10ms per message
        expect(encryptedMessages.length, equals(messageCount));
        
        // Verify all messages encrypted successfully
        for (final encrypted in encryptedMessages) {
          expect(encrypted.data, isNotEmpty);
          expect(encrypted.iv, isNotEmpty);
          expect(encrypted.algorithm, equals('AES-256-GCM'));
        }
      });
    });

    group('Authentication Security Audit', () {
      test('JWT token security validation', () async {
        final userId = 'test_user_123';
        final token = await authService.generateJWTToken(userId, {
          'role': 'member',
          'permissions': ['messaging', 'voice_calling'],
        });
        
        // Verify token structure
        final tokenParts = token.split('.');
        expect(tokenParts.length, equals(3)); // Header.Payload.Signature
        
        // Verify token validation
        final isValid = await authService.validateJWTToken(token);
        expect(isValid, isTrue);
        
        // Test token expiration
        final expiredToken = await authService.generateJWTToken(userId, {}, 
          expirationSeconds: -1); // Already expired
        final isExpiredValid = await authService.validateJWTToken(expiredToken);
        expect(isExpiredValid, isFalse);
        
        // Test token tampering
        final tamperedToken = token.substring(0, token.length - 5) + 'XXXXX';
        final isTamperedValid = await authService.validateJWTToken(tamperedToken);
        expect(isTamperedValid, isFalse);
      });

      test('Rate limiting security', () async {
        final userId = 'rate_limit_test_user';
        
        // Test message rate limiting (60 messages/minute)
        final messageTasks = <Future<bool>>[];
        for (int i = 0; i < 70; i++) {
          messageTasks.add(authService.checkRateLimit(userId, 'messaging'));
        }
        
        final results = await Future.wait(messageTasks);
        final allowedRequests = results.where((r) => r).length;
        final blockedRequests = results.where((r) => !r).length;
        
        expect(allowedRequests, lessThanOrEqualTo(60));
        expect(blockedRequests, greaterThanOrEqualTo(10));
        
        // Test burst limit (10 messages in 10 seconds)
        final burstTasks = <Future<bool>>[];
        for (int i = 0; i < 15; i++) {
          burstTasks.add(authService.checkBurstLimit(userId, 'messaging'));
        }
        
        final burstResults = await Future.wait(burstTasks);
        final allowedBurst = burstResults.where((r) => r).length;
        final blockedBurst = burstResults.where((r) => !r).length;
        
        expect(allowedBurst, lessThanOrEqualTo(10));
        expect(blockedBurst, greaterThanOrEqualTo(5));
      });

      test('Session management security', () async {
        final userId = 'session_test_user';
        
        // Create session
        final sessionId = await authService.createSession(userId);
        expect(sessionId, isNotEmpty);
        
        // Verify session exists
        final sessionValid = await authService.validateSession(sessionId);
        expect(sessionValid, isTrue);
        
        // Test session timeout
        await authService.setSessionTimeout(sessionId, Duration(milliseconds: 100));
        await Future.delayed(Duration(milliseconds: 200));
        
        final expiredSessionValid = await authService.validateSession(sessionId);
        expect(expiredSessionValid, isFalse);
        
        // Test concurrent session limit
        final sessions = <String>[];
        for (int i = 0; i < 10; i++) {
          final session = await authService.createSession(userId);
          sessions.add(session);
        }
        
        // Should only allow 5 concurrent sessions
        final validSessions = <String>[];
        for (final session in sessions) {
          if (await authService.validateSession(session)) {
            validSessions.add(session);
          }
        }
        
        expect(validSessions.length, lessThanOrEqualTo(5));
      });

      test('Biometric authentication security', () async {
        final userId = 'biometric_test_user';
        
        // Test biometric enrollment
        final biometricData = securityUtils.generateMockBiometricData();
        final enrolled = await authService.enrollBiometric(userId, biometricData);
        expect(enrolled, isTrue);
        
        // Test biometric authentication
        final authenticated = await authService.authenticateWithBiometric(userId, biometricData);
        expect(authenticated, isTrue);
        
        // Test with wrong biometric data
        final wrongBiometricData = securityUtils.generateMockBiometricData();
        final wrongAuthenticated = await authService.authenticateWithBiometric(userId, wrongBiometricData);
        expect(wrongAuthenticated, isFalse);
        
        // Test biometric data storage security
        final storedData = await authService.getBiometricData(userId);
        expect(storedData, isNot(equals(biometricData))); // Should be hashed/encrypted
      });
    });

    group('Input Validation Security Audit', () {
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
          final messageValid = await securityUtils.validateMessageContent(input);
          expect(messageValid, isFalse, reason: 'SQL injection not prevented: $input');
          
          // Test user search validation
          final searchValid = await securityUtils.validateSearchQuery(input);
          expect(searchValid, isFalse, reason: 'SQL injection in search not prevented: $input');
        }
      });

      test('XSS prevention', () async {
        final xssPayloads = [
          '<script>alert("XSS")</script>',
          'javascript:alert("XSS")',
          '<img src="x" onerror="alert(\'XSS\')">',
          '<svg onload="alert(\'XSS\')">',
          '"><script>alert("XSS")</script>',
          "';alert('XSS');//",
        ];
        
        for (final payload in xssPayloads) {
          // Test message content sanitization
          final sanitized = await securityUtils.sanitizeMessageContent(payload);
          expect(sanitized, isNot(contains('<script>')));
          expect(sanitized, isNot(contains('javascript:')));
          expect(sanitized, isNot(contains('onerror=')));
          expect(sanitized, isNot(contains('onload=')));
          
          // Test that sanitized content is safe
          final isSafe = await securityUtils.isContentSafe(sanitized);
          expect(isSafe, isTrue, reason: 'XSS not prevented: $payload');
        }
      });

      test('File upload security validation', () async {
        final maliciousFiles = [
          {'name': 'malware.exe', 'content': securityUtils.generateMalwareSignature()},
          {'name': 'script.js', 'content': '<script>alert("XSS")</script>'},
          {'name': 'huge_file.pdf', 'content': securityUtils.generateLargeFile(100 * 1024 * 1024)}, // 100MB
          {'name': '../../../etc/passwd', 'content': 'root:x:0:0:root:/root:/bin/bash'},
          {'name': 'file.php', 'content': '<?php system($_GET["cmd"]); ?>'},
        ];
        
        for (final file in maliciousFiles) {
          final uploadResult = await fileService.uploadFile(
            file['name'] as String,
            file['content'] as Uint8List,
          );
          
          // Should reject malicious files
          expect(uploadResult.success, isFalse, 
            reason: 'Malicious file not rejected: ${file['name']}');
          expect(uploadResult.error, isNotEmpty);
        }
        
        // Test legitimate files
        final legitimateFile = {
          'name': 'land_document.pdf',
          'content': securityUtils.generateLegitimateFile('pdf'),
        };
        
        final legitimateResult = await fileService.uploadFile(
          legitimateFile['name'] as String,
          legitimateFile['content'] as Uint8List,
        );
        
        expect(legitimateResult.success, isTrue);
        expect(legitimateResult.virusScanned, isTrue);
        expect(legitimateResult.encrypted, isTrue);
      });

      test('Path traversal prevention', () async {
        final pathTraversalAttempts = [
          '../../../etc/passwd',
          '..\\..\\..\\windows\\system32\\config\\sam',
          '/etc/shadow',
          'C:\\Windows\\System32\\config\\SAM',
          '....//....//....//etc/passwd',
          '%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd',
        ];
        
        for (final path in pathTraversalAttempts) {
          // Test file access attempts
          final accessResult = await fileService.getFile(path);
          expect(accessResult.success, isFalse, 
            reason: 'Path traversal not prevented: $path');
          
          // Test file upload with malicious path
          final uploadResult = await fileService.uploadFile(
            path,
            securityUtils.generateRandomBytes(1024),
          );
          expect(uploadResult.success, isFalse,
            reason: 'Path traversal in upload not prevented: $path');
        }
      });
    });

    group('Anonymous Messaging Security Audit', () {
      test('Identity protection validation', () async {
        final reporterId = 'anonymous_reporter_123';
        final coordinatorId = 'coordinator_456';
        
        // Send anonymous report
        final reportResult = await anonymousService.sendAnonymousReport(
          reporterId: reporterId,
          coordinatorId: coordinatorId,
          content: 'Land grabbing incident at location X',
          location: {'lat': 17.3850, 'lng': 78.4867},
        );
        
        expect(reportResult.success, isTrue);
        expect(reportResult.caseId, isNotEmpty);
        
        // Verify coordinator cannot see reporter identity
        final receivedReport = await anonymousService.getReportForCoordinator(
          coordinatorId, reportResult.caseId);
        
        expect(receivedReport.reporterId, isNot(equals(reporterId)));
        expect(receivedReport.reporterId, startsWith('anon_'));
        expect(receivedReport.location.lat, isNot(equals(17.3850))); // Location generalized
        expect(receivedReport.location.lng, isNot(equals(78.4867)));
        
        // Verify metadata minimization
        expect(receivedReport.metadata.keys.length, lessThan(5));
        expect(receivedReport.metadata, isNot(contains('deviceId')));
        expect(receivedReport.metadata, isNot(contains('ipAddress')));
      });

      test('Proxy routing security', () async {
        final reporterId = 'proxy_test_reporter';
        final coordinatorId = 'proxy_test_coordinator';
        
        // Send message through proxy
        final proxyResult = await anonymousService.sendThroughProxy(
          senderId: reporterId,
          recipientId: coordinatorId,
          content: 'Anonymous message content',
        );
        
        expect(proxyResult.success, isTrue);
        expect(proxyResult.proxyHops, greaterThan(1)); // Multiple proxy hops
        
        // Verify proxy servers don't log sender identity
        for (final proxyId in proxyResult.proxyPath) {
          final proxyLogs = await anonymousService.getProxyLogs(proxyId);
          
          // Logs should not contain original sender ID
          expect(proxyLogs.any((log) => log.contains(reporterId)), isFalse);
          
          // Logs should only contain encrypted data
          expect(proxyLogs.every((log) => log.contains('encrypted_payload')), isTrue);
        }
      });

      test('Anonymous response security', () async {
        final caseId = 'anonymous_case_123';
        final coordinatorId = 'response_coordinator';
        
        // Coordinator sends response to anonymous report
        final responseResult = await anonymousService.sendAnonymousResponse(
          coordinatorId: coordinatorId,
          caseId: caseId,
          response: 'We are investigating this matter',
        );
        
        expect(responseResult.success, isTrue);
        
        // Verify response maintains anonymity
        final receivedResponse = await anonymousService.getResponseForReporter(caseId);
        
        expect(receivedResponse.coordinatorId, isNot(equals(coordinatorId)));
        expect(receivedResponse.coordinatorId, startsWith('coord_'));
        expect(receivedResponse.content, equals('We are investigating this matter'));
        
        // Verify no correlation possible between request and response
        final correlationTest = await securityUtils.testAnonymityCorrelation(
          caseId, coordinatorId);
        expect(correlationTest.correlationPossible, isFalse);
      });
    });

    group('Network Security Audit', () {
      test('TLS/SSL configuration validation', () async {
        final tlsConfig = await securityUtils.getTLSConfiguration();
        
        // Verify TLS version
        expect(tlsConfig.version, greaterThanOrEqualTo('1.2'));
        
        // Verify cipher suites
        expect(tlsConfig.cipherSuites, contains('TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'));
        expect(tlsConfig.cipherSuites, isNot(contains('TLS_RSA_WITH_RC4_128_MD5'))); // Weak cipher
        
        // Verify certificate validation
        expect(tlsConfig.certificateValidation, isTrue);
        expect(tlsConfig.hostnameVerification, isTrue);
        
        // Test connection security
        final connectionTest = await securityUtils.testSecureConnection();
        expect(connectionTest.encrypted, isTrue);
        expect(connectionTest.certificateValid, isTrue);
        expect(connectionTest.protocolSecure, isTrue);
      });

      test('WebSocket security validation', () async {
        final wsConfig = await securityUtils.getWebSocketConfiguration();
        
        // Verify WSS (WebSocket Secure) is used
        expect(wsConfig.protocol, equals('wss'));
        
        // Verify authentication required
        expect(wsConfig.authenticationRequired, isTrue);
        
        // Test unauthorized connection attempt
        final unauthorizedResult = await securityUtils.testUnauthorizedWebSocketConnection();
        expect(unauthorizedResult.connectionAllowed, isFalse);
        expect(unauthorizedResult.errorCode, equals(401));
        
        // Test authorized connection
        final authorizedResult = await securityUtils.testAuthorizedWebSocketConnection();
        expect(authorizedResult.connectionAllowed, isTrue);
        expect(authorizedResult.encrypted, isTrue);
      });

      test('API endpoint security', () async {
        final endpoints = [
          '/api/messages',
          '/api/voice-calls',
          '/api/files',
          '/api/groups',
          '/api/users',
        ];
        
        for (final endpoint in endpoints) {
          // Test without authentication
          final unauthResult = await securityUtils.testEndpointWithoutAuth(endpoint);
          expect(unauthResult.statusCode, equals(401));
          
          // Test with invalid token
          final invalidTokenResult = await securityUtils.testEndpointWithInvalidToken(endpoint);
          expect(invalidTokenResult.statusCode, equals(401));
          
          // Test with valid token but wrong permissions
          final wrongPermResult = await securityUtils.testEndpointWithWrongPermissions(endpoint);
          expect(wrongPermResult.statusCode, equals(403));
          
          // Test rate limiting
          final rateLimitResult = await securityUtils.testEndpointRateLimit(endpoint);
          expect(rateLimitResult.rateLimitEnforced, isTrue);
        }
      });
    });

    group('Data Protection Security Audit', () {
      test('Data encryption at rest', () async {
        final testData = {
          'messages': 'Sensitive message content',
          'files': securityUtils.generateRandomBytes(1024),
          'user_data': {'name': 'Test User', 'phone': '+1234567890'},
        };
        
        for (final entry in testData.entries) {
          final dataType = entry.key;
          final data = entry.value;
          
          // Store data
          final storeResult = await securityUtils.storeData(dataType, data);
          expect(storeResult.success, isTrue);
          expect(storeResult.encrypted, isTrue);
          
          // Verify data is encrypted in storage
          final rawStoredData = await securityUtils.getRawStoredData(storeResult.id);
          expect(rawStoredData, isNot(contains(data.toString())));
          
          // Verify data can be decrypted and retrieved
          final retrievedData = await securityUtils.retrieveData(storeResult.id);
          expect(retrievedData, equals(data));
        }
      });

      test('Data access logging and auditing', () async {
        final userId = 'audit_test_user';
        final sensitiveOperations = [
          'view_user_profile',
          'access_messages',
          'download_file',
          'view_call_history',
        ];
        
        for (final operation in sensitiveOperations) {
          // Perform operation
          await securityUtils.performSensitiveOperation(userId, operation);
          
          // Verify audit log entry
          final auditLogs = await securityUtils.getAuditLogs(userId);
          final operationLog = auditLogs.firstWhere(
            (log) => log.operation == operation,
            orElse: () => throw Exception('Audit log not found for $operation'),
          );
          
          expect(operationLog.userId, equals(userId));
          expect(operationLog.timestamp, isNotNull);
          expect(operationLog.ipAddress, isNotNull);
          expect(operationLog.userAgent, isNotNull);
          expect(operationLog.success, isTrue);
        }
      });

      test('Data retention and deletion', () async {
        final testUserId = 'retention_test_user';
        
        // Create test data with different retention periods
        final shortRetentionData = await securityUtils.createDataWithRetention(
          testUserId, 'short_term', Duration(days: 1));
        final longRetentionData = await securityUtils.createDataWithRetention(
          testUserId, 'long_term', Duration(days: 365));
        
        // Fast-forward time simulation
        await securityUtils.simulateTimePassage(Duration(days: 2));
        
        // Run retention cleanup
        await securityUtils.runRetentionCleanup();
        
        // Verify short retention data is deleted
        final shortDataExists = await securityUtils.dataExists(shortRetentionData.id);
        expect(shortDataExists, isFalse);
        
        // Verify long retention data still exists
        final longDataExists = await securityUtils.dataExists(longRetentionData.id);
        expect(longDataExists, isTrue);
        
        // Test user data deletion request
        final deletionResult = await securityUtils.requestUserDataDeletion(testUserId);
        expect(deletionResult.success, isTrue);
        
        // Verify all user data is deleted
        final userDataExists = await securityUtils.userDataExists(testUserId);
        expect(userDataExists, isFalse);
      });
    });

    group('Vulnerability Assessment', () {
      test('Common vulnerability scanning', () async {
        final vulnerabilityResults = await securityUtils.runVulnerabilityScans([
          'sql_injection',
          'xss',
          'csrf',
          'path_traversal',
          'file_upload',
          'authentication_bypass',
          'privilege_escalation',
          'information_disclosure',
        ]);
        
        for (final result in vulnerabilityResults) {
          expect(result.vulnerabilityFound, isFalse, 
            reason: 'Vulnerability found: ${result.vulnerabilityType} - ${result.description}');
          expect(result.riskLevel, equals('low'));
        }
      });

      test('Dependency security scanning', () async {
        final dependencyResults = await securityUtils.scanDependencies();
        
        // Check for known vulnerable dependencies
        final highRiskDependencies = dependencyResults.dependencies
            .where((dep) => dep.riskLevel == 'high')
            .toList();
        
        expect(highRiskDependencies, isEmpty, 
          reason: 'High-risk dependencies found: ${highRiskDependencies.map((d) => d.name).join(', ')}');
        
        // Check for outdated dependencies
        final outdatedDependencies = dependencyResults.dependencies
            .where((dep) => dep.isOutdated)
            .toList();
        
        // Allow some outdated dependencies but flag critical ones
        final criticalOutdated = outdatedDependencies
            .where((dep) => dep.isCritical)
            .toList();
        
        expect(criticalOutdated, isEmpty,
          reason: 'Critical outdated dependencies: ${criticalOutdated.map((d) => d.name).join(', ')}');
      });

      test('Security configuration validation', () async {
        final configResults = await securityUtils.validateSecurityConfiguration();
        
        // Check security headers
        expect(configResults.securityHeaders['X-Content-Type-Options'], equals('nosniff'));
        expect(configResults.securityHeaders['X-Frame-Options'], equals('DENY'));
        expect(configResults.securityHeaders['X-XSS-Protection'], equals('1; mode=block'));
        expect(configResults.securityHeaders['Strict-Transport-Security'], isNotNull);
        
        // Check CORS configuration
        expect(configResults.corsConfiguration.allowCredentials, isFalse);
        expect(configResults.corsConfiguration.allowedOrigins, isNot(contains('*')));
        
        // Check CSP (Content Security Policy)
        expect(configResults.contentSecurityPolicy, isNotNull);
        expect(configResults.contentSecurityPolicy, contains("default-src 'self'"));
        
        // Check other security settings
        expect(configResults.httpsOnly, isTrue);
        expect(configResults.secureSessionCookies, isTrue);
        expect(configResults.passwordComplexityEnforced, isTrue);
      });
    });
  });
}