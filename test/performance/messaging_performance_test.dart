// Performance Tests for Message Delivery and Voice Call Quality
// Tests message delivery speed, voice call quality, and system responsiveness

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'dart:async';
import 'dart:math';

// Import services for performance testing
import 'package:talowa/services/messaging/messaging_service.dart';
import 'package:talowa/services/messaging/webrtc_service.dart';
import 'package:talowa/services/messaging/call_quality_monitor.dart';
import 'package:talowa/services/messaging/offline_messaging_service.dart';
import 'package:talowa/services/messaging/message_sync_service.dart';
import 'package:talowa/services/messaging/file_sharing_service.dart';
import 'package:talowa/services/messaging/emergency_broadcast_service.dart';

// Import models
import 'package:talowa/models/message_model.dart';
import 'package:talowa/models/user_model.dart';

class PerformanceMetrics {
  final String testName;
  final int operationCount;
  final Duration totalDuration;
  final List<Duration> operationTimes;
  final Map<String, dynamic> additionalMetrics;

  PerformanceMetrics({
    required this.testName,
    required this.operationCount,
    required this.totalDuration,
    required this.operationTimes,
    this.additionalMetrics = const {},
  });

  double get averageLatency => operationTimes.isEmpty ? 0 :
      operationTimes.map((d) => d.inMicroseconds).reduce((a, b) => a + b) / 
      operationTimes.length / 1000; // Convert to milliseconds

  double get throughput => operationCount / (totalDuration.inMilliseconds / 1000);

  Duration get minLatency => operationTimes.isEmpty ? Duration.zero :
      operationTimes.reduce((a, b) => a.inMicroseconds < b.inMicroseconds ? a : b);

  Duration get maxLatency => operationTimes.isEmpty ? Duration.zero :
      operationTimes.reduce((a, b) => a.inMicroseconds > b.inMicroseconds ? a : b);

  Duration get p50Latency => _getPercentile(0.5);
  Duration get p95Latency => _getPercentile(0.95);
  Duration get p99Latency => _getPercentile(0.99);

  Duration _getPercentile(double percentile) {
    if (operationTimes.isEmpty) return Duration.zero;
    final sorted = List<Duration>.from(operationTimes)..sort();
    final index = (sorted.length * percentile).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  @override
  String toString() {
    return '''
Performance Test: $testName
- Operations: $operationCount
- Total Duration: ${totalDuration.inMilliseconds}ms
- Throughput: ${throughput.toStringAsFixed(2)} ops/sec
- Average Latency: ${averageLatency.toStringAsFixed(2)}ms
- Min Latency: ${minLatency.inMilliseconds}ms
- Max Latency: ${maxLatency.inMilliseconds}ms
- P50 Latency: ${p50Latency.inMilliseconds}ms
- P95 Latency: ${p95Latency.inMilliseconds}ms
- P99 Latency: ${p99Latency.inMilliseconds}ms
''';
  }
}

class PerformanceTestRunner {
  Future<PerformanceMetrics> measurePerformance({
    required String testName,
    required Future<void> Function() operation,
    required int iterations,
    Duration? warmupDuration,
  }) async {
    final operationTimes = <Duration>[];

    // Warmup phase
    if (warmupDuration != null) {
      final warmupEnd = DateTime.now().add(warmupDuration);
      while (DateTime.now().isBefore(warmupEnd)) {
        await operation();
      }
    }

    // Actual measurement phase
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < iterations; i++) {
      final operationStopwatch = Stopwatch()..start();
      await operation();
      operationStopwatch.stop();
      operationTimes.add(operationStopwatch.elapsed);
    }

    stopwatch.stop();

    return PerformanceMetrics(
      testName: testName,
      operationCount: iterations,
      totalDuration: stopwatch.elapsed,
      operationTimes: operationTimes,
    );
  }

  Future<PerformanceMetrics> measureConcurrentPerformance({
    required String testName,
    required Future<void> Function() operation,
    required int concurrentOperations,
    Duration? timeout,
  }) async {
    final operationTimes = <Duration>[];
    final futures = <Future<Duration>>[];

    final stopwatch = Stopwatch()..start();

    // Start all operations concurrently
    for (int i = 0; i < concurrentOperations; i++) {
      futures.add(_measureSingleOperation(operation));
    }

    // Wait for all operations to complete
    final results = await Future.wait(futures).timeout(
      timeout ?? const Duration(minutes: 5),
    );

    stopwatch.stop();
    operationTimes.addAll(results);

    return PerformanceMetrics(
      testName: testName,
      operationCount: concurrentOperations,
      totalDuration: stopwatch.elapsed,
      operationTimes: operationTimes,
    );
  }

  Future<Duration> _measureSingleOperation(Future<void> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    return stopwatch.elapsed;
  }
}

void main() {
  group('Messaging Performance Tests', () {
    late MessagingService messagingService;
    late WebRTCService webrtcService;
    late CallQualityMonitor qualityMonitor;
    late OfflineMessagingService offlineService;
    late MessageSyncService syncService;
    late FileSharingService fileService;
    late EmergencyBroadcastService emergencyService;
    late PerformanceTestRunner testRunner;

    setUpAll(() async {
      messagingService = MessagingService();
      webrtcService = WebRTCService();
      qualityMonitor = CallQualityMonitor();
      offlineService = OfflineMessagingService();
      syncService = MessageSyncService();
      fileService = FileSharingService();
      emergencyService = EmergencyBroadcastService();
      testRunner = PerformanceTestRunner();

      await messagingService.initialize();
      await webrtcService.initialize();
      await offlineService.initialize();
    });

    group('Message Delivery Performance Tests', () {
      test('should deliver messages within 2 seconds', () async {
        final metrics = await testRunner.measurePerformance(
          testName: 'Message Delivery Speed',
          operation: () async {
            final message = MessageModel(
              id: 'perf_test_${DateTime.now().microsecondsSinceEpoch}',
              senderId: 'perf_sender',
              recipientId: 'perf_recipient',
              content: 'Performance test message',
              messageType: MessageType.text,
              timestamp: DateTime.now(),
              status: MessageStatus.pending,
            );

            final result = await messagingService.sendMessage(message);
            if (!result.success) {
              throw Exception('Message delivery failed');
            }

            // Wait for delivery confirmation
            await messagingService.waitForDeliveryConfirmation(result.messageId);
          },
          iterations: 100,
          warmupDuration: const Duration(seconds: 5),
        );

        print(metrics.toString());

        // Performance requirements
        expect(metrics.averageLatency, lessThan(2000)); // < 2 seconds average
        expect(metrics.p95Latency.inMilliseconds, lessThan(3000)); // P95 < 3 seconds
        expect(metrics.p99Latency.inMilliseconds, lessThan(5000)); // P99 < 5 seconds
        expect(metrics.throughput, greaterThan(10)); // > 10 messages/second
      });

      test('should handle concurrent message delivery efficiently', () async {
        final metrics = await testRunner.measureConcurrentPerformance(
          testName: 'Concurrent Message Delivery',
          operation: () async {
            final message = MessageModel(
              id: 'concurrent_perf_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}',
              senderId: 'concurrent_sender_${Random().nextInt(100)}',
              recipientId: 'concurrent_recipient_${Random().nextInt(100)}',
              content: 'Concurrent performance test message',
              messageType: MessageType.text,
              timestamp: DateTime.now(),
              status: MessageStatus.pending,
            );

            final result = await messagingService.sendMessage(message);
            if (!result.success) {
              throw Exception('Concurrent message delivery failed');
            }
          },
          concurrentOperations: 50,
          timeout: const Duration(minutes: 2),
        );

        print(metrics.toString());

        expect(metrics.averageLatency, lessThan(1000)); // < 1 second average for concurrent
        expect(metrics.p95Latency.inMilliseconds, lessThan(2000)); // P95 < 2 seconds
        expect(metrics.throughput, greaterThan(20)); // > 20 messages/second concurrent
      });

      test('should maintain performance with large messages', () async {
        final largeSizes = [1024, 5120, 10240, 51200]; // 1KB, 5KB, 10KB, 50KB

        for (final size in largeSizes) {
          final largeContent = 'A' * size;
          
          final metrics = await testRunner.measurePerformance(
            testName: 'Large Message Delivery ($size bytes)',
            operation: () async {
              final message = MessageModel(
                id: 'large_perf_${DateTime.now().microsecondsSinceEpoch}',
                senderId: 'large_sender',
                recipientId: 'large_recipient',
                content: largeContent,
                messageType: MessageType.text,
                timestamp: DateTime.now(),
                status: MessageStatus.pending,
              );

              final result = await messagingService.sendMessage(message);
              if (!result.success) {
                throw Exception('Large message delivery failed');
              }
            },
            iterations: 20,
          );

          print(metrics.toString());

          // Performance should degrade gracefully with size
          final expectedLatency = 1000 + (size / 1024) * 100; // Base + size factor
          expect(metrics.averageLatency, lessThan(expectedLatency));
        }
      });

      test('should handle group message delivery performance', () async {
        // Create test group with many members
        final groupData = CreateGroupRequest(
          name: 'Performance Test Group',
          description: 'Group for performance testing',
          type: GroupType.campaign,
          maxMembers: 200,
        );

        final group = await groupService.createGroup(groupData);
        final memberIds = List.generate(100, (index) => 'perf_member_$index');
        await groupService.addMembers(group.id, memberIds);

        final metrics = await testRunner.measurePerformance(
          testName: 'Group Message Delivery (100 members)',
          operation: () async {
            final groupMessage = MessageModel(
              id: 'group_perf_${DateTime.now().microsecondsSinceEpoch}',
              senderId: 'group_perf_sender',
              groupId: group.id,
              content: 'Group performance test message',
              messageType: MessageType.text,
              timestamp: DateTime.now(),
              status: MessageStatus.pending,
            );

            final result = await messagingService.sendGroupMessage(groupMessage);
            if (!result.success) {
              throw Exception('Group message delivery failed');
            }
          },
          iterations: 20,
        );

        print(metrics.toString());

        // Group messages should still be reasonably fast
        expect(metrics.averageLatency, lessThan(5000)); // < 5 seconds for 100 members
        expect(metrics.p95Latency.inMilliseconds, lessThan(8000)); // P95 < 8 seconds
      });
    });

    group('Voice Call Quality Performance Tests', () {
      test('should establish calls within 10 seconds', () async {
        final metrics = await testRunner.measurePerformance(
          testName: 'Voice Call Establishment',
          operation: () async {
            final callSession = await webrtcService.initiateCall(
              recipientId: 'call_perf_recipient_${Random().nextInt(1000)}',
              callType: CallType.voice,
            );

            if (callSession.id.isEmpty) {
              throw Exception('Call initiation failed');
            }

            // Simulate call acceptance and connection
            await webrtcService.acceptCall(callSession.id);
            
            // Wait for connection to be established
            await webrtcService.waitForCallConnection(callSession.id);
            
            // Clean up
            await webrtcService.endCall(callSession.id);
          },
          iterations: 20,
          warmupDuration: const Duration(seconds: 3),
        );

        print(metrics.toString());

        expect(metrics.averageLatency, lessThan(10000)); // < 10 seconds average
        expect(metrics.p95Latency.inMilliseconds, lessThan(15000)); // P95 < 15 seconds
        expect(metrics.maxLatency.inMilliseconds, lessThan(20000)); // Max < 20 seconds
      });

      test('should maintain call quality under various conditions', () async {
        final qualityConditions = [
          {'name': 'Excellent', 'latency': 50, 'packetLoss': 0.001, 'jitter': 5},
          {'name': 'Good', 'latency': 100, 'packetLoss': 0.01, 'jitter': 15},
          {'name': 'Fair', 'latency': 200, 'packetLoss': 0.03, 'jitter': 30},
          {'name': 'Poor', 'latency': 400, 'packetLoss': 0.05, 'jitter': 50},
        ];

        for (final condition in qualityConditions) {
          final callSession = await webrtcService.initiateCall(
            recipientId: 'quality_test_recipient',
            callType: CallType.voice,
          );

          await qualityMonitor.startMonitoring(callSession.id);

          // Simulate network conditions
          await qualityMonitor.simulateNetworkConditions(
            callSession.id,
            latency: condition['latency'] as int,
            packetLoss: condition['packetLoss'] as double,
            jitter: condition['jitter'] as int,
          );

          final qualityMeasurements = <CallQuality>[];
          qualityMonitor.onQualityUpdate = (quality) {
            qualityMeasurements.add(quality);
          };

          // Monitor for 5 seconds
          await Future.delayed(const Duration(seconds: 5));

          qualityMonitor.stopMonitoring(callSession.id);
          await webrtcService.endCall(callSession.id);

          // Analyze quality metrics
          final avgLatency = qualityMeasurements
              .map((q) => q.latency)
              .reduce((a, b) => a + b) / qualityMeasurements.length;
          
          final avgPacketLoss = qualityMeasurements
              .map((q) => q.packetLoss)
              .reduce((a, b) => a + b) / qualityMeasurements.length;

          print('Quality Test - ${condition['name']}:');
          print('  Average Latency: ${avgLatency.toStringAsFixed(2)}ms');
          print('  Average Packet Loss: ${(avgPacketLoss * 100).toStringAsFixed(3)}%');
          print('  Quality Measurements: ${qualityMeasurements.length}');

          // Quality should be within expected ranges
          expect(avgLatency, lessThan((condition['latency'] as int) * 1.5));
          expect(avgPacketLoss, lessThan((condition['packetLoss'] as double) * 2));
        }
      });

      test('should handle concurrent voice calls efficiently', () async {
        const concurrentCalls = 10;
        final callSessions = <CallSession>[];

        final metrics = await testRunner.measureConcurrentPerformance(
          testName: 'Concurrent Voice Calls',
          operation: () async {
            final callSession = await webrtcService.initiateCall(
              recipientId: 'concurrent_call_recipient_${Random().nextInt(1000)}',
              callType: CallType.voice,
            );

            if (callSession.id.isEmpty) {
              throw Exception('Concurrent call initiation failed');
            }

            callSessions.add(callSession);
            
            // Simulate brief call
            await Future.delayed(const Duration(milliseconds: 500));
            await webrtcService.endCall(callSession.id);
          },
          concurrentOperations: concurrentCalls,
          timeout: const Duration(minutes: 2),
        );

        print(metrics.toString());

        expect(metrics.averageLatency, lessThan(5000)); // < 5 seconds for concurrent calls
        expect(metrics.p95Latency.inMilliseconds, lessThan(8000)); // P95 < 8 seconds
      });

      test('should adapt call quality based on network conditions', () async {
        final callSession = await webrtcService.initiateCall(
          recipientId: 'adaptive_quality_recipient',
          callType: CallType.voice,
        );

        await qualityMonitor.startMonitoring(callSession.id);

        final qualityChanges = <CallQuality>[];
        qualityMonitor.onQualityUpdate = (quality) {
          qualityChanges.add(quality);
        };

        // Simulate degrading network conditions
        await qualityMonitor.simulateNetworkConditions(
          callSession.id,
          latency: 50,
          packetLoss: 0.001,
          jitter: 5,
        );
        await Future.delayed(const Duration(seconds: 2));

        await qualityMonitor.simulateNetworkConditions(
          callSession.id,
          latency: 200,
          packetLoss: 0.03,
          jitter: 30,
        );
        await Future.delayed(const Duration(seconds: 2));

        await qualityMonitor.simulateNetworkConditions(
          callSession.id,
          latency: 500,
          packetLoss: 0.08,
          jitter: 80,
        );
        await Future.delayed(const Duration(seconds: 2));

        qualityMonitor.stopMonitoring(callSession.id);
        await webrtcService.endCall(callSession.id);

        // Verify quality adaptation
        expect(qualityChanges.length, greaterThan(5));
        
        final initialQuality = qualityChanges.first.audioQuality;
        final finalQuality = qualityChanges.last.audioQuality;
        
        // Quality should have degraded as network conditions worsened
        expect(finalQuality.index, lessThan(initialQuality.index));

        print('Quality Adaptation Test:');
        print('  Initial Quality: $initialQuality');
        print('  Final Quality: $finalQuality');
        print('  Quality Changes: ${qualityChanges.length}');
      });
    });

    group('File Transfer Performance Tests', () {
      test('should handle file upload performance', () async {
        final fileSizes = [
          {'name': '100KB', 'size': 100 * 1024},
          {'name': '1MB', 'size': 1024 * 1024},
          {'name': '5MB', 'size': 5 * 1024 * 1024},
          {'name': '10MB', 'size': 10 * 1024 * 1024},
        ];

        for (final fileSize in fileSizes) {
          final fileData = FileUploadData(
            fileName: 'perf_test_${fileSize['name']}.jpg',
            mimeType: 'image/jpeg',
            fileBytes: List<int>.filled(fileSize['size'] as int, Random().nextInt(256)),
            metadata: FileMetadata(
              uploadedBy: 'perf_test_user',
              tags: ['performance_test'],
              accessLevel: AccessLevel.private,
            ),
          );

          final metrics = await testRunner.measurePerformance(
            testName: 'File Upload Performance (${fileSize['name']})',
            operation: () async {
              final result = await fileService.uploadFile(fileData);
              if (!result.success) {
                throw Exception('File upload failed');
              }
            },
            iterations: 5,
          );

          print(metrics.toString());

          // Performance expectations based on file size
          final expectedLatency = (fileSize['size'] as int) / 1024 / 1024 * 2000; // 2s per MB
          expect(metrics.averageLatency, lessThan(expectedLatency));
        }
      });

      test('should handle concurrent file downloads', () async {
        // First, upload test files
        final uploadedFiles = <String>[];
        
        for (int i = 0; i < 5; i++) {
          final fileData = FileUploadData(
            fileName: 'download_perf_test_$i.pdf',
            mimeType: 'application/pdf',
            fileBytes: List<int>.filled(1024 * 1024, 65), // 1MB files
            metadata: FileMetadata(
              uploadedBy: 'download_perf_user',
              tags: ['download_performance_test'],
              accessLevel: AccessLevel.private,
            ),
          );

          final result = await fileService.uploadFile(fileData);
          uploadedFiles.add(result.fileId);
        }

        final metrics = await testRunner.measureConcurrentPerformance(
          testName: 'Concurrent File Downloads',
          operation: () async {
            final fileId = uploadedFiles[Random().nextInt(uploadedFiles.length)];
            final fileData = await fileService.downloadFile(fileId);
            
            if (fileData.isEmpty) {
              throw Exception('File download failed');
            }
          },
          concurrentOperations: 20,
          timeout: const Duration(minutes: 3),
        );

        print(metrics.toString());

        expect(metrics.averageLatency, lessThan(3000)); // < 3 seconds for 1MB files
        expect(metrics.p95Latency.inMilliseconds, lessThan(5000)); // P95 < 5 seconds
        expect(metrics.throughput, greaterThan(5)); // > 5 downloads/second
      });
    });

    group('Offline Synchronization Performance Tests', () {
      test('should sync messages efficiently when coming back online', () async {
        // Simulate going offline
        await offlineService.setOfflineMode(true);

        // Queue messages while offline
        final offlineMessages = <MessageModel>[];
        for (int i = 0; i < 50; i++) {
          final message = MessageModel(
            id: 'offline_sync_$i',
            senderId: 'offline_sender',
            recipientId: 'offline_recipient_$i',
            content: 'Offline message $i',
            messageType: MessageType.text,
            timestamp: DateTime.now(),
            status: MessageStatus.pending,
          );
          
          offlineMessages.add(message);
          await messagingService.sendMessage(message); // Will be queued
        }

        // Come back online and measure sync performance
        await offlineService.setOfflineMode(false);

        final metrics = await testRunner.measurePerformance(
          testName: 'Offline Message Synchronization',
          operation: () async {
            final syncResult = await syncService.syncPendingMessages();
            if (!syncResult.success) {
              throw Exception('Sync failed');
            }
          },
          iterations: 1,
        );

        print(metrics.toString());

        expect(metrics.averageLatency, lessThan(10000)); // < 10 seconds for 50 messages
        
        // Verify all messages were synced
        final queuedMessages = await offlineService.getQueuedMessages();
        expect(queuedMessages.length, equals(0));
      });

      test('should handle conflict resolution performance', () async {
        // Create conflicting scenarios
        final conflictingMessages = <MessageModel>[];
        
        for (int i = 0; i < 20; i++) {
          final message = MessageModel(
            id: 'conflict_msg_$i',
            senderId: 'conflict_sender',
            recipientId: 'conflict_recipient',
            content: 'Original content $i',
            messageType: MessageType.text,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          );
          
          conflictingMessages.add(message);
          await messagingService.sendMessage(message);
        }

        // Simulate offline edits
        await offlineService.setOfflineMode(true);
        
        for (final message in conflictingMessages) {
          final editedMessage = message.copyWith(
            content: 'Edited offline content',
            editedAt: DateTime.now(),
          );
          await messagingService.editMessage(editedMessage);
        }

        await offlineService.setOfflineMode(false);

        final metrics = await testRunner.measurePerformance(
          testName: 'Conflict Resolution Performance',
          operation: () async {
            final syncResult = await syncService.syncWithConflictResolution();
            if (!syncResult.success) {
              throw Exception('Conflict resolution failed');
            }
          },
          iterations: 1,
        );

        print(metrics.toString());

        expect(metrics.averageLatency, lessThan(15000)); // < 15 seconds for 20 conflicts
      });
    });

    group('Emergency Broadcast Performance Tests', () {
      test('should deliver emergency broadcasts within 30 seconds', () async {
        final metrics = await testRunner.measurePerformance(
          testName: 'Emergency Broadcast Delivery',
          operation: () async {
            final broadcast = EmergencyBroadcast(
              title: 'Performance Test Emergency',
              message: 'This is a performance test emergency broadcast',
              scope: BroadcastScope(
                level: LocationLevel.district,
                locationIds: ['perf_test_district'],
              ),
              channels: [NotificationChannel.push, NotificationChannel.sms],
              priority: BroadcastPriority.critical,
            );

            final result = await emergencyService.sendEmergencyBroadcast(broadcast);
            if (!result.success) {
              throw Exception('Emergency broadcast failed');
            }

            // Wait for delivery completion
            await emergencyService.waitForBroadcastCompletion(result.broadcastId);
          },
          iterations: 10,
        );

        print(metrics.toString());

        expect(metrics.averageLatency, lessThan(30000)); // < 30 seconds
        expect(metrics.p95Latency.inMilliseconds, lessThan(45000)); // P95 < 45 seconds
        expect(metrics.maxLatency.inMilliseconds, lessThan(60000)); // Max < 60 seconds
      });
    });

    tearDownAll(() async {
      await messagingService.dispose();
      webrtcService.dispose();
      offlineService.dispose();
    });
  });
}