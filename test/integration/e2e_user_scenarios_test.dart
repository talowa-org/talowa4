import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import '../test_utils/test_data_generator.dart';
import '../test_utils/mock_services.dart';
import 'package:talowa/services/messaging/messaging_service.dart';
import 'package:talowa/services/messaging/voice_calling_service.dart';
import 'package:talowa/services/messaging/group_management_service.dart';
import 'package:talowa/services/messaging/emergency_broadcast_service.dart';
import 'package:talowa/services/messaging/anonymous_reporting_service.dart';

void main() {
  group('End-to-End User Scenarios', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late MessagingService messagingService;
    late VoiceCallingService voiceService;
    late GroupManagementService groupService;
    late FileShareService fileService;
    late EmergencyBroadcastService emergencyService;
    late AnonymousReportingService anonymousService;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth();
      
      // Initialize services with mocks
      messagingService = MessagingService(firestore: firestore, auth: auth);
      voiceService = VoiceCallingService(firestore: firestore, auth: auth);
      groupService = GroupManagementService(firestore: firestore, auth: auth);
      fileService = FileShareService(firestore: firestore, auth: auth);
      emergencyService = EmergencyBroadcastService(firestore: firestore, auth: auth);
      anonymousService = AnonymousReportingService(firestore: firestore, auth: auth);
      
      // Populate test data
      await TestDataGenerator.populateTestUsers(firestore);
      await TestDataGenerator.populateTestGroups(firestore);
    });

    testWidgets('Scenario 1: New User Registration and First Message', (tester) async {
      // Simulate new user registration
      final newUser = await TestDataGenerator.createTestUser(
        id: 'new_user_001',
        phoneNumber: '+919876543210',
        role: 'member',
      );
      
      // User joins a village group
      final villageGroup = await groupService.createGroup(
        name: 'Kondapur Village',
        type: 'village',
        locationId: 'kondapur_village',
        createdBy: newUser.id,
      );
      
      // User sends first message
      final message = await messagingService.sendMessage(
        content: 'Hello everyone! I just joined TALOWA.',
        senderId: newUser.id,
        groupId: villageGroup.id,
        type: 'text',
      );
      
      expect(message.status, equals('sent'));
      expect(message.content, equals('Hello everyone! I just joined TALOWA.'));
      
      // Verify message is stored in Firestore
      final storedMessage = await firestore
          .collection('messages')
          .doc(message.id)
          .get();
      
      expect(storedMessage.exists, isTrue);
      expect(storedMessage.data()!['content'], equals(message.content));
    });

    testWidgets('Scenario 2: Coordinator Emergency Broadcast', (tester) async {
      // Create coordinator user
      final coordinator = await TestDataGenerator.createTestUser(
        id: 'coordinator_001',
        role: 'coordinator',
        location: 'medak_mandal',
      );
      
      // Create emergency broadcast
      final broadcast = await emergencyService.sendEmergencyBroadcast(
        title: 'Land Survey Alert',
        message: 'Government survey team arriving tomorrow at 10 AM. All farmers please gather at village center.',
        senderId: coordinator.id,
        scope: {
          'level': 'mandal',
          'locationIds': ['medak_mandal'],
        },
        channels: ['push', 'sms'],
        priority: 'high',
      );
      
      expect(broadcast.status, equals('sent'));
      expect(broadcast.deliveryTracking.isNotEmpty, isTrue);
      
      // Verify broadcast reaches all users in mandal
      final deliveryCount = broadcast.deliveryTracking.length;
      expect(deliveryCount, greaterThan(0));
      
      // Check delivery within 30 seconds requirement
      final deliveryTime = broadcast.deliveredAt!.difference(broadcast.createdAt);
      expect(deliveryTime.inSeconds, lessThan(30));
    });

    testWidgets('Scenario 3: Anonymous Land Grabbing Report', (tester) async {
      // Create reporter user
      final reporter = await TestDataGenerator.createTestUser(
        id: 'reporter_001',
        role: 'member',
        location: 'village_123',
      );
      
      // Submit anonymous report
      final report = await anonymousService.submitAnonymousReport(
        content: 'Local politician trying to grab 2 acres of community land near temple.',
        reporterId: reporter.id,
        category: 'land_grabbing',
        location: {
          'village': 'village_123',
          'coordinates': {'lat': 17.4065, 'lng': 78.4772},
        },
        evidence: ['photo_001.jpg', 'document_001.pdf'],
      );
      
      expect(report.caseId.isNotEmpty, isTrue);
      expect(report.isAnonymous, isTrue);
      expect(report.reporterIdentity, isNull); // Identity should be hidden
      
      // Verify coordinator can respond anonymously
      final coordinator = await TestDataGenerator.createTestUser(
        id: 'coordinator_002',
        role: 'coordinator',
      );
      
      final response = await anonymousService.respondToAnonymousReport(
        caseId: report.caseId,
        responderId: coordinator.id,
        message: 'Thank you for reporting. We are investigating this matter.',
      );
      
      expect(response.isAnonymous, isTrue);
      expect(response.responderIdentity, isNull);
    });

    testWidgets('Scenario 4: Group Voice Call for Legal Case Discussion', (tester) async {
      // Create legal team members
      final lawyer = await TestDataGenerator.createTestUser(
        id: 'lawyer_001',
        role: 'legal_team',
      );
      
      final coordinator = await TestDataGenerator.createTestUser(
        id: 'coordinator_003',
        role: 'coordinator',
      );
      
      final farmer = await TestDataGenerator.createTestUser(
        id: 'farmer_001',
        role: 'member',
      );
      
      // Create legal case group
      final legalGroup = await groupService.createGroup(
        name: 'Case #LC2024001 - Land Dispute',
        type: 'legal_case',
        createdBy: lawyer.id,
        settings: {
          'encryptionLevel': 'high_security',
          'whoCanAddMembers': 'admin',
          'requireApprovalToJoin': true,
        },
      );
      
      // Add members to legal group
      await groupService.addMembers(legalGroup.id, [coordinator.id, farmer.id]);
      
      // Initiate group voice call
      final call = await voiceService.initiateGroupCall(
        groupId: legalGroup.id,
        callerId: lawyer.id,
        participants: [lawyer.id, coordinator.id, farmer.id],
        isEncrypted: true,
      );
      
      expect(call.status, equals('initiated'));
      expect(call.isEncrypted, isTrue);
      expect(call.participants.length, equals(3));
      
      // Simulate call acceptance by all participants
      for (final participantId in [coordinator.id, farmer.id]) {
        await voiceService.acceptCall(call.id, participantId);
      }
      
      // Verify call is connected
      final connectedCall = await voiceService.getCallStatus(call.id);
      expect(connectedCall.status, equals('connected'));
      
      // Check connection time requirement (< 10 seconds)
      final connectionTime = connectedCall.connectedAt!.difference(call.initiatedAt);
      expect(connectionTime.inSeconds, lessThan(10));
    });

    testWidgets('Scenario 5: File Sharing with Land Records Integration', (tester) async {
      // Create farmer user
      final farmer = await TestDataGenerator.createTestUser(
        id: 'farmer_002',
        role: 'member',
        landRecords: ['LR_001', 'LR_002'],
      );
      
      // Create village group
      final villageGroup = await groupService.createGroup(
        name: 'Farmer Support Group',
        type: 'village',
        createdBy: farmer.id,
      );
      
      // Upload land document
      final landDocument = await fileService.uploadFile(
        fileName: 'patta_document.pdf',
        fileData: TestDataGenerator.generateMockPDFData(),
        uploadedBy: farmer.id,
        metadata: {
          'type': 'land_document',
          'landRecordId': 'LR_001',
          'documentType': 'patta',
          'gpsCoordinates': {'lat': 17.4065, 'lng': 78.4772},
        },
      );
      
      expect(landDocument.isEncrypted, isTrue);
      expect(landDocument.linkedToLandRecord, equals('LR_001'));
      
      // Share document in group
      final message = await messagingService.sendMessage(
        content: 'Sharing my patta document for verification',
        senderId: farmer.id,
        groupId: villageGroup.id,
        type: 'document',
        mediaUrl: landDocument.downloadUrl,
        mediaMetadata: landDocument.metadata,
      );
      
      expect(message.type, equals('document'));
      expect(message.mediaUrl, isNotNull);
      
      // Verify automatic land record linking
      final linkedRecord = await firestore
          .collection('land_records')
          .doc('LR_001')
          .get();
      
      expect(linkedRecord.exists, isTrue);
      expect(linkedRecord.data()!['documents'], contains(landDocument.id));
    });

    testWidgets('Scenario 6: Offline Message Sync and Delivery', (tester) async {
      // Create users
      final sender = await TestDataGenerator.createTestUser(id: 'sender_001');
      final recipient = await TestDataGenerator.createTestUser(id: 'recipient_001');
      
      // Simulate offline scenario for recipient
      await MockServices.simulateOfflineUser(recipient.id);
      
      // Send message while recipient is offline
      final message = await messagingService.sendMessage(
        content: 'Important meeting tomorrow at 2 PM',
        senderId: sender.id,
        recipientId: recipient.id,
        type: 'text',
      );
      
      expect(message.status, equals('sent')); // Sent but not delivered
      
      // Simulate recipient coming back online
      await MockServices.simulateOnlineUser(recipient.id);
      
      // Trigger sync process
      await messagingService.syncOfflineMessages(recipient.id);
      
      // Verify message is delivered
      final deliveredMessage = await messagingService.getMessage(message.id);
      expect(deliveredMessage.status, equals('delivered'));
      
      // Check delivery time requirement
      final deliveryTime = deliveredMessage.deliveredAt!.difference(message.timestamp);
      expect(deliveryTime.inSeconds, lessThan(5)); // Should sync quickly when back online
    });

    testWidgets('Scenario 7: Multi-language Message Translation', (tester) async {
      // Create users with different language preferences
      final teluguUser = await TestDataGenerator.createTestUser(
        id: 'telugu_user',
        language: 'te',
      );
      
      final hindiUser = await TestDataGenerator.createTestUser(
        id: 'hindi_user', 
        language: 'hi',
      );
      
      final englishUser = await TestDataGenerator.createTestUser(
        id: 'english_user',
        language: 'en',
      );
      
      // Create multilingual group
      final group = await groupService.createGroup(
        name: 'Multi-language Support Group',
        type: 'custom',
        createdBy: englishUser.id,
        settings: {
          'autoTranslate': true,
          'supportedLanguages': ['en', 'hi', 'te'],
        },
      );
      
      await groupService.addMembers(group.id, [teluguUser.id, hindiUser.id]);
      
      // Send message in Telugu
      final teluguMessage = await messagingService.sendMessage(
        content: 'నమస్కారం అందరికీ! ఈ రోజు సమావేశం ఎలా ఉంది?',
        senderId: teluguUser.id,
        groupId: group.id,
        type: 'text',
        language: 'te',
      );
      
      expect(teluguMessage.language, equals('te'));
      
      // Verify automatic translation for other users
      final translatedForHindi = await messagingService.getTranslatedMessage(
        teluguMessage.id,
        targetLanguage: 'hi',
      );
      
      expect(translatedForHindi.translatedContent, isNotNull);
      expect(translatedForHindi.targetLanguage, equals('hi'));
      
      final translatedForEnglish = await messagingService.getTranslatedMessage(
        teluguMessage.id,
        targetLanguage: 'en',
      );
      
      expect(translatedForEnglish.translatedContent, isNotNull);
      expect(translatedForEnglish.targetLanguage, equals('en'));
    });

    testWidgets('Scenario 8: Campaign Coordination with Event Management', (tester) async {
      // Create campaign coordinator
      final coordinator = await TestDataGenerator.createTestUser(
        id: 'campaign_coordinator',
        role: 'coordinator',
      );
      
      // Create campaign
      final campaign = await TestDataGenerator.createTestCampaign(
        id: 'campaign_001',
        name: 'Land Rights Awareness Rally',
        coordinatorId: coordinator.id,
        location: 'hyderabad_district',
      );
      
      // Create campaign group automatically
      final campaignGroup = await groupService.createGroup(
        name: 'Land Rights Rally - Hyderabad',
        type: 'campaign',
        createdBy: coordinator.id,
        linkedCampaignId: campaign.id,
      );
      
      // Add volunteers to campaign
      final volunteers = await TestDataGenerator.createMultipleTestUsers(
        count: 50,
        role: 'member',
        location: 'hyderabad_district',
      );
      
      await groupService.addMembers(
        campaignGroup.id,
        volunteers.map((u) => u.id).toList(),
      );
      
      // Send campaign update
      final update = await messagingService.sendMessage(
        content: 'Rally confirmed for Sunday 10 AM at Tank Bund. Please bring banners and water.',
        senderId: coordinator.id,
        groupId: campaignGroup.id,
        type: 'text',
        priority: 'high',
      );
      
      expect(update.priority, equals('high'));
      
      // Verify all volunteers receive notification
      final notifications = await messagingService.getNotificationsForGroup(campaignGroup.id);
      expect(notifications.length, equals(volunteers.length));
      
      // Check delivery time for bulk messaging
      final deliveryTimes = notifications.map((n) => 
        n.deliveredAt!.difference(update.timestamp).inSeconds
      ).toList();
      
      expect(deliveryTimes.every((time) => time < 5), isTrue); // All delivered within 5 seconds
    });
  });
}