import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/messaging/data_backup_service.dart';
import 'package:talowa/services/messaging/disaster_recovery_service.dart';
import 'package:talowa/services/messaging/backup_scheduler_service.dart';
import 'package:talowa/services/messaging/message_retention_service.dart';
import 'package:talowa/services/messaging/data_migration_service.dart';
import 'package:talowa/services/auth_service.dart';

// Generate mocks
@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  QueryDocumentSnapshot,
  AuthService,
])
import 'backup_recovery_test.mocks.dart';

void main() {
  group('Data Backup and Recovery Tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockAuthService mockAuthService;
    late DataBackupService backupService;
    late DisasterRecoveryService recoveryService;
    late BackupSchedulerService schedulerService;
    late MessageRetentionService retentionService;
    late DataMigrationService migrationService;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockAuthService = MockAuthService();
      
      // Initialize services with mocked dependencies
      backupService = DataBackupService();
      recoveryService = DisasterRecoveryService();
      schedulerService = BackupSchedulerService();
      retentionService = MessageRetentionService();
      migrationService = DataMigrationService();
    });

    group('DataBackupService Tests', () {
      test('should create full backup successfully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('user_backups')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {
          return null;
        });

        // Mock conversations collection
        final mockConversationsCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockConversationsQuery = MockQuery<Map<String, dynamic>>();
        final mockConversationsSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('conversations')).thenReturn(mockConversationsCollection);
        when(mockConversationsCollection.where('participantIds', arrayContains: userId))
            .thenReturn(mockConversationsQuery);
        when(mockConversationsQuery.get()).thenAnswer((_) async => mockConversationsSnapshot);
        when(mockConversationsSnapshot.docs).thenReturn([]);

        // Act
        final backupId = await backupService.createFullBackup(
          includeMessages: true,
          includeCallHistory: true,
          includeConversations: true,
        );

        // Assert
        expect(backupId, isNotNull);
        expect(backupId, startsWith('backup_'));
        verify(mockAuthService.getCurrentUserId()).called(1);
      });

      test('should export user data successfully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        // Mock Firestore collections
        final mockConversationsCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockConversationsQuery = MockQuery<Map<String, dynamic>>();
        final mockConversationsSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('conversations')).thenReturn(mockConversationsCollection);
        when(mockConversationsCollection.where('participantIds', arrayContains: userId))
            .thenReturn(mockConversationsQuery);
        when(mockConversationsQuery.get()).thenAnswer((_) async => mockConversationsSnapshot);
        when(mockConversationsSnapshot.docs).thenReturn([]);

        // Act
        final exportData = await backupService.exportUserData(
          includeMessages: true,
          includeCallHistory: true,
          includeConversations: true,
        );

        // Assert
        expect(exportData, isNotNull);
        expect(exportData['exportId'], isNotNull);
        expect(exportData['userId'], equals(userId));
        expect(exportData['conversations'], isNotNull);
        expect(exportData['messages'], isNotNull);
        expect(exportData['callHistory'], isNotNull);
      });

      test('should get backup history successfully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockQuery = MockQuery<Map<String, dynamic>>();
        final mockSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('user_backups')).thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId)).thenReturn(mockQuery);
        when(mockQuery.orderBy('createdAt', descending: true)).thenReturn(mockQuery);
        when(mockQuery.limit(20)).thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.docs).thenReturn([]);

        // Act
        final backupHistory = await backupService.getBackupHistory();

        // Assert
        expect(backupHistory, isNotNull);
        expect(backupHistory, isList);
        verify(mockAuthService.getCurrentUserId()).called(1);
      });

      test('should get storage usage successfully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockQuery = MockQuery<Map<String, dynamic>>();
        final mockSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('user_backups')).thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId)).thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.docs).thenReturn([]);

        // Act
        final storageUsage = await backupService.getStorageUsage();

        // Assert
        expect(storageUsage, isNotNull);
        expect(storageUsage['totalSize'], isNotNull);
        expect(storageUsage['backupCount'], isNotNull);
        expect(storageUsage['averageSize'], isNotNull);
      });
    });

    group('DisasterRecoveryService Tests', () {
      test('should create recovery plan successfully', () async {
        // Arrange
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('recovery_plans')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        final planId = await recoveryService.createRecoveryPlan(
          planName: 'Test Recovery Plan',
          criticalDataTypes: ['messages', 'conversations'],
          recoveryConfig: {'backupRetentionDays': 30},
        );

        // Assert
        expect(planId, isNotNull);
        expect(planId, startsWith('recovery_plan_'));
      });

      test('should check system health successfully', () async {
        // Arrange
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('health_check')).thenReturn(mockCollection);
        when(mockCollection.doc('test')).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {
          return null;
        });
        when(mockDoc.get()).thenAnswer((_) async => MockDocumentSnapshot<Map<String, dynamic>>());
        when(mockDoc.delete()).thenAnswer((_) async {
          return null;
        });

        // Act
        final healthCheck = await recoveryService.checkSystemHealth();

        // Assert
        expect(healthCheck, isNotNull);
        expect(healthCheck['timestamp'], isNotNull);
        expect(healthCheck['overall'], isNotNull);
        expect(healthCheck['components'], isNotNull);
      });

      test('should test recovery procedures successfully', () async {
        // Arrange
        const recoveryPlanId = 'test_plan_123';
        
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('recovery_test_results')).thenReturn(mockCollection);
        when(mockCollection.add(any)).thenAnswer((_) async => mockDoc);

        // Act
        final testResults = await recoveryService.testRecoveryProcedures(recoveryPlanId);

        // Assert
        expect(testResults, isNotNull);
        expect(testResults['planId'], equals(recoveryPlanId));
        expect(testResults['overallResult'], isNotNull);
        expect(testResults['tests'], isNotNull);
      });
    });

    group('BackupSchedulerService Tests', () {
      test('should create backup schedule successfully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('backup_schedules')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        final scheduleId = await schedulerService.createBackupSchedule(
          scheduleName: 'Daily Backup',
          interval: const Duration(days: 1),
          dataTypes: ['messages', 'conversations'],
          backupConfig: {'includeMessages': true},
        );

        // Assert
        expect(scheduleId, isNotNull);
        expect(scheduleId, startsWith('schedule_'));
        verify(mockAuthService.getCurrentUserId()).called(1);
      });

      test('should get backup schedules successfully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockQuery = MockQuery<Map<String, dynamic>>();
        final mockSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('backup_schedules')).thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId)).thenReturn(mockQuery);
        when(mockQuery.orderBy('createdAt', descending: true)).thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.docs).thenReturn([]);

        // Act
        final schedules = await schedulerService.getBackupSchedules();

        // Assert
        expect(schedules, isNotNull);
        expect(schedules, isList);
        verify(mockAuthService.getCurrentUserId()).called(1);
      });

      test('should update backup schedule successfully', () async {
        // Arrange
        const scheduleId = 'schedule_123';
        
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('backup_schedules')).thenReturn(mockCollection);
        when(mockCollection.doc(scheduleId)).thenReturn(mockDoc);
        when(mockDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.exists).thenReturn(true);
        when(mockSnapshot.data()).thenReturn({
          'lastRun': Timestamp.now(),
          'interval': const Duration(days: 1).inMilliseconds,
        });
        when(mockDoc.update(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        await schedulerService.updateBackupSchedule(
          scheduleId: scheduleId,
          scheduleName: 'Updated Schedule',
          isActive: false,
        );

        // Assert
        verify(mockDoc.update(any)).called(1);
      });

      test('should delete backup schedule successfully', () async {
        // Arrange
        const scheduleId = 'schedule_123';
        
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('backup_schedules')).thenReturn(mockCollection);
        when(mockCollection.doc(scheduleId)).thenReturn(mockDoc);
        when(mockDoc.delete()).thenAnswer((_) async {
          return null;
        });

        // Act
        await schedulerService.deleteBackupSchedule(scheduleId);

        // Assert
        verify(mockDoc.delete()).called(1);
      });
    });

    group('MessageRetentionService Tests', () {
      test('should set retention policy successfully', () async {
        // Arrange
        const entityId = 'user_123';
        const entityType = 'user';
        final retentionPeriods = {'messages': 365, 'call_history': 180};
        
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('retention_policies')).thenReturn(mockCollection);
        when(mockCollection.doc(entityId)).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        await retentionService.setRetentionPolicy(
          entityId: entityId,
          entityType: entityType,
          retentionPeriods: retentionPeriods,
        );

        // Assert
        verify(mockDoc.set(any)).called(1);
      });

      test('should get retention policy successfully', () async {
        // Arrange
        const entityId = 'user_123';
        
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('retention_policies')).thenReturn(mockCollection);
        when(mockCollection.doc(entityId)).thenReturn(mockDoc);
        when(mockDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.exists).thenReturn(true);
        when(mockSnapshot.data()).thenReturn({
          'entityId': entityId,
          'entityType': 'user',
          'retentionPeriods': {'messages': 365},
          'autoCleanup': true,
        });

        // Act
        final policy = await retentionService.getRetentionPolicy(entityId);

        // Assert
        expect(policy, isNotNull);
        expect(policy!['entityId'], equals(entityId));
        expect(policy['retentionPeriods'], isNotNull);
      });

      test('should cleanup expired messages successfully', () async {
        // Arrange
        const userId = 'user_123';
        
        // Mock retention policy
        final mockPolicyCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockPolicyDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockPolicySnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('retention_policies')).thenReturn(mockPolicyCollection);
        when(mockPolicyCollection.doc(userId)).thenReturn(mockPolicyDoc);
        when(mockPolicyDoc.get()).thenAnswer((_) async => mockPolicySnapshot);
        when(mockPolicySnapshot.exists).thenReturn(true);
        when(mockPolicySnapshot.data()).thenReturn({
          'autoCleanup': true,
          'retentionPeriods': {'regular_messages': 365},
        });

        // Mock conversations
        final mockConversationsCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockConversationsQuery = MockQuery<Map<String, dynamic>>();
        final mockConversationsSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('conversations')).thenReturn(mockConversationsCollection);
        when(mockConversationsCollection.where('participantIds', arrayContains: userId))
            .thenReturn(mockConversationsQuery);
        when(mockConversationsQuery.get()).thenAnswer((_) async => mockConversationsSnapshot);
        when(mockConversationsSnapshot.docs).thenReturn([]);

        // Mock cleanup job creation
        final mockJobsCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockJobDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('cleanup_jobs')).thenReturn(mockJobsCollection);
        when(mockJobsCollection.doc(any)).thenReturn(mockJobDoc);
        when(mockJobDoc.set(any)).thenAnswer((_) async {
          return null;
        });
        when(mockJobDoc.update(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        await retentionService.cleanupExpiredMessages(userId);

        // Assert
        verify(mockPolicyDoc.get()).called(1);
      });
    });

    group('DataMigrationService Tests', () {
      test('should create migration configuration successfully', () async {
        // Arrange
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        
        when(mockFirestore.collection('migration_configs')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {
          return null;
        });

        // Act
        final configId = await migrationService.createMigrationConfig(
          configName: 'Test Migration',
          sourceType: 'firestore',
          targetType: 'sqlite',
          sourceConfig: {'collection': 'messages'},
          targetConfig: {'database': 'local.db'},
          dataTypes: ['messages'],
        );

        // Assert
        expect(configId, isNotNull);
        expect(configId, startsWith('migration_config_'));
      });

      test('should export data to JSON successfully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        // Mock conversations
        final mockConversationsCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockConversationsQuery = MockQuery<Map<String, dynamic>>();
        final mockConversationsSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('conversations')).thenReturn(mockConversationsCollection);
        when(mockConversationsCollection.where('participantIds', arrayContains: userId))
            .thenReturn(mockConversationsQuery);
        when(mockConversationsQuery.get()).thenAnswer((_) async => mockConversationsSnapshot);
        when(mockConversationsSnapshot.docs).thenReturn([]);

        // Act
        final filePath = await migrationService.exportToJSON(
          dataTypes: ['messages', 'conversations'],
        );

        // Assert
        expect(filePath, isNotNull);
        expect(filePath, contains('talowa_export_'));
        verify(mockAuthService.getCurrentUserId()).called(1);
      });

      test('should get migration history successfully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockQuery = MockQuery<Map<String, dynamic>>();
        final mockSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('data_migration_jobs')).thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId)).thenReturn(mockQuery);
        when(mockQuery.orderBy('createdAt', descending: true)).thenReturn(mockQuery);
        when(mockQuery.limit(20)).thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.docs).thenReturn([]);

        // Act
        final migrationHistory = await migrationService.getMigrationHistory();

        // Assert
        expect(migrationHistory, isNotNull);
        expect(migrationHistory, isList);
        verify(mockAuthService.getCurrentUserId()).called(1);
      });
    });

    group('Integration Tests', () {
      test('should perform complete backup and recovery workflow', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        // Mock all necessary Firestore operations
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDoc);
        when(mockCollection.where(any, isEqualTo: any)).thenReturn(MockQuery<Map<String, dynamic>>());
        when(mockCollection.where(any, arrayContains: any)).thenReturn(MockQuery<Map<String, dynamic>>());
        when(mockDoc.set(any)).thenAnswer((_) async {
          return null;
        });
        when(mockDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.exists).thenReturn(true);
        when(mockSnapshot.data()).thenReturn({
          'userId': userId,
          'backupData': {
            'messages': [],
            'conversations': [],
            'callHistory': [],
          },
        });

        // Act - Create backup
        final backupId = await backupService.createFullBackup(
          includeMessages: true,
          includeCallHistory: true,
          includeConversations: true,
        );

        // Act - Create recovery plan
        final recoveryPlanId = await recoveryService.createRecoveryPlan(
          planName: 'Test Recovery Plan',
          criticalDataTypes: ['messages', 'conversations'],
          recoveryConfig: {'backupId': backupId},
        );

        // Act - Test recovery procedures
        final testResults = await recoveryService.testRecoveryProcedures(recoveryPlanId);

        // Assert
        expect(backupId, isNotNull);
        expect(recoveryPlanId, isNotNull);
        expect(testResults, isNotNull);
        expect(testResults['overallResult'], isIn(['passed', 'warning', 'failed']));
      });

      test('should handle backup scheduling and execution', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {
          return null;
        });
        when(mockDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.exists).thenReturn(true);
        when(mockSnapshot.data()).thenReturn({
          'userId': userId,
          'scheduleName': 'Test Schedule',
          'interval': const Duration(days: 1).inMilliseconds,
          'dataTypes': ['messages'],
          'backupConfig': {'includeMessages': true},
          'isActive': true,
        });

        // Act - Create schedule
        final scheduleId = await schedulerService.createBackupSchedule(
          scheduleName: 'Test Schedule',
          interval: const Duration(days: 1),
          dataTypes: ['messages'],
          backupConfig: {'includeMessages': true},
        );

        // Act - Execute backup now
        final backupId = await schedulerService.executeBackupNow(scheduleId);

        // Assert
        expect(scheduleId, isNotNull);
        expect(backupId, isNotNull);
      });
    });

    group('Error Handling Tests', () {
      test('should handle authentication errors gracefully', () async {
        // Arrange
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => backupService.createFullBackup(),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle Firestore errors gracefully', () async {
        // Arrange
        const userId = 'test_user_123';
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => userId);
        
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        when(mockFirestore.collection('user_backups')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenThrow(Exception('Firestore error'));

        // Act & Assert
        expect(
          () => backupService.createFullBackup(),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle missing backup data gracefully', () async {
        // Arrange
        const backupId = 'non_existent_backup';
        
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(mockFirestore.collection('user_backups')).thenReturn(mockCollection);
        when(mockCollection.doc(backupId)).thenReturn(mockDoc);
        when(mockDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.exists).thenReturn(false);

        // Act & Assert
        expect(
          () => backupService.restoreFromBackup(backupId),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}

// Mock classes for testing
class MockQuery<T> extends Mock implements Query<T> {}
