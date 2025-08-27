import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/referral/recognition_retention_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('RecognitionRetentionService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      RecognitionRetentionService.setFirestoreInstance(fakeFirestore);
    });

    group('Promotion Certificate Generation', () {
      test('should generate promotion certificate', () async {
        final certificate = await RecognitionRetentionService.generatePromotionCertificate(
          userId: 'user1',
          userName: 'John Doe',
          userPhotoUrl: 'https://example.com/photo.jpg',
          oldRole: 'member',
          newRole: 'organizer',
          achievements: {'referrals': 10, 'teamSize': 25},
        );

        expect(certificate.userId, equals('user1'));
        expect(certificate.userName, equals('John Doe'));
        expect(certificate.oldRole, equals('member'));
        expect(certificate.newRole, equals('organizer'));
        expect(certificate.digitalSignature, isNotEmpty);
        expect(certificate.certificateUrl, isNotEmpty);

        // Verify certificate was saved to database
        final certificateDoc = await fakeFirestore
            .collection('certificates')
            .doc(certificate.id)
            .get();
        
        expect(certificateDoc.exists, isTrue);
        expect(certificateDoc.data()!['userId'], equals('user1'));
      });
    });

    group('Celebration Animation', () {
      test('should create celebration animation data', () {
        final animation = RecognitionRetentionService.createCelebrationAnimation(
          type: 'promotion',
          title: 'Congratulations!',
          subtitle: 'You\'ve been promoted',
          primaryColor: Colors.blue,
          secondaryColor: Colors.lightBlue,
          confettiColors: ['#FFD700', '#FF6B6B'],
          soundEffect: 'celebration.mp3',
          duration: const Duration(seconds: 3),
        );

        expect(animation['type'], equals('promotion'));
        expect(animation['title'], equals('Congratulations!'));
        expect(animation['subtitle'], equals('You\'ve been promoted'));
        expect(animation['primaryColor'], equals(Colors.blue.value));
        expect(animation['confettiColors'], equals(['#FFD700', '#FF6B6B']));
        expect(animation['duration'], equals(3000));
        expect(animation['animations'], isA<Map<String, dynamic>>());
        expect(animation['animations']['confetti']['enabled'], isTrue);
        expect(animation['animations']['fireworks']['enabled'], isTrue);
      });

      test('should disable fireworks for non-promotion types', () {
        final animation = RecognitionRetentionService.createCelebrationAnimation(
          type: 'achievement',
          title: 'Achievement Unlocked!',
          subtitle: 'Great job!',
          primaryColor: Colors.green,
          secondaryColor: Colors.lightGreen,
          confettiColors: ['#00FF00'],
          soundEffect: 'achievement.mp3',
          duration: const Duration(seconds: 2),
        );

        expect(animation['animations']['fireworks']['enabled'], isFalse);
        expect(animation['animations']['confetti']['enabled'], isTrue);
      });
    });

    group('Role-Specific Badge Creation', () {
      test('should create role-specific badge', () async {
        final badge = await RecognitionRetentionService.createRoleSpecificBadge(
          userId: 'user1',
          role: 'organizer',
          achievements: {'firstReferral': true, 'teamBuilder': true},
          statistics: {'directReferrals': 10, 'teamSize': 25},
        );

        expect(badge['userId'], equals('user1'));
        expect(badge['role'], equals('organizer'));
        expect(badge['roleName'], equals('Organizer'));
        expect(badge['badgeUrl'], isNotEmpty);
        expect(badge['isActive'], isTrue);
        expect(badge['displayOrder'], greaterThan(0));

        // Verify badge was saved to database
        final badgeDoc = await fakeFirestore
            .collection('user_badges')
            .doc(badge['id'])
            .get();
        
        expect(badgeDoc.exists, isTrue);
      });
    });

    group('Achievement Timeline Tracking', () {
      test('should track achievement timeline', () async {
        final achievement = Achievement(
          id: 'achievement1',
          name: 'First Referral',
          description: 'Made your first referral',
          badgeUrl: 'https://example.com/badge.png',
          category: 'referral',
          points: 100,
          criteria: {'referrals': 1},
          unlockedAt: DateTime.now(),
          isShared: false,
          rewards: {'bonus': 50},
        );

        await RecognitionRetentionService.trackAchievementTimeline(
          userId: 'user1',
          achievement: achievement,
        );

        final timeline = await fakeFirestore
            .collection('achievement_timeline')
            .where('userId', isEqualTo: 'user1')
            .get();

        expect(timeline.docs.length, equals(1));
        
        final timelineData = timeline.docs.first.data();
        expect(timelineData['achievementId'], equals('achievement1'));
        expect(timelineData['achievementName'], equals('First Referral'));
        expect(timelineData['points'], equals(100));
      });
    });

    group('Social Media Sharing Content', () {
      test('should generate social sharing content', () {
        final content = RecognitionRetentionService.generateSocialSharingContent(
          type: 'promotion',
          userName: 'John Doe',
          title: 'Promoted to Organizer',
          description: 'John Doe has been promoted to Organizer!',
          imageUrl: 'https://example.com/certificate.png',
          hashtags: ['#Promotion', '#Success'],
        );

        expect(content['type'], equals('promotion'));
        expect(content['platforms'], isA<Map<String, dynamic>>());
        
        final facebook = content['platforms']['facebook'];
        expect(facebook['text'], contains('John Doe has been promoted to Organizer!'));
        expect(facebook['text'], contains('#Talowa'));
        expect(facebook['text'], contains('#Promotion'));
        expect(facebook['imageUrl'], equals('https://example.com/certificate.png'));

        final twitter = content['platforms']['twitter'];
        expect(twitter['text'], contains('Promoted to Organizer'));
        expect(twitter['text'], contains('#Success'));

        expect(content['brandedGraphics'], isA<Map<String, dynamic>>());
        expect(content['brandedGraphics']['certificateUrl'], isNotEmpty);
      });
    });

    group('Role Feature Unlocking', () {
      test('should unlock role features', () async {
        // Setup user
        await fakeFirestore.collection('users').doc('user1').set({
          'fullName': 'John Doe',
          'currentRole': 'member',
        });

        final result = await RecognitionRetentionService.unlockRoleFeatures(
          userId: 'user1',
          newRole: 'organizer',
          oldRole: 'member',
        );

        expect(result['unlockedFeatures'], isA<List<String>>());
        expect(result['allFeatures'], isA<Map<String, dynamic>>());
        expect(result['guidedTour'], isA<Map<String, dynamic>>());
        expect(result['celebrationData'], isA<Map<String, dynamic>>());

        // Verify user was updated
        final userDoc = await fakeFirestore.collection('users').doc('user1').get();
        final userData = userDoc.data()!;
        expect(userData.containsKey('roleFeatures'), isTrue);
        expect(userData.containsKey('newFeaturesUnlocked'), isTrue);
      });
    });

    group('Team Promotion Notifications', () {
      test('should send team promotion notifications', () async {
        final teamMemberIds = ['member1', 'member2', 'member3'];

        await RecognitionRetentionService.sendTeamPromotionNotifications(
          promotedUserId: 'user1',
          promotedUserName: 'John Doe',
          newRole: 'organizer',
          teamMemberIds: teamMemberIds,
        );

        final notifications = await fakeFirestore
            .collection('notifications')
            .get();

        expect(notifications.docs.length, equals(3));

        for (final doc in notifications.docs) {
          final data = doc.data();
          expect(data['type'], equals('team_leader_promotion'));
          expect(data['title'], contains('Team Leader Promoted'));
          expect(data['message'], contains('John Doe'));
          expect(data['message'], contains('Organizer'));
          expect(teamMemberIds.contains(data['userId']), isTrue);
        }
      });
    });

    group('Profile Card Updates', () {
      test('should update profile card', () async {
        final achievements = [
          Achievement(
            id: 'achievement1',
            name: 'First Referral',
            description: 'Made your first referral',
            badgeUrl: 'https://example.com/badge1.png',
            category: 'referral',
            points: 100,
            criteria: {},
            unlockedAt: DateTime.now(),
            isShared: false,
            rewards: {},
          ),
        ];

        final statistics = {
          'directReferrals': 10,
          'teamSize': 25,
          'activeTeamSize': 20,
        };

        final profileCard = await RecognitionRetentionService.updateProfileCard(
          userId: 'user1',
          newRole: 'organizer',
          achievements: achievements,
          statistics: statistics,
        );

        expect(profileCard['userId'], equals('user1'));
        expect(profileCard['role'], equals('organizer'));
        expect(profileCard['roleName'], equals('Organizer'));
        expect(profileCard['achievements'], isA<List>());
        expect(profileCard['statistics'], equals(statistics));

        // Verify profile card was saved
        final profileDoc = await fakeFirestore
            .collection('profile_cards')
            .doc('user1')
            .get();
        
        expect(profileDoc.exists, isTrue);
      });
    });

    group('Achievement Gallery', () {
      test('should get achievement gallery', () async {
        // Setup test data
        await fakeFirestore.collection('achievement_timeline').add({
          'userId': 'user1',
          'achievementId': 'achievement1',
          'achievementName': 'First Referral',
          'achievementCategory': 'referral',
          'points': 100,
          'unlockedAt': Timestamp.fromDate(DateTime.now()),
        });

        await fakeFirestore.collection('certificates').add({
          'userId': 'user1',
          'userName': 'John Doe',
          'oldRole': 'member',
          'newRole': 'organizer',
          'promotionDate': Timestamp.fromDate(DateTime.now()),
        });

        await fakeFirestore.collection('user_badges').add({
          'userId': 'user1',
          'role': 'organizer',
          'isActive': true,
          'displayOrder': 1,
        });

        final gallery = await RecognitionRetentionService.getAchievementGallery('user1');

        expect(gallery['achievements'], isA<List>());
        expect(gallery['certificates'], isA<List>());
        expect(gallery['badges'], isA<List>());
        expect(gallery['totalPoints'], isA<int>());
        expect(gallery['categories'], isA<Map<String, dynamic>>());
        expect(gallery['milestones'], isA<List>());

        expect(gallery['achievements'].length, equals(1));
        expect(gallery['certificates'].length, equals(1));
        expect(gallery['badges'].length, equals(1));
      });
    });

    group('Certificate Download', () {
      test('should download certificate', () async {
        // Setup certificate
        const certificateId = 'cert123';
        await fakeFirestore.collection('certificates').doc(certificateId).set({
          'userId': 'user1',
          'userName': 'John Doe',
          'oldRole': 'member',
          'newRole': 'organizer',
          'promotionDate': Timestamp.fromDate(DateTime.now()),
          'certificateUrl': 'https://example.com/cert.png',
          'digitalSignature': 'SIGNATURE123',
          'achievements': {},
          'isDownloaded': false,
        });

        final downloadUrl = await RecognitionRetentionService.downloadCertificate(certificateId);

        expect(downloadUrl, equals('https://example.com/cert.png'));

        // Verify certificate was marked as downloaded
        final certificateDoc = await fakeFirestore
            .collection('certificates')
            .doc(certificateId)
            .get();
        
        expect(certificateDoc.data()!['isDownloaded'], isTrue);
        expect(certificateDoc.data()!.containsKey('downloadedAt'), isTrue);
      });

      test('should throw exception for non-existent certificate', () async {
        expect(
          () => RecognitionRetentionService.downloadCertificate('nonexistent'),
          throwsA(isA<RecognitionRetentionException>()),
        );
      });
    });

    group('Data Models', () {
      test('should create Achievement from map', () {
        final map = {
          'id': 'achievement1',
          'name': 'First Referral',
          'description': 'Made your first referral',
          'badgeUrl': 'https://example.com/badge.png',
          'category': 'referral',
          'points': 100,
          'criteria': <String, dynamic>{'referrals': 1},
          'unlockedAt': Timestamp.fromDate(DateTime.now()),
          'isShared': false,
          'rewards': <String, dynamic>{'bonus': 50},
        };

        final achievement = Achievement.fromMap(map);

        expect(achievement.id, equals('achievement1'));
        expect(achievement.name, equals('First Referral'));
        expect(achievement.points, equals(100));
        expect(achievement.category, equals('referral'));
      });

      test('should create PromotionCertificate from map', () {
        final map = {
          'id': 'cert1',
          'userId': 'user1',
          'userName': 'John Doe',
          'userPhotoUrl': 'https://example.com/photo.jpg',
          'oldRole': 'member',
          'newRole': 'organizer',
          'promotionDate': Timestamp.fromDate(DateTime.now()),
          'certificateUrl': 'https://example.com/cert.png',
          'digitalSignature': 'SIGNATURE123',
          'achievements': <String, dynamic>{'referrals': 10},
          'isDownloaded': false,
        };

        final certificate = PromotionCertificate.fromMap(map);

        expect(certificate.id, equals('cert1'));
        expect(certificate.userId, equals('user1'));
        expect(certificate.userName, equals('John Doe'));
        expect(certificate.oldRole, equals('member'));
        expect(certificate.newRole, equals('organizer'));
        expect(certificate.isDownloaded, isFalse);
      });
    });

    group('Error Handling', () {
      test('should create RecognitionRetentionException correctly', () {
        const message = 'Test recognition error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = RecognitionRetentionException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test recognition error';
        final exception = const RecognitionRetentionException(message);

        expect(exception.code, equals('RECOGNITION_RETENTION_FAILED'));
        expect(exception.context, isNull);
      });
    });
  });
}
