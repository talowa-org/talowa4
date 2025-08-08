// Test file for ContentModerationService
// Comprehensive tests for content moderation functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:talowa/services/social_feed/content_moderation_service.dart';

void main() {
  group('ContentModerationService Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(signedIn: true);
    });

    group('Content Validation', () {
      test('should validate clean content successfully', () async {
        // Arrange
        const content = 'This is a clean post about land rights and farming';
        const authorId = 'test_user_123';

        // Act
        final result = await ContentModerationService.validateContent(
          content: content,
          authorId: authorId,
        );

        // Assert
        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
        expect(result.requiresReview, isFalse);
        expect(result.confidence, greaterThan(0.8));
      });

      test('should detect inappropriate language', () async {
        // Arrange
        const content = 'This post contains hate speech and violence';
        const authorId = 'test_user_123';

        // Act
        final result = await ContentModerationService.validateContent(
          content: content,
          authorId: authorId,
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.issues, isNotEmpty);
        expect(result.requiresReview, isTrue);
        expect(result.issues.any((issue) => issue.contains('inappropriate language')), isTrue);
      });

      test('should detect suspicious patterns', () async {
        // Arrange
        const content = 'Contact me at 9876543210 or email@example.com';
        const authorId = 'test_user_123';

        // Act
        final result = await ContentModerationService.validateContent(
          content: content,
          authorId: authorId,
        );

        // Assert
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any((warning) => warning.contains('personal information')), isTrue);
      });

      test('should validate content length limits', () async {
        // Arrange
        final longContent = 'a' * 2001; // Exceeds 2000 character limit
        const authorId = 'test_user_123';

        // Act
        final result = await ContentModerationService.validateContent(
          content: longContent,
          authorId: authorId,
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.contains('maximum length')), isTrue);
      });

      test('should validate empty content', () async {
        // Arrange
        const content = '';
        const authorId = 'test_user_123';

        // Act
        final result = await ContentModerationService.validateContent(
          content: content,
          authorId: authorId,
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.contains('cannot be empty')), isTrue);
      });

      test('should validate image URL limits', () async {
        // Arrange
        const content = 'Post with many images';
        const authorId = 'test_user_123';
        final imageUrls = List.generate(6, (index) => 'https://example.com/image$index.jpg');

        // Act
        final result = await ContentModerationService.validateContent(
          content: content,
          authorId: authorId,
          imageUrls: imageUrls,
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.contains('more than 5 images')), isTrue);
      });

      test('should validate document URL limits', () async {
        // Arrange
        const content = 'Post with many documents';
        const authorId = 'test_user_123';
        final documentUrls = List.generate(4, (index) => 'https://example.com/doc$index.pdf');

        // Act
        final result = await ContentModerationService.validateContent(
          content: content,
          authorId: authorId,
          documentUrls: documentUrls,
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.contains('more than 3 documents')), isTrue);
      });
    });

    group('Content Reporting', () {
      test('should report content successfully', () async {
        // Arrange
        const postId = 'test_post_123';
        const reporterId = 'reporter_123';
        const reason = 'inappropriate_content';
        const description = 'This post contains offensive language';

        // Mock reporter profile
        await fakeFirestore.collection('users').doc(reporterId).set({
          'fullName': 'Test Reporter',
          'role': 'member',
        });

        // Mock post
        await fakeFirestore.collection('posts').doc(postId).set({
          'content': 'Test post content',
          'authorId': 'author_123',
          'isReported': false,
          'reportCount': 0,
        });

        // Act
        await ContentModerationService.reportContent(
          postId: postId,
          reporterId: reporterId,
          reason: reason,
          description: description,
        );

        // Assert
        final reports = await fakeFirestore.collection('post_reports').get();
        expect(reports.docs.length, equals(1));
        
        final reportData = reports.docs.first.data();
        expect(reportData['postId'], equals(postId));
        expect(reportData['reportedBy'], equals(reporterId));
        expect(reportData['reason'], equals(reason));
        expect(reportData['status'], equals('pending'));

        // Check post was flagged
        final postDoc = await fakeFirestore.collection('posts').doc(postId).get();
        final postData = postDoc.data() as Map<String, dynamic>;
        expect(postData['isReported'], isTrue);
        expect(postData['reportCount'], equals(1));
      });

      test('should fail to report with invalid reporter', () async {
        // Arrange
        const postId = 'test_post_123';
        const reporterId = 'invalid_reporter';
        const reason = 'inappropriate_content';

        // Act & Assert
        expect(() async {
          await ContentModerationService.reportContent(
            postId: postId,
            reporterId: reporterId,
            reason: reason,
          );
        }, throwsException);
      });
    });

    group('Content Moderation', () {
      test('should hide content successfully by coordinator', () async {
        // Arrange
        const postId = 'test_post_123';
        const moderatorId = 'coordinator_123';
        const reason = 'Inappropriate content';

        // Mock coordinator profile
        await fakeFirestore.collection('users').doc(moderatorId).set({
          'fullName': 'Test Coordinator',
          'role': 'village_coordinator',
        });

        // Mock post
        await fakeFirestore.collection('posts').doc(postId).set({
          'content': 'Test post content',
          'authorId': 'author_123',
          'isHidden': false,
        });

        // Act
        await ContentModerationService.moderateContent(
          postId: postId,
          moderatorId: moderatorId,
          hide: true,
          reason: reason,
        );

        // Assert
        final postDoc = await fakeFirestore.collection('posts').doc(postId).get();
        final postData = postDoc.data() as Map<String, dynamic>;
        expect(postData['isHidden'], isTrue);
        expect(postData['moderationReason'], equals(reason));
        expect(postData['moderatedBy'], equals(moderatorId));
      });

      test('should fail moderation with insufficient permissions', () async {
        // Arrange
        const postId = 'test_post_123';
        const moderatorId = 'regular_user_123';

        // Mock regular user profile
        await fakeFirestore.collection('users').doc(moderatorId).set({
          'fullName': 'Regular User',
          'role': 'member',
        });

        // Act & Assert
        expect(() async {
          await ContentModerationService.moderateContent(
            postId: postId,
            moderatorId: moderatorId,
            hide: true,
          );
        }, throwsException);
      });

      test('should unhide content successfully', () async {
        // Arrange
        const postId = 'test_post_123';
        const moderatorId = 'coordinator_123';

        // Mock coordinator profile
        await fakeFirestore.collection('users').doc(moderatorId).set({
          'fullName': 'Test Coordinator',
          'role': 'village_coordinator',
        });

        // Mock hidden post
        await fakeFirestore.collection('posts').doc(postId).set({
          'content': 'Test post content',
          'authorId': 'author_123',
          'isHidden': true,
          'moderationReason': 'Previously hidden',
        });

        // Act
        await ContentModerationService.moderateContent(
          postId: postId,
          moderatorId: moderatorId,
          hide: false,
        );

        // Assert
        final postDoc = await fakeFirestore.collection('posts').doc(postId).get();
        final postData = postDoc.data() as Map<String, dynamic>;
        expect(postData['isHidden'], isFalse);
      });
    });

    group('Report Management', () {
      test('should get pending reports', () async {
        // Arrange
        // Create test reports
        await fakeFirestore.collection('post_reports').add({
          'postId': 'post_1',
          'reportedBy': 'user_1',
          'reporterName': 'User One',
          'reason': 'spam',
          'status': 'pending',
          'createdAt': DateTime.now(),
        });

        await fakeFirestore.collection('post_reports').add({
          'postId': 'post_2',
          'reportedBy': 'user_2',
          'reporterName': 'User Two',
          'reason': 'inappropriate_content',
          'status': 'reviewed',
          'createdAt': DateTime.now(),
        });

        // Mock posts
        await fakeFirestore.collection('posts').doc('post_1').set({
          'content': 'Spam post content',
          'authorName': 'Spam Author',
        });

        await fakeFirestore.collection('posts').doc('post_2').set({
          'content': 'Inappropriate post content',
          'authorName': 'Bad Author',
        });

        // Act
        final pendingReports = await ContentModerationService.getPendingReports();

        // Assert
        expect(pendingReports.length, equals(1));
        expect(pendingReports.first['reason'], equals('spam'));
        expect(pendingReports.first['postContent'], equals('Spam post content'));
      });

      test('should review report successfully', () async {
        // Arrange
        const reviewerId = 'coordinator_123';
        const action = 'hide_content';
        const notes = 'Content violates community guidelines';

        // Mock coordinator profile
        await fakeFirestore.collection('users').doc(reviewerId).set({
          'fullName': 'Test Coordinator',
          'role': 'village_coordinator',
        });

        // Create test report
        final reportRef = await fakeFirestore.collection('post_reports').add({
          'postId': 'post_1',
          'reportedBy': 'user_1',
          'reason': 'inappropriate_content',
          'status': 'pending',
          'createdAt': DateTime.now(),
        });

        // Mock post
        await fakeFirestore.collection('posts').doc('post_1').set({
          'content': 'Inappropriate content',
          'authorId': 'author_1',
          'isHidden': false,
        });

        // Act
        await ContentModerationService.reviewReport(
          reportId: reportRef.id,
          reviewerId: reviewerId,
          action: action,
          notes: notes,
        );

        // Assert
        final reportDoc = await fakeFirestore.collection('post_reports').doc(reportRef.id).get();
        final reportData = reportDoc.data() as Map<String, dynamic>;
        expect(reportData['status'], equals('reviewed'));
        expect(reportData['action'], equals(action));
        expect(reportData['reviewedBy'], equals(reviewerId));
        expect(reportData['reviewNotes'], equals(notes));

        // Check if post was hidden (since action was 'hide_content')
        final postDoc = await fakeFirestore.collection('posts').doc('post_1').get();
        final postData = postDoc.data() as Map<String, dynamic>;
        expect(postData['isHidden'], isTrue);
      });
    });

    group('Automated Scanning', () {
      test('should perform automated scanning and flag high-risk content', () async {
        // Arrange
        const postId = 'test_post_123';

        // Create post with inappropriate content
        await fakeFirestore.collection('posts').doc(postId).set({
          'content': 'This post contains hate speech and violence',
          'authorId': 'author_123',
          'imageUrls': [],
          'documentUrls': [],
          'reportCount': 0,
        });

        // Act
        final result = await ContentModerationService.performAutomatedScanning(postId);

        // Assert
        expect(result.postId, equals(postId));
        expect(result.riskScore, greaterThan(0));
        expect(result.action, isNot(AutoModerationAction.none));
        expect(result.validationResult.hasIssues, isTrue);
      });

      test('should handle scanning errors gracefully', () async {
        // Arrange
        const postId = 'nonexistent_post';

        // Act
        final result = await ContentModerationService.performAutomatedScanning(postId);

        // Assert
        expect(result.action, equals(AutoModerationAction.error));
        expect(result.reason, contains('Post not found'));
      });
    });

    group('Moderation Statistics', () {
      test('should calculate moderation statistics', () async {
        // Arrange
        final fromDate = DateTime.now().subtract(const Duration(days: 7));
        final toDate = DateTime.now();

        // Create test reports
        await fakeFirestore.collection('post_reports').add({
          'postId': 'post_1',
          'reason': 'spam',
          'status': 'pending',
          'createdAt': fromDate.add(const Duration(days: 1)),
        });

        await fakeFirestore.collection('post_reports').add({
          'postId': 'post_2',
          'reason': 'inappropriate_content',
          'status': 'reviewed',
          'action': 'hide_content',
          'createdAt': fromDate.add(const Duration(days: 2)),
          'reviewedAt': fromDate.add(const Duration(days: 2, hours: 2)),
        });

        // Act
        final stats = await ContentModerationService.getModerationStats(
          fromDate: fromDate,
          toDate: toDate,
        );

        // Assert
        expect(stats['totalReports'], equals(2));
        expect(stats['pendingReports'], equals(1));
        expect(stats['resolvedReports'], equals(1));
        expect(stats['hiddenPosts'], equals(1));
        expect(stats['reasonBreakdown']['spam'], equals(1));
        expect(stats['reasonBreakdown']['inappropriate_content'], equals(1));
      });
    });

    group('Bulk Moderation', () {
      test('should perform bulk hide action', () async {
        // Arrange
        const moderatorId = 'coordinator_123';
        final postIds = ['post_1', 'post_2', 'post_3'];
        const reason = 'Bulk moderation action';

        // Mock coordinator profile
        await fakeFirestore.collection('users').doc(moderatorId).set({
          'fullName': 'Test Coordinator',
          'role': 'village_coordinator',
        });

        // Create test posts
        for (final postId in postIds) {
          await fakeFirestore.collection('posts').doc(postId).set({
            'content': 'Test post $postId',
            'authorId': 'author_$postId',
            'isHidden': false,
          });
        }

        // Act
        await ContentModerationService.bulkModerationAction(
          postIds: postIds,
          moderatorId: moderatorId,
          action: BulkModerationAction.hide,
          reason: reason,
        );

        // Assert
        for (final postId in postIds) {
          final postDoc = await fakeFirestore.collection('posts').doc(postId).get();
          final postData = postDoc.data() as Map<String, dynamic>;
          expect(postData['isHidden'], isTrue);
          expect(postData['moderationReason'], equals(reason));
          expect(postData['moderatedBy'], equals(moderatorId));
        }
      });

      test('should fail bulk moderation with insufficient permissions', () async {
        // Arrange
        const moderatorId = 'regular_user_123';
        final postIds = ['post_1', 'post_2'];

        // Mock regular user profile
        await fakeFirestore.collection('users').doc(moderatorId).set({
          'fullName': 'Regular User',
          'role': 'member',
        });

        // Act & Assert
        expect(() async {
          await ContentModerationService.bulkModerationAction(
            postIds: postIds,
            moderatorId: moderatorId,
            action: BulkModerationAction.hide,
          );
        }, throwsException);
      });
    });

    group('Language Detection', () {
      test('should detect Hindi inappropriate words', () async {
        // Arrange
        const content = 'यह पोस्ट में नफरत और हिंसा है';
        const authorId = 'test_user_123';

        // Act
        final result = await ContentModerationService.validateContent(
          content: content,
          authorId: authorId,
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.issues, isNotEmpty);
        expect(result.requiresReview, isTrue);
      });

      test('should detect Telugu inappropriate words', () async {
        // Arrange
        const content = 'ఈ పోస్ట్‌లో ద్వేషం మరియు హింస ఉంది';
        const authorId = 'test_user_123';

        // Act
        final result = await ContentModerationService.validateContent(
          content: content,
          authorId: authorId,
        );

        // Assert
        expect(result.isValid, isFalse);
        expect(result.issues, isNotEmpty);
        expect(result.requiresReview, isTrue);
      });
    });
  });
}