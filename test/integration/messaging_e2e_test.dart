// End-to-End Integration Tests for Messaging System
// Tests complete message flow and call setup scenarios

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:integration_test/integration_test.dart';

// Import services for integration testing
import 'package:talowa/services/messaging/messaging_service.dart';
import 'package:talowa/services/messaging/encryption_service.dart';
import 'package:talowa/services/messaging/webrtc_service.dart';
import 'package:talowa/services/messaging/group_service.dart';
import 'package:talowa/services/messaging/file_sharing_service.dart';
import 'package:talowa/services/messaging/anonymous_messaging_service.dart';
import 'package:talowa/services/messaging/emergency_broadcast_service.dart';
import 'package:talowa/services/messaging/offline_messaging_service.dart';
import 'package:talowa/services/messaging/message_sync_service.dart';

// Import models
import 'package:talowa/models/message_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Messaging Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MessagingService messagingService;
    late EncryptionService encryptionService;
    late WebRTCService webrtcService;
    late GroupService groupService;

    setUpAll(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      
      // Initialize services
      messagingService = MessagingService();
      encryptionService = EncryptionService();
      webrtcService = WebRTCService();
      groupService = GroupService();
      
      await messagingService.initialize();
      await encryptionService.initializeUserEncryption();
      await webrtcService.initialize();
    });

    group('Complete Message Flow Tests', () {
      test('should complete full encrypted message flow', () async {
        // Step 1: Initialize users
        const senderId = 'user_sender_123';
        const recipientId = 'user_recipient_456';
        
        // Step 2: Generate encryption keys for both users
        await encryptionService.generateKeyPair(senderId);
        await encryptionService.generateKeyPair(recipientId);
        
        // Step 3: Create and send encrypted message
        final originalMessage = MessageModel(
          id: 'e2e_msg_001',
          senderId: senderId,
          recipientId: recipientId,
          content: 'This is an end-to-end encrypted message about land rights coordination',
          messageType: MessageType.text,
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
          encryptionLevel: EncryptionLevel.standard,
        );

        // Step 4: Send message through messaging service
        final sendResult = await messagingService.sendMessage(originalMessage);
        expect(sendResult.success, isTrue);
        expect(sendResult.messageId, isNotEmpty);

        // Step 5: Simulate message delivery
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Step 6: Verify message was encrypted and stored
        final storedMessage = await messagingService.getMessage(sendResult.messageId);
        expect(storedMessage, isNotNull);
        expect(storedMessage!.status, equals(MessageStatus.delivered));
        
        // Step 7: Simulate recipient receiving and decrypting message
        final decryptedContent = await encryptionService.decryptMessage(
          EncryptedContent(
            data: storedMessage.encryptedContent!,
            iv: storedMessage.encryptionIV!,
            algorithm: 'AES-256-GCM',
            keyFingerprint: storedMessage.keyFingerprint!,
          ),
        );
        
        expect(decryptedContent, equals(originalMessage.content));
        
        // Step 8: Update message status to read
        await messagingService.updateMessageStatus(sendResult.messageId, MessageStatus.read);
        
        final finalMessage = await messagingService.getMessage(sendResult.messageId);
        expect(finalMessage!.status, equals(MessageStatus.read));
      });

      test('should handle group message flow with multiple recipients', () async {
        // Step 1: Create group
        final groupData = CreateGroupRequest(
          name: 'E2E Test Group',
          description: 'Group for end-to-end testing',
          type: GroupType.campaign,
          maxMembers: 10,
        );

        final group = await groupService.createGroup(groupData);
        expect(group.id, isNotEmpty);

        // Step 2: Add members to group
        final memberIds = ['user_1', 'user_2', 'user_3', 'user_4'];
        await groupService.addMembers(group.id, memberIds);

        // Step 3: Generate encryption keys for all members
        for (final memberId in memberIds) {
          await encryptionService.generateKeyPair(memberId);
        }

        // Step 4: Send group message
        final groupMessage = MessageModel(
          id: 'e2e_group_msg_001',
          senderId: 'user_1',
          groupId: group.id,
          content: 'Important coordination message for all group members',
          messageType: MessageType.text,
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
          encryptionLevel: EncryptionLevel.standard,
        );

        final sendResult = await messagingService.sendGroupMessage(groupMessage);
        expect(sendResult.success, isTrue);

        // Step 5: Verify all members received the message
        for (final memberId in memberIds) {
          final memberMessages = await messagingService.getMessagesForUser(memberId);
          expect(memberMessages.any((msg) => msg.id == sendResult.messageId), isTrue);
        }

        // Step 6: Simulate read receipts from members
        for (final memberId in memberIds.skip(1)) { // Skip sender
          await messagingService.markMessageAsRead(sendResult.messageId, memberId);
        }

        final finalMessage = await messagingService.getMessage(sendResult.messageId);
        expect(finalMessage!.readBy.length, equals(memberIds.length - 1));
      });

      test('should handle file sharing with encryption', () async {
        // Step 1: Prepare file data
        final fileData = FileUploadData(
          fileName: 'land_document_e2e.pdf',
          mimeType: 'application/pdf',
          fileBytes: List<int>.filled(2048, 65), // Mock PDF content
          metadata: FileMetadata(
            uploadedBy: 'user_file_sender',
            tags: ['land_record', 'legal_document', 'e2e_test'],
            accessLevel: AccessLevel.private,
          ),
        );

        // Step 2: Upload and encrypt file
        final fileService = FileSharingService();
        final uploadResult = await fileService.uploadFile(fileData);
        expect(uploadResult.success, isTrue);

        // Step 3: Create message with file attachment
        final fileMessage = MessageModel(
          id: 'e2e_file_msg_001',
          senderId: 'user_file_sender',
          recipientId: 'user_file_recipient',
          content: 'Please review this land document',
          messageType: MessageType.document,
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
          mediaUrls: [uploadResult.downloadUrl],
          mediaMetadata: {
            'fileId': uploadResult.fileId,
            'fileName': fileData.fileName,
            'fileSize': fileData.fileBytes.length,
            'mimeType': fileData.mimeType,
          },
        );

        // Step 4: Send message with file
        final sendResult = await messagingService.sendMessage(fileMessage);
        expect(sendResult.success, isTrue);

        // Step 5: Recipient downloads file
        final downloadedFile = await fileService.downloadFile(uploadResult.fileId);
        expect(downloadedFile, isNotNull);
        expect(downloadedFile.length, equals(fileData.fileBytes.length));
      });

      test('should handle anonymous reporting flow', () async {
        // Step 1: Send anonymous report
        final anonymousService = AnonymousMessagingService();
        
        const reportContent = 'Anonymous report about land grabbing incident in village XYZ';
        const coordinatorId = 'coordinator_e2e_test';
        
        final caseId = await anonymousService.sendAnonymousReport(
          content: reportContent,
          coordinatorId: coordinatorId,
          reportType: ReportType.landGrabbing,
          location: {
            'villageCode': 'VIL_E2E_001',
            'villageName': 'E2E Test Village',
            'mandalCode': 'MAN_E2E_001',
            'mandalName': 'E2E Test Mandal',
          },
        );

        expect(caseId, isNotEmpty);
        expect(caseId, startsWith('ANON-'));

        // Step 2: Coordinator receives anonymous report
        final coordinatorMessages = await messagingService.getMessagesForUser(coordinatorId);
        final anonymousReport = coordinatorMessages.firstWhere(
          (msg) => msg.isAnonymous && msg.anonymousCaseId == caseId,
        );
        
        expect(anonymousReport, isNotNull);
        expect(anonymousReport.senderId, equals('anonymous'));

        // Step 3: Coordinator responds to anonymous report
        const response = 'Thank you for your report. We are investigating this matter.';
        await anonymousService.respondToAnonymousReport(
          caseId: caseId,
          response: response,
        );

        // Step 4: Verify anonymous response was sent
        final caseStatus = await anonymousService.getAnonymousCaseStatus(caseId);
        expect(caseStatus.hasResponse, isTrue);
        expect(caseStatus.responseCount, equals(1));
      });

      test('should handle emergency broadcast flow', () async {
        // Step 1: Create emergency broadcast
        final emergencyService = EmergencyBroadcastService();
        
        final broadcast = EmergencyBroadcast(
          title: 'E2E Test Emergency Alert',
          message: 'This is a test emergency broadcast for end-to-end testing',
          scope: BroadcastScope(
            level: LocationLevel.village,
            locationIds: ['village_e2e_001', 'village_e2e_002'],
          ),
          channels: [NotificationChannel.push, NotificationChannel.sms],
          priority: BroadcastPriority.high,
        );

        // Step 2: Send emergency broadcast
        final broadcastResult = await emergencyService.sendEmergencyBroadcast(broadcast);
        expect(broadcastResult.success, isTrue);
        expect(broadcastResult.broadcastId, isNotEmpty);

        // Step 3: Wait for delivery processing
        await Future.delayed(const Duration(milliseconds: 500));

        // Step 4: Check delivery status
        final deliveryStatus = await emergencyService.getBroadcastDeliveryStatus(
          broadcastResult.broadcastId,
        );
        
        expect(deliveryStatus.broadcastId, equals(broadcastResult.broadcastId));
        expect(deliveryStatus.totalRecipients, greaterThan(0));
        expect(deliveryStatus.deliveredCount, greaterThanOrEqualTo(0));

        // Step 5: Retry any failed deliveries
        if (deliveryStatus.failedCount > 0) {
          await emergencyService.retryFailedDeliveries(broadcastResult.broadcastId);
          
          // Check status again after retry
          final retryStatus = await emergencyService.getBroadcastDeliveryStatus(
            broadcastResult.broadcastId,
          );
          expect(retryStatus.retryAttempts, greaterThan(0));
        }
      });
    });

    group('Voice Call Integration Tests', () {
      test('should complete full voice call setup and teardown', () async {
        // Step 1: Initialize call participants
        const callerId = 'caller_e2e_test';
        const recipientId = 'recipient_e2e_test';

        // Step 2: Initiate call
        final callSession = await webrtcService.initiateCall(
          recipientId: recipientId,
          callType: CallType.voice,
        );

        expect(callSession.id, isNotEmpty);
        expect(callSession.callType, equals(CallType.voice));
        expect(callSession.status, equals(CallStatus.connecting));

        // Step 3: Simulate call ringing
        await webrtcService.updateCallStatus(callSession.id, CallStatus.ringing);
        
        // Step 4: Recipient accepts call
        final acceptedSession = await webrtcService.acceptCall(callSession.id);
        expect(acceptedSession.status, equals(CallStatus.connected));

        // Step 5: Simulate call duration
        await Future.delayed(const Duration(milliseconds: 200));

        // Step 6: Test call controls
        await webrtcService.muteAudio(callSession.id);
        await webrtcService.unmuteAudio(callSession.id);
        await webrtcService.toggleSpeaker(callSession.id);

        // Step 7: End call
        await webrtcService.endCall(callSession.id);

        // Step 8: Verify call was recorded in history
        final callHistory = await webrtcService.getCallHistory(callerId);
        expect(callHistory.any((call) => call.id == callSession.id), isTrue);
      });

      test('should handle call quality monitoring', () async {
        // Step 1: Start a call
        final callSession = await webrtcService.initiateCall(
          recipientId: 'quality_test_recipient',
          callType: CallType.voice,
        );

        // Step 2: Start quality monitoring
        final qualityMonitor = CallQualityMonitor();
        await qualityMonitor.startMonitoring(callSession.id);

        // Step 3: Simulate quality updates
        final qualityUpdates = <CallQuality>[];
        qualityMonitor.onQualityUpdate = (quality) {
          qualityUpdates.add(quality);
        };

        // Step 4: Simulate various quality conditions
        await qualityMonitor.simulateQualityChange(
          callSession.id,
          CallQuality(
            callId: callSession.id,
            latency: 150,
            packetLoss: 0.02,
            jitter: 20,
            audioQuality: AudioQuality.good,
          ),
        );

        expect(qualityUpdates.length, greaterThan(0));
        expect(qualityUpdates.last.audioQuality, equals(AudioQuality.good));

        // Step 5: Test quality recommendations
        final recommendations = await qualityMonitor.getQualityRecommendations(callSession.id);
        expect(recommendations, isA<List<QualityRecommendation>>());

        // Step 6: Stop monitoring and end call
        await qualityMonitor.stopMonitoring(callSession.id);
        await webrtcService.endCall(callSession.id);
      });

      test('should handle group voice calls', () async {
        // Step 1: Create group for voice call
        final groupData = CreateGroupRequest(
          name: 'Voice Call Test Group',
          description: 'Group for testing voice calls',
          type: GroupType.campaign,
          maxMembers: 5,
        );

        final group = await groupService.createGroup(groupData);
        final memberIds = ['caller_1', 'caller_2', 'caller_3'];
        await groupService.addMembers(group.id, memberIds);

        // Step 2: Initiate group call
        final groupCallSession = await webrtcService.initiateGroupCall(
          groupId: group.id,
          callType: CallType.voice,
        );

        expect(groupCallSession.id, isNotEmpty);
        expect(groupCallSession.participants.length, equals(memberIds.length));

        // Step 3: Members join call
        for (final memberId in memberIds.skip(1)) {
          await webrtcService.joinGroupCall(groupCallSession.id, memberId);
        }

        // Step 4: Verify all participants are connected
        final updatedSession = webrtcService.getCallSession(groupCallSession.id);
        final connectedParticipants = updatedSession.participants
            .where((p) => p.status == ParticipantStatus.connected)
            .length;
        
        expect(connectedParticipants, equals(memberIds.length));

        // Step 5: Test group call controls
        await webrtcService.muteParticipant(groupCallSession.id, memberIds[1]);
        await webrtcService.unmuteParticipant(groupCallSession.id, memberIds[1]);

        // Step 6: End group call
        await webrtcService.endGroupCall(groupCallSession.id);
      });
    });

    group('Offline Synchronization Tests', () {
      test('should handle offline message queuing and sync', () async {
        // Step 1: Initialize offline messaging service
        final offlineService = OfflineMessagingService();
        await offlineService.initialize();

        // Step 2: Simulate going offline
        await offlineService.setOfflineMode(true);

        // Step 3: Send messages while offline
        final offlineMessages = [
          MessageModel(
            id: 'offline_msg_001',
            senderId: 'offline_sender',
            recipientId: 'offline_recipient_1',
            content: 'Message sent while offline 1',
            messageType: MessageType.text,
            timestamp: DateTime.now(),
            status: MessageStatus.pending,
          ),
          MessageModel(
            id: 'offline_msg_002',
            senderId: 'offline_sender',
            recipientId: 'offline_recipient_2',
            content: 'Message sent while offline 2',
            messageType: MessageType.text,
            timestamp: DateTime.now(),
            status: MessageStatus.pending,
          ),
        ];

        for (final message in offlineMessages) {
          final result = await messagingService.sendMessage(message);
          expect(result.success, isTrue);
          expect(result.queued, isTrue);
        }

        // Step 4: Verify messages are queued
        final queuedMessages = await offlineService.getQueuedMessages();
        expect(queuedMessages.length, equals(offlineMessages.length));

        // Step 5: Simulate coming back online
        await offlineService.setOfflineMode(false);

        // Step 6: Trigger sync
        final syncService = MessageSyncService();
        final syncResult = await syncService.syncPendingMessages();
        
        expect(syncResult.success, isTrue);
        expect(syncResult.syncedMessages, equals(offlineMessages.length));

        // Step 7: Verify messages were sent
        final finalQueuedMessages = await offlineService.getQueuedMessages();
        expect(finalQueuedMessages.length, equals(0));
      });

      test('should handle conflict resolution during sync', () async {
        // Step 1: Create conflicting message scenarios
        final originalMessage = MessageModel(
          id: 'conflict_msg_001',
          senderId: 'conflict_sender',
          recipientId: 'conflict_recipient',
          content: 'Original message content',
          messageType: MessageType.text,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        );

        // Step 2: Send original message
        await messagingService.sendMessage(originalMessage);

        // Step 3: Simulate offline edit
        final offlineService = OfflineMessagingService();
        await offlineService.setOfflineMode(true);

        final editedMessage = originalMessage.copyWith(
          content: 'Edited message content while offline',
          editedAt: DateTime.now(),
        );

        await messagingService.editMessage(editedMessage);

        // Step 4: Simulate server-side edit while offline
        final serverEditedMessage = originalMessage.copyWith(
          content: 'Server-side edited content',
          editedAt: DateTime.now().add(const Duration(minutes: 1)),
        );

        // Step 5: Come back online and sync
        await offlineService.setOfflineMode(false);
        
        final conflictResolver = MessageConflictResolver();
        final resolution = await conflictResolver.resolveConflict(
          localMessage: editedMessage,
          serverMessage: serverEditedMessage,
        );

        expect(resolution.conflictType, equals(ConflictType.contentModified));
        expect(resolution.resolution, isNotNull);
      });
    });

    group('Performance Integration Tests', () {
      test('should handle high message throughput', () async {
        // Step 1: Prepare for high throughput test
        const messageCount = 100;
        const senderId = 'throughput_sender';
        const recipientId = 'throughput_recipient';

        final messages = List.generate(messageCount, (index) => MessageModel(
          id: 'throughput_msg_${index.toString().padLeft(3, '0')}',
          senderId: senderId,
          recipientId: recipientId,
          content: 'High throughput test message #$index',
          messageType: MessageType.text,
          timestamp: DateTime.now(),
          status: MessageStatus.pending,
        ));

        // Step 2: Send messages concurrently
        final stopwatch = Stopwatch()..start();
        
        final futures = messages.map((message) => messagingService.sendMessage(message));
        final results = await Future.wait(futures);
        
        stopwatch.stop();

        // Step 3: Verify all messages were sent successfully
        final successCount = results.where((result) => result.success).length;
        expect(successCount, equals(messageCount));

        // Step 4: Check performance metrics
        final averageTimePerMessage = stopwatch.elapsedMilliseconds / messageCount;
        expect(averageTimePerMessage, lessThan(100)); // Less than 100ms per message

        print('Sent $messageCount messages in ${stopwatch.elapsedMilliseconds}ms');
        print('Average time per message: ${averageTimePerMessage.toStringAsFixed(2)}ms');
      });

      test('should handle concurrent voice calls', () async {
        // Step 1: Prepare for concurrent call test
        const callCount = 5;
        final callPairs = List.generate(callCount, (index) => {
          'caller': 'concurrent_caller_$index',
          'recipient': 'concurrent_recipient_$index',
        });

        // Step 2: Initiate calls concurrently
        final stopwatch = Stopwatch()..start();
        
        final callFutures = callPairs.map((pair) => webrtcService.initiateCall(
          recipientId: pair['recipient']!,
          callType: CallType.voice,
        ));
        
        final callSessions = await Future.wait(callFutures);
        stopwatch.stop();

        // Step 3: Verify all calls were initiated
        expect(callSessions.length, equals(callCount));
        expect(callSessions.every((session) => session.id.isNotEmpty), isTrue);

        // Step 4: Accept all calls
        final acceptFutures = callSessions.map((session) => webrtcService.acceptCall(session.id));
        final acceptedSessions = await Future.wait(acceptFutures);
        
        expect(acceptedSessions.every((session) => session.status == CallStatus.connected), isTrue);

        // Step 5: End all calls
        final endFutures = callSessions.map((session) => webrtcService.endCall(session.id));
        await Future.wait(endFutures);

        print('Handled $callCount concurrent calls in ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    tearDownAll(() async {
      // Clean up services
      await messagingService.dispose();
      webrtcService.dispose();
    });
  });
}