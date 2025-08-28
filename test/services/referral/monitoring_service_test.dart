import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/referral/monitoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('MonitoringService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      MonitoringService.setFirestoreInstance(fakeFirestore);
    });

    group('Operation Monitoring', () {
      test('should start and end operation monitoring', () async {
        const operationId = 'test_op_1';
        const operation = 'referral_code_generation';
        const userId = 'user123';
        
        // Start monitoring
        MonitoringService.startOperation(operationId, operation, userId);
        
        // Simulate some work
        await Future.delayed(const Duration(milliseconds: 100));
        
        // End monitoring
        await MonitoringService.endOperation(
          operationId,
          operation,
          userId,
          success: true,
          metadata: {'codeLength': 9},
        );
        
        // Verify metrics were recorded
        final metrics = await fakeFirestore
            .collection('performance_metrics')
            .where('operation', isEqualTo: operation)
            .where('userId', isEqualTo: userId)
            .get();
        
        expect(metrics.docs.length, equals(1));
        
        final metricData = metrics.docs.first.data();
        expect(metricData['operation'], equals(operation));
        expect(metricData['userId'], equals(userId));
        expect(metricData['success'], isTrue);
        expect(metricData['durationMs'], greaterThan(0));
        expect(metricData['metadata']['codeLength'], equals(9));
      });

      test('should record failed operations', () async {
        const operationId = 'test_op_2';
        const operation = 'payment_processing';
        const userId = 'user456';
        const errorMessage = 'Payment gateway timeout';
        
        MonitoringService.startOperation(operationId, operation, userId);
        
        await MonitoringService.endOperation(
          operationId,
          operation,
          userId,
          success: false,
          errorMessage: errorMessage,
        );
        
        final metrics = await fakeFirestore
            .collection('performance_metrics')
            .where('operation', isEqualTo: operation)
            .get();
        
        expect(metrics.docs.length, equals(1));
        
        final metricData = metrics.docs.first.data();
        expect(metricData['success'], isFalse);
        expect(metricData['errorMessage'], equals(errorMessage));
      });

      test('should handle missing operation gracefully', () async {
        const operationId = 'missing_op';
        const operation = 'test_operation';
        const userId = 'user789';
        
        // End operation without starting it
        await MonitoringService.endOperation(
          operationId,
          operation,
          userId,
          success: true,
        );
        
        // Should not throw an error and should not record metrics
        final metrics = await fakeFirestore
            .collection('performance_metrics')
            .get();
        
        expect(metrics.docs.length, equals(0));
      });
    });

    group('Error Logging', () {
      test('should log error events', () async {
        const message = 'Database connection failed';
        const operation = 'user_registration';
        const userId = 'user123';
        const errorType = 'DatabaseError';
        const stackTrace = 'Stack trace here...';
        
        await MonitoringService.logError(
          message,
          operation: operation,
          userId: userId,
          errorType: errorType,
          stackTrace: stackTrace,
          context: {'database': 'firestore', 'retry': 3},
          level: MonitoringLevel.error,
        );
        
        final errors = await fakeFirestore
            .collection('error_events')
            .where('operation', isEqualTo: operation)
            .get();
        
        expect(errors.docs.length, equals(1));
        
        final errorData = errors.docs.first.data();
        expect(errorData['message'], equals(message));
        expect(errorData['operation'], equals(operation));
        expect(errorData['userId'], equals(userId));
        expect(errorData['errorType'], equals(errorType));
        expect(errorData['stackTrace'], equals(stackTrace));
        expect(errorData['level'], equals(MonitoringLevel.error.toString()));
        expect(errorData['isResolved'], isFalse);
        expect(errorData['context']['database'], equals('firestore'));
      });

      test('should log warning events', () async {
        const message = 'Slow database query detected';
        const operation = 'referral_lookup';
        const userId = 'user456';
        
        await MonitoringService.logWarning(
          message,
          operation: operation,
          userId: userId,
          context: {'queryTime': 5000},
        );
        
        final warnings = await fakeFirestore
            .collection('error_events')
            .where('level', isEqualTo: MonitoringLevel.warning.toString())
            .get();
        
        expect(warnings.docs.length, equals(1));
        
        final warningData = warnings.docs.first.data();
        expect(warningData['message'], equals(message));
        expect(warningData['level'], equals(MonitoringLevel.warning.toString()));
        expect(warningData['errorType'], equals('Warning'));
      });

      test('should log info events', () async {
        const message = 'User successfully registered';
        const operation = 'user_registration';
        const userId = 'user789';
        
        await MonitoringService.logInfo(
          message,
          operation: operation,
          userId: userId,
          context: {'registrationMethod': 'referral'},
        );
        
        final infos = await fakeFirestore
            .collection('error_events')
            .where('level', isEqualTo: MonitoringLevel.info.toString())
            .get();
        
        expect(infos.docs.length, equals(1));
        
        final infoData = infos.docs.first.data();
        expect(infoData['message'], equals(message));
        expect(infoData['level'], equals(MonitoringLevel.info.toString()));
        expect(infoData['errorType'], equals('Info'));
      });

      test('should send critical alerts', () async {
        const message = 'System database is down';
        const operation = 'database_connection';
        const userId = 'system';
        
        await MonitoringService.logError(
          message,
          operation: operation,
          userId: userId,
          level: MonitoringLevel.critical,
        );
        
        // Verify error was logged
        final errors = await fakeFirestore
            .collection('error_events')
            .where('level', isEqualTo: MonitoringLevel.critical.toString())
            .get();
        
        expect(errors.docs.length, equals(1));
        
        // Verify critical alert was created
        final alerts = await fakeFirestore
            .collection('critical_alerts')
            .get();
        
        expect(alerts.docs.length, equals(1));
        
        final alertData = alerts.docs.first.data();
        expect(alertData['message'], equals(message));
        expect(alertData['operation'], equals(operation));
        expect(alertData['acknowledged'], isFalse);
      });
    });

    group('Metrics Retrieval', () {
      test('should get performance metrics with filters', () async {
        // Create test metrics
        await fakeFirestore.collection('performance_metrics').add({
          'operation': 'referral_code_generation',
          'userId': 'user1',
          'timestamp': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'durationMs': 100,
          'success': true,
          'metadata': {},
          'sessionId': 'session1',
        });
        
        await fakeFirestore.collection('performance_metrics').add({
          'operation': 'payment_processing',
          'userId': 'user2',
          'timestamp': Timestamp.fromDate(DateTime(2024, 1, 16)),
          'durationMs': 500,
          'success': false,
          'errorMessage': 'Payment failed',
          'metadata': {},
          'sessionId': 'session2',
        });
        
        // Get all metrics
        final allMetrics = await MonitoringService.getPerformanceMetrics();
        expect(allMetrics.length, equals(2));
        
        // Get metrics by operation
        final codeGenMetrics = await MonitoringService.getPerformanceMetrics(
          operation: 'referral_code_generation',
        );
        expect(codeGenMetrics.length, equals(1));
        expect(codeGenMetrics.first.operation, equals('referral_code_generation'));
        
        // Get metrics by user
        final user1Metrics = await MonitoringService.getPerformanceMetrics(
          userId: 'user1',
        );
        expect(user1Metrics.length, equals(1));
        expect(user1Metrics.first.userId, equals('user1'));
        
        // Get metrics by date range
        final dateRangeMetrics = await MonitoringService.getPerformanceMetrics(
          startDate: DateTime(2024, 1, 15),
          endDate: DateTime(2024, 1, 15, 23, 59, 59),
        );
        expect(dateRangeMetrics.length, equals(1));
      });

      test('should get error events with filters', () async {
        // Create test error events
        await fakeFirestore.collection('error_events').add({
          'errorType': 'DatabaseError',
          'message': 'Connection timeout',
          'timestamp': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'level': MonitoringLevel.error.toString(),
          'operation': 'user_lookup',
          'userId': 'user1',
          'sessionId': 'session1',
          'context': {},
          'isResolved': false,
        });
        
        await fakeFirestore.collection('error_events').add({
          'errorType': 'ValidationError',
          'message': 'Invalid referral code',
          'timestamp': Timestamp.fromDate(DateTime(2024, 1, 16)),
          'level': MonitoringLevel.warning.toString(),
          'operation': 'referral_validation',
          'userId': 'user2',
          'sessionId': 'session2',
          'context': {},
          'isResolved': true,
          'resolvedAt': Timestamp.fromDate(DateTime(2024, 1, 17)),
        });
        
        // Get all errors
        final allErrors = await MonitoringService.getErrorEvents();
        expect(allErrors.length, equals(2));
        
        // Get errors by level
        final errorLevelEvents = await MonitoringService.getErrorEvents(
          level: MonitoringLevel.error,
        );
        expect(errorLevelEvents.length, equals(1));
        expect(errorLevelEvents.first.level, equals(MonitoringLevel.error));
        
        // Get unresolved errors
        final unresolvedErrors = await MonitoringService.getErrorEvents(
          isResolved: false,
        );
        expect(unresolvedErrors.length, equals(1));
        expect(unresolvedErrors.first.isResolved, isFalse);
        
        // Get resolved errors
        final resolvedErrors = await MonitoringService.getErrorEvents(
          isResolved: true,
        );
        expect(resolvedErrors.length, equals(1));
        expect(resolvedErrors.first.isResolved, isTrue);
        expect(resolvedErrors.first.resolvedAt, isNotNull);
      });
    });

    group('Health Report', () {
      test('should generate comprehensive health report', () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(hours: 12));
        
        // Create test data
        await fakeFirestore.collection('performance_metrics').add({
          'operation': 'referral_code_generation',
          'userId': 'user1',
          'timestamp': Timestamp.fromDate(yesterday),
          'durationMs': 150,
          'success': true,
          'metadata': {},
          'sessionId': 'session1',
        });
        
        await fakeFirestore.collection('performance_metrics').add({
          'operation': 'payment_processing',
          'userId': 'user2',
          'timestamp': Timestamp.fromDate(yesterday),
          'durationMs': 800,
          'success': false,
          'errorMessage': 'Payment failed',
          'metadata': {},
          'sessionId': 'session2',
        });
        
        await fakeFirestore.collection('error_events').add({
          'errorType': 'PaymentError',
          'message': 'Payment gateway timeout',
          'timestamp': Timestamp.fromDate(yesterday),
          'level': MonitoringLevel.error.toString(),
          'operation': 'payment_processing',
          'userId': 'user2',
          'sessionId': 'session2',
          'context': {},
          'isResolved': false,
        });
        
        final healthReport = await MonitoringService.generateHealthReport();
        
        expect(healthReport['timestamp'], isNotNull);
        expect(healthReport['period'], equals('24 hours'));
        
        final overall = healthReport['overall'];
        expect(overall['totalOperations'], equals(2));
        expect(overall['successfulOperations'], equals(1));
        expect(overall['successRate'], equals(50.0));
        expect(overall['avgResponseTime'], equals(475.0)); // (150 + 800) / 2
        expect(overall['totalErrors'], equals(1));
        
        final errorsByLevel = healthReport['errorsByLevel'];
        expect(errorsByLevel[MonitoringLevel.error.toString()], equals(1));
        
        final operationStats = healthReport['operationStats'];
        expect(operationStats.containsKey('referral_code_generation'), isTrue);
        expect(operationStats.containsKey('payment_processing'), isTrue);
        
        expect(healthReport['systemStatus'], equals('degraded')); // 50% success rate
        expect(healthReport['recommendations'], isA<List>());
        expect(healthReport['recommendations'].length, greaterThan(0));
      });

      test('should determine correct system status', () async {
        final now = DateTime.now();
        
        // Create metrics with high success rate
        for (int i = 0; i < 100; i++) {
          await fakeFirestore.collection('performance_metrics').add({
            'operation': 'test_operation',
            'userId': 'user$i',
            'timestamp': Timestamp.fromDate(now.subtract(Duration(minutes: i))),
            'durationMs': 100,
            'success': true,
            'metadata': {},
            'sessionId': 'session$i',
          });
        }
        
        final healthReport = await MonitoringService.generateHealthReport();
        expect(healthReport['systemStatus'], equals('healthy'));
        expect(healthReport['overall']['successRate'], equals(100.0));
      });
    });

    group('Error Resolution', () {
      test('should resolve error events', () async {
        // Create an error event
        final errorRef = await fakeFirestore.collection('error_events').add({
          'errorType': 'TestError',
          'message': 'Test error message',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'level': MonitoringLevel.error.toString(),
          'operation': 'test_operation',
          'userId': 'user1',
          'sessionId': 'session1',
          'context': {},
          'isResolved': false,
        });
        
        // Resolve the error
        await MonitoringService.resolveError(errorRef.id);
        
        // Verify error is marked as resolved
        final resolvedError = await fakeFirestore
            .collection('error_events')
            .doc(errorRef.id)
            .get();
        
        final errorData = resolvedError.data()!;
        expect(errorData['isResolved'], isTrue);
        expect(errorData['resolvedAt'], isNotNull);
      });
    });

    group('Data Models', () {
      test('should create PerformanceMetrics from map', () {
        final map = {
          'id': 'metrics1',
          'operation': 'test_operation',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'durationMs': 500,
          'success': true,
          'metadata': {'key': 'value'},
          'userId': 'user1',
          'sessionId': 'session1',
        };
        
        final metrics = PerformanceMetrics.fromMap(map);
        
        expect(metrics.id, equals('metrics1'));
        expect(metrics.operation, equals('test_operation'));
        expect(metrics.duration.inMilliseconds, equals(500));
        expect(metrics.success, isTrue);
        expect(metrics.metadata['key'], equals('value'));
        expect(metrics.userId, equals('user1'));
        expect(metrics.sessionId, equals('session1'));
      });

      test('should create ErrorEvent from map', () {
        final map = {
          'id': 'error1',
          'errorType': 'TestError',
          'message': 'Test error',
          'stackTrace': 'Stack trace...',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'level': MonitoringLevel.error.toString(),
          'operation': 'test_operation',
          'userId': 'user1',
          'sessionId': 'session1',
          'context': {'key': 'value'},
          'isResolved': false,
        };
        
        final error = ErrorEvent.fromMap(map);
        
        expect(error.id, equals('error1'));
        expect(error.errorType, equals('TestError'));
        expect(error.message, equals('Test error'));
        expect(error.stackTrace, equals('Stack trace...'));
        expect(error.level, equals(MonitoringLevel.error));
        expect(error.operation, equals('test_operation'));
        expect(error.userId, equals('user1'));
        expect(error.sessionId, equals('session1'));
        expect(error.context['key'], equals('value'));
        expect(error.isResolved, isFalse);
        expect(error.resolvedAt, isNull);
      });
    });

    group('Error Handling', () {
      test('should create MonitoringException correctly', () {
        const message = 'Test monitoring error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = MonitoringException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test monitoring error';
        const exception = MonitoringException(message);

        expect(exception.code, equals('MONITORING_FAILED'));
        expect(exception.context, isNull);
      });
    });
  });
}
