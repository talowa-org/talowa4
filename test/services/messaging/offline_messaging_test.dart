// Test for Offline Messaging Service
// Tests Task 8: Create offline messaging and synchronization

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:talowa/services/messaging/offline_messaging_service.dart';
import 'package:talowa/services/messaging/message_queue_service.dart';
import 'package:talowa/services/messaging/message_sync_service.dart';
import 'package:talowa/services/messaging/message_conflict_resolver.dart';
import 'package:talowa/services/messaging/message_compression_service.dart';
import 'package:talowa/services/messaging/unified_offline_messaging_service.dart';
import 'package:talowa/models/message_model.dart';

void main() {
  group('Offline Messaging Service Tests', () {
    late OfflineMessagingService offlineService;
    late MessageQueueService queueService;
    late MessageSyncService syncService;
    late MessageConflictResolver conflictResolver;
    late MessageCompressionService compressionService;
    late UnifiedOfflineMessagingService unifiedService;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      offlineService = OfflineMessagingService();
      queueService = MessageQueueService();
      syncService = MessageSyncService();
      conflictResolver = MessageConflictResolver();
      compressionService = MessageCompressionService();
      unifiedService = UnifiedOfflineMessagingService();
    });

    group('Message Compression Service', () {
      test('should compress large text content', () async {
        const largeText = 'This is a large text content that should be compressed. ' * 50;
        
        final compressed = await compressionService.compressText(largeText);
        
        expect(compressed, isNot(equals(largeText)));
        expect(compressed.length, lessThan(largeText.length));
      });

      test('should not compress small text content', () async {
        const smallText = 'Small text';
        
        final compressed = await compressionService.compressText(smallText);
        
        expect(compressed, equals(smallText));
      });

      test('should decompress compressed text correctly', () async {
        const originalText = 'This is a test message that will be compressed and then decompressed. ' * 20;
        
        final compressed = await compressionService.compressText(originalText);
        final decompressed = await compressionService.decompressText(compressed);
        
        expect(decompressed, equals(originalText));
      });

      test('should get optimal compression settings based on network quality', () async {
        final settings = await compressionService.getOptimalCompressionSettings();
        
        expect(settings, isNotNull);
        expect(settings.imageQuality, greaterThan(0));
        expect(settings.imageQuality, lessThanOrEqualTo(1.0));
      });
    });

    group('Message Queue Service', () {
      test('should create queue statistics', () async {
        final stats = await queueService.getQueueStatistics();
        
        expect(stats, isNotNull);
        expect(stats.totalMessages, isA<int>());
        expect(stats.pendingMessages, isA<int>());
        expect(stats.failedMessages, isA<int>());
      });

      test('should handle message priority correctly', () {
        const highPriority = MessagePriority.high;
        const normalPriority = MessagePriority.normal;
        const lowPriority = MessagePriority.low;
        
        expect(highPriority.index, greaterThan(normalPriority.index));
        expect(normalPriority.index, greaterThan(lowPriority.index));
      });
    });

    group('Message Conflict Resolver', () {
      test('should create conflict statistics', () async {
        final stats = await conflictResolver.getConflictStatistics();
        
        expect(stats, isNotNull);
        expect(stats.totalConflicts, isA<int>());
        expect(stats.resolvedConflicts, isA<int>());
        expect(stats.pendingConflicts, isA<int>());
      });

      test('should calculate resolution rate correctly', () {
        final stats = ConflictStatistics(
          totalConflicts: 10,
          resolvedConflicts: 8,
          pendingConflicts: 2,
        );
        
        expect(stats.resolutionRate, equals(80.0));
        expect(stats.hasConflicts, isTrue);
        expect(stats.hasPendingConflicts, isTrue);
      });
    });

    group('Unified Offline Messaging Service', () {
      test('should create unified status', () async {
        final status = await unifiedService.getStatus();
        
        expect(status, isNotNull);
        expect(status.isOnline, isA<bool>());
        expect(status.isInitialized, isA<bool>());
        expect(status.hasPendingMessages, isA<bool>());
        expect(status.hasFailedMessages, isA<bool>());
        expect(status.isSyncing, isA<bool>());
        expect(status.hasConflicts, isA<bool>());
      });

      test('should create offline messaging stats', () async {
        final stats = await unifiedService.getStats();
        
        expect(stats, isNotNull);
        expect(stats.totalMessages, isA<int>());
        expect(stats.totalPendingOperations, isA<int>());
        expect(stats.totalStorageMB, isA<double>());
        expect(stats.compressionSavingsMB, isA<double>());
      });
    });

    group('Data Models', () {
      test('should create QueuedMessage correctly', () {
        final queuedMessage = QueuedMessage(
          id: 'test_id',
          conversationId: 'conv_id',
          content: 'Test message',
          messageType: MessageType.text,
          mediaUrls: [],
          metadata: {},
          priority: 1,
          createdAt: DateTime.now(),
          attempts: 0,
          maxAttempts: 3,
          status: QueuedMessageStatus.pending,
          compressionApplied: false,
          originalSize: 12,
          compressedSize: 12,
        );
        
        expect(queuedMessage.id, equals('test_id'));
        expect(queuedMessage.conversationId, equals('conv_id'));
        expect(queuedMessage.content, equals('Test message'));
        expect(queuedMessage.messageType, equals(MessageType.text));
        expect(queuedMessage.status, equals(QueuedMessageStatus.pending));
      });

      test('should create SyncResult correctly', () {
        final syncResult = SyncResult(
          success: true,
          message: 'Sync completed',
          syncType: SyncType.incremental,
          downloadedMessages: 5,
          updatedConversations: 2,
          duration: const Duration(seconds: 10),
          errors: [],
        );
        
        expect(syncResult.success, isTrue);
        expect(syncResult.message, equals('Sync completed'));
        expect(syncResult.syncType, equals(SyncType.incremental));
        expect(syncResult.downloadedMessages, equals(5));
        expect(syncResult.updatedConversations, equals(2));
        expect(syncResult.errors, isEmpty);
      });

      test('should create CompressionResult correctly', () {
        final compressionResult = CompressionResult(
          success: true,
          originalPath: '/path/to/original.jpg',
          compressedPath: '/path/to/compressed.jpg',
          originalSize: 1000,
          compressedSize: 600,
          compressionRatio: 40.0,
        );
        
        expect(compressionResult.success, isTrue);
        expect(compressionResult.bytesSaved, equals(400));
        expect(compressionResult.wasCompressed, isTrue);
        expect(compressionResult.compressionRatio, equals(40.0));
      });
    });

    group('Enums and Constants', () {
      test('should have correct OfflineSyncStatus values', () {
        expect(OfflineSyncStatus.values, contains(OfflineSyncStatus.idle));
        expect(OfflineSyncStatus.values, contains(OfflineSyncStatus.syncing));
        expect(OfflineSyncStatus.values, contains(OfflineSyncStatus.downloading));
        expect(OfflineSyncStatus.values, contains(OfflineSyncStatus.completed));
        expect(OfflineSyncStatus.values, contains(OfflineSyncStatus.failed));
      });

      test('should have correct NetworkQuality values', () {
        expect(NetworkQuality.values, contains(NetworkQuality.excellent));
        expect(NetworkQuality.values, contains(NetworkQuality.good));
        expect(NetworkQuality.values, contains(NetworkQuality.poor));
        expect(NetworkQuality.values, contains(NetworkQuality.veryPoor));
        expect(NetworkQuality.values, contains(NetworkQuality.unknown));
      });

      test('should have correct ConflictType values', () {
        expect(ConflictType.values, contains(ConflictType.none));
        expect(ConflictType.values, contains(ConflictType.contentModified));
        expect(ConflictType.values, contains(ConflictType.mediaModified));
        expect(ConflictType.values, contains(ConflictType.timestampMismatch));
        expect(ConflictType.values, contains(ConflictType.duplicateMessage));
      });
    });
  });
}