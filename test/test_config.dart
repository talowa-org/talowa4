// Test Configuration for Messaging System Tests
// Provides configuration and utilities for all messaging tests

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestConfig {
  // Test timeouts
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration longTimeout = Duration(minutes: 5);
  static const Duration loadTestTimeout = Duration(minutes: 10);

  // Performance thresholds
  static const int maxMessageDeliveryTimeMs = 2000;
  static const int maxCallSetupTimeMs = 10000;
  static const int maxFileUploadTimeMs = 5000;
  static const double minPassRate = 0.90;

  // Load test parameters
  static const int defaultConcurrentUsers = 50;
  static const int defaultMessagesPerUser = 10;
  static const int maxConcurrentCalls = 20;

  // Security test parameters
  static const int maxRateLimitAttempts = 60;
  static const int bruteForceAttempts = 10;
  static const List<String> maliciousPayloads = [
    '<script>alert("xss")</script>',
    '\'; DROP TABLE messages; --',
    '../../../etc/passwd',
    'javascript:alert(1)',
  ];

  // Test data
  static const String testUserId = 'test_user_123';
  static const String testRecipientId = 'test_recipient_456';
  static const String testGroupId = 'test_group_789';
  static const String testMessage = 'This is a test message for TALOWA messaging system';
  
  static Map<String, dynamic> get testUserData => {
    'id': testUserId,
    'name': 'Test User',
    'email': 'test@talowa.org',
    'phone': '+919876543210',
    'role': 'member',
    'location': {
      'village': 'Test Village',
      'mandal': 'Test Mandal',
      'district': 'Test District',
    },
  };

  static Map<String, dynamic> get testGroupData => {
    'id': testGroupId,
    'name': 'Test Group',
    'description': 'Group for testing purposes',
    'type': 'village',
    'memberCount': 5,
    'maxMembers': 100,
  };
}

class TestSetupHelper {
  static late FakeFirebaseFirestore fakeFirestore;
  static late MockFirebaseAuth mockAuth;
  static late MockUser mockUser;

  static Future<void> setupTestEnvironment() async {
    // Initialize fake Firebase services
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    // Setup mock user
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn(TestConfig.testUserId);
    when(mockUser.email).thenReturn('test@talowa.org');
    when(mockUser.phoneNumber).thenReturn('+919876543210');

    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Setup test data in Firestore
    await _setupTestData();
  }

  static Future<void> _setupTestData() async {
    // Add test user to Firestore
    await fakeFirestore
        .collection('users')
        .doc(TestConfig.testUserId)
        .set(TestConfig.testUserData);

    // Add test recipient
    await fakeFirestore
        .collection('users')
        .doc(TestConfig.testRecipientId)
        .set({
      'id': TestConfig.testRecipientId,
      'name': 'Test Recipient',
      'email': 'recipient@talowa.org',
      'phone': '+919876543211',
      'role': 'member',
    });

    // Add test group
    await fakeFirestore
        .collection('groups')
        .doc(TestConfig.testGroupId)
        .set(TestConfig.testGroupData);

    // Add test conversations
    await fakeFirestore
        .collection('conversations')
        .doc('test_conversation_1')
        .set({
      'id': 'test_conversation_1',
      'type': 'direct',
      'participantIds': [TestConfig.testUserId, TestConfig.testRecipientId],
      'lastMessage': {
        'content': 'Hello',
        'timestamp': DateTime.now().toIso8601String(),
        'senderId': TestConfig.testUserId,
      },
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> cleanupTestEnvironment() async {
    // Clear all test data
    await fakeFirestore.clearPersistence();
    
    // Reset SharedPreferences
    SharedPreferences.setMockInitialValues({});
  }

  static Future<void> seedTestMessages(int count) async {
    for (int i = 0; i < count; i++) {
      await fakeFirestore
          .collection('messages')
          .doc('test_message_$i')
          .set({
        'id': 'test_message_$i',
        'senderId': i % 2 == 0 ? TestConfig.testUserId : TestConfig.testRecipientId,
        'recipientId': i % 2 == 0 ? TestConfig.testRecipientId : TestConfig.testUserId,
        'content': 'Test message $i',
        'messageType': 'text',
        'timestamp': DateTime.now().subtract(Duration(minutes: count - i)).toIso8601String(),
        'status': 'delivered',
        'conversationId': 'test_conversation_1',
      });
    }
  }

  static Future<void> seedTestGroups(int count) async {
    for (int i = 0; i < count; i++) {
      await fakeFirestore
          .collection('groups')
          .doc('test_group_$i')
          .set({
        'id': 'test_group_$i',
        'name': 'Test Group $i',
        'description': 'Test group for testing purposes',
        'type': 'village',
        'memberCount': 5 + i,
        'maxMembers': 100,
        'createdAt': DateTime.now().subtract(Duration(days: i)).toIso8601String(),
        'createdBy': TestConfig.testUserId,
      });
    }
  }
}

class TestDataGenerator {
  static final Random _random = Random();

  static String generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))));
  }

  static List<int> generateRandomBytes(int length) {
    return List.generate(length, (_) => _random.nextInt(256));
  }

  static Map<String, dynamic> generateTestMessage({
    String? id,
    String? senderId,
    String? recipientId,
    String? content,
    String? messageType,
  }) {
    return {
      'id': id ?? 'msg_${DateTime.now().microsecondsSinceEpoch}',
      'senderId': senderId ?? TestConfig.testUserId,
      'recipientId': recipientId ?? TestConfig.testRecipientId,
      'content': content ?? 'Test message ${generateRandomString(10)}',
      'messageType': messageType ?? 'text',
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    };
  }

  static Map<String, dynamic> generateTestUser({
    String? id,
    String? name,
    String? email,
    String? role,
  }) {
    final userId = id ?? 'user_${generateRandomString(8)}';
    return {
      'id': userId,
      'name': name ?? 'Test User ${generateRandomString(5)}',
      'email': email ?? '${generateRandomString(8)}@talowa.org',
      'phone': '+91${_random.nextInt(9000000000) + 1000000000}',
      'role': role ?? 'member',
      'location': {
        'village': 'Village ${generateRandomString(5)}',
        'mandal': 'Mandal ${generateRandomString(5)}',
        'district': 'District ${generateRandomString(5)}',
      },
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> generateTestGroup({
    String? id,
    String? name,
    String? type,
    int? memberCount,
  }) {
    return {
      'id': id ?? 'group_${generateRandomString(8)}',
      'name': name ?? 'Test Group ${generateRandomString(5)}',
      'description': 'Generated test group for testing purposes',
      'type': type ?? 'village',
      'memberCount': memberCount ?? _random.nextInt(50) + 5,
      'maxMembers': 100,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': TestConfig.testUserId,
    };
  }

  static List<Map<String, dynamic>> generateTestMessages(int count) {
    return List.generate(count, (index) => generateTestMessage(
      id: 'bulk_msg_$index',
      content: 'Bulk test message $index',
    ));
  }

  static List<Map<String, dynamic>> generateTestUsers(int count) {
    return List.generate(count, (index) => generateTestUser(
      id: 'bulk_user_$index',
      name: 'Bulk Test User $index',
    ));
  }
}

class TestAssertions {
  static void assertMessageDeliveryTime(Duration actualTime) {
    expect(actualTime.inMilliseconds, lessThan(TestConfig.maxMessageDeliveryTimeMs),
        reason: 'Message delivery should be under ${TestConfig.maxMessageDeliveryTimeMs}ms');
  }

  static void assertCallSetupTime(Duration actualTime) {
    expect(actualTime.inMilliseconds, lessThan(TestConfig.maxCallSetupTimeMs),
        reason: 'Call setup should be under ${TestConfig.maxCallSetupTimeMs}ms');
  }

  static void assertFileUploadTime(Duration actualTime) {
    expect(actualTime.inMilliseconds, lessThan(TestConfig.maxFileUploadTimeMs),
        reason: 'File upload should be under ${TestConfig.maxFileUploadTimeMs}ms');
  }

  static void assertPassRate(double actualRate) {
    expect(actualRate, greaterThan(TestConfig.minPassRate),
        reason: 'Pass rate should be above ${TestConfig.minPassRate * 100}%');
  }

  static void assertSecurityValidation(bool isValid, String context) {
    expect(isValid, isFalse,
        reason: 'Security validation should reject malicious content in $context');
  }

  static void assertEncryptionIntegrity(String original, String decrypted) {
    expect(decrypted, equals(original),
        reason: 'Decrypted content should match original');
  }

  static void assertRateLimitEnforcement(bool isBlocked, String action) {
    expect(isBlocked, isTrue,
        reason: 'Rate limiting should block excessive $action requests');
  }
}

class TestMetricsCollector {
  final Map<String, List<Duration>> _metrics = {};
  final Map<String, int> _counters = {};

  void recordLatency(String operation, Duration latency) {
    _metrics.putIfAbsent(operation, () => []).add(latency);
  }

  void incrementCounter(String counter) {
    _counters[counter] = (_counters[counter] ?? 0) + 1;
  }

  Duration getAverageLatency(String operation) {
    final latencies = _metrics[operation];
    if (latencies == null || latencies.isEmpty) return Duration.zero;
    
    final totalMicroseconds = latencies
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a + b);
    
    return Duration(microseconds: totalMicroseconds ~/ latencies.length);
  }

  Duration getP95Latency(String operation) {
    final latencies = _metrics[operation];
    if (latencies == null || latencies.isEmpty) return Duration.zero;
    
    final sorted = List<Duration>.from(latencies)..sort();
    final index = (sorted.length * 0.95).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  int getCounter(String counter) => _counters[counter] ?? 0;

  Map<String, dynamic> getMetricsSummary() {
    final summary = <String, dynamic>{};
    
    for (final operation in _metrics.keys) {
      summary[operation] = {
        'count': _metrics[operation]!.length,
        'average_ms': getAverageLatency(operation).inMilliseconds,
        'p95_ms': getP95Latency(operation).inMilliseconds,
      };
    }
    
    summary['counters'] = Map.from(_counters);
    
    return summary;
  }

  void reset() {
    _metrics.clear();
    _counters.clear();
  }
}

// Global test utilities
final TestMetricsCollector testMetrics = TestMetricsCollector();

void setUpTestEnvironment() {
  setUpAll(() async {
    await TestSetupHelper.setupTestEnvironment();
  });

  tearDownAll(() async {
    await TestSetupHelper.cleanupTestEnvironment();
  });
}

void setUpTestMetrics() {
  setUp(() {
    testMetrics.reset();
  });

  tearDown(() {
    final summary = testMetrics.getMetricsSummary();
    if (summary.isNotEmpty) {
      print('Test Metrics: $summary');
    }
  });
}
