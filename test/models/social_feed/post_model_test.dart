// Test file for PostModel
// Tests for post model functionality and validation

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/models/social_feed/index.dart';

void main() {
  group('PostModel Tests', () {
    group('Content Validation', () {
      test('should validate content successfully', () {
        // Arrange
        const content = 'This is a valid post about land rights';

        // Act
        final result = PostModel.validateContent(content);

        // Assert
        expect(result, isNull);
      });

      test('should reject empty content', () {
        // Arrange
        const content = '';

        // Act
        final result = PostModel.validateContent(content);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('cannot be empty'));
      });

      test('should reject content exceeding limit', () {
        // Arrange
        final content = 'a' * 2001; // Exceeds 2000 character limit

        // Act
        final result = PostModel.validateContent(content);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('cannot exceed 2000 characters'));
      });

      test('should reject whitespace-only content', () {
        // Arrange
        const content = '   \n\t   ';

        // Act
        final result = PostModel.validateContent(content);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('cannot be empty'));
      });
    });

    group('Hashtag Extraction', () {
      test('should extract hashtags from content', () {
        // Arrange
        const content = 'This post has #hashtag1 and #hashtag2 tags';

        // Act
        final hashtags = PostModel.extractHashtags(content);

        // Assert
        expect(hashtags, hasLength(2));
        expect(hashtags, contains('hashtag1'));
        expect(hashtags, contains('hashtag2'));
      });

      test('should extract Hindi hashtags', () {
        // Arrange
        const content = 'à¤¯à¤¹ à¤ªà¥‹à¤¸à¥à¤Ÿ à¤®à¥‡à¤‚ #à¤­à¥‚à¤®à¤¿_à¤…à¤§à¤¿à¤•à¤¾à¤° à¤”à¤° #à¤•à¤¿à¤¸à¤¾à¤¨_à¤…à¤§à¤¿à¤•à¤¾à¤° à¤¹à¥ˆ';

        // Act
        final hashtags = PostModel.extractHashtags(content);

        // Assert
        expect(hashtags, hasLength(2));
        expect(hashtags, contains('à¤­à¥‚à¤®à¤¿_à¤…à¤§à¤¿à¤•à¤¾à¤°'));
        expect(hashtags, contains('à¤•à¤¿à¤¸à¤¾à¤¨_à¤…à¤§à¤¿à¤•à¤¾à¤°'));
      });

      test('should handle content without hashtags', () {
        // Arrange
        const content = 'This post has no hashtags';

        // Act
        final hashtags = PostModel.extractHashtags(content);

        // Assert
        expect(hashtags, isEmpty);
      });

      test('should handle duplicate hashtags', () {
        // Arrange
        const content = 'Post with #test #test #different hashtags';

        // Act
        final hashtags = PostModel.extractHashtags(content);

        // Assert
        expect(hashtags, hasLength(3));
        expect(hashtags.where((tag) => tag == 'test'), hasLength(2));
        expect(hashtags, contains('different'));
      });
    });

    group('Post Visibility', () {
      test('should allow public post visibility to all users', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Public post content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
          visibility: PostVisibility.public,
        );

        // Act & Assert
        expect(post.isVisibleToUser(userId: 'user_123'), isTrue);
        expect(post.isVisibleToUser(userId: 'user_456'), isTrue);
      });

      test('should restrict coordinator-only posts', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Coordinator only post',
          category: PostCategory.announcement,
          createdAt: DateTime.now(),
          visibility: PostVisibility.coordinatorsOnly,
        );

        // Act & Assert
        expect(post.isVisibleToUser(
          userId: 'user_123',
          userRole: 'member',
        ), isFalse);
        
        expect(post.isVisibleToUser(
          userId: 'coordinator_123',
          userRole: 'village_coordinator',
        ), isTrue);
      });

      test('should allow author to see their own hidden posts', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Hidden post content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
          isHidden: true,
        );

        // Act & Assert
        expect(post.isVisibleToUser(userId: 'author_123'), isTrue);
        expect(post.isVisibleToUser(userId: 'other_user'), isFalse);
      });

      test('should restrict local community posts by location', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Local community post',
          category: PostCategory.communityNews,
          createdAt: DateTime.now(),
          visibility: PostVisibility.localCommunity,
          allowedLocations: ['Village A'],
        );

        // Act & Assert
        expect(post.isVisibleToUser(
          userId: 'user_123',
          userLocation: 'Village A',
        ), isTrue);
        
        expect(post.isVisibleToUser(
          userId: 'user_456',
          userLocation: 'Village B',
        ), isFalse);
      });
    });

    group('Post Interaction Permissions', () {
      test('should allow author to interact with their own posts', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Test post content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(post.canUserInteract(userId: 'author_123'), isTrue);
      });

      test('should restrict interaction with reported posts for regular users', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Reported post content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
          isReported: true,
        );

        // Act & Assert
        expect(post.canUserInteract(
          userId: 'user_123',
          userRole: 'member',
        ), isFalse);
        
        expect(post.canUserInteract(
          userId: 'coordinator_123',
          userRole: 'village_coordinator',
        ), isTrue);
      });

      test('should allow coordinators to interact with hidden posts', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Hidden post content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
          isHidden: true,
        );

        // Act & Assert
        expect(post.canUserInteract(
          userId: 'user_123',
          userRole: 'member',
        ), isFalse);
        
        expect(post.canUserInteract(
          userId: 'coordinator_123',
          userRole: 'village_coordinator',
        ), isTrue);
      });
    });

    group('Time Formatting', () {
      test('should format recent time correctly', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Recent post',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        );

        // Act
        final timeAgo = post.getTimeAgo();

        // Assert
        expect(timeAgo, contains('30m ago'));
      });

      test('should format hours correctly', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Hour old post',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        );

        // Act
        final timeAgo = post.getTimeAgo();

        // Assert
        expect(timeAgo, contains('2h ago'));
      });

      test('should format days correctly', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Day old post',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        );

        // Act
        final timeAgo = post.getTimeAgo();

        // Assert
        expect(timeAgo, contains('3d ago'));
      });

      test('should format very recent time as "Just now"', () {
        // Arrange
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Just posted',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        // Act
        final timeAgo = post.getTimeAgo();

        // Assert
        expect(timeAgo, equals('Just now'));
      });

      test('should format old posts with date', () {
        // Arrange
        final oldDate = DateTime(2024, 1, 15);
        final post = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Old post',
          category: PostCategory.generalDiscussion,
          createdAt: oldDate,
        );

        // Act
        final timeAgo = post.getTimeAgo();

        // Assert
        expect(timeAgo, contains('15/1/2024'));
      });
    });

    group('Post Categories', () {
      test('should have correct display names for categories', () {
        expect(PostCategory.successStory.displayName, equals('Success Story'));
        expect(PostCategory.legalUpdate.displayName, equals('Legal Update'));
        expect(PostCategory.announcement.displayName, equals('Announcement'));
        expect(PostCategory.emergency.displayName, equals('Emergency'));
        expect(PostCategory.generalDiscussion.displayName, equals('General Discussion'));
        expect(PostCategory.landRights.displayName, equals('Land Rights'));
        expect(PostCategory.communityNews.displayName, equals('Community News'));
        expect(PostCategory.education.displayName, equals('Education'));
        expect(PostCategory.healthAndSafety.displayName, equals('Health & Safety'));
        expect(PostCategory.agriculture.displayName, equals('Agriculture'));
      });

      test('should have appropriate icons for categories', () {
        expect(PostCategory.successStory.icon, equals('ðŸ†'));
        expect(PostCategory.legalUpdate.icon, equals('âš–ï¸'));
        expect(PostCategory.announcement.icon, equals('ðŸ“¢'));
        expect(PostCategory.emergency.icon, equals('ðŸš¨'));
        expect(PostCategory.generalDiscussion.icon, equals('ðŸ’¬'));
        expect(PostCategory.landRights.icon, equals('ðŸžï¸'));
        expect(PostCategory.communityNews.icon, equals('ðŸ“°'));
        expect(PostCategory.education.icon, equals('ðŸ“š'));
        expect(PostCategory.healthAndSafety.icon, equals('ðŸ¥'));
        expect(PostCategory.agriculture.icon, equals('ðŸŒ¾'));
      });
    });

    group('Post Visibility Settings', () {
      test('should have correct display names for visibility', () {
        expect(PostVisibility.public.displayName, equals('Public'));
        expect(PostVisibility.coordinatorsOnly.displayName, equals('Coordinators Only'));
        expect(PostVisibility.localCommunity.displayName, equals('Local Community'));
        expect(PostVisibility.directNetwork.displayName, equals('Direct Network'));
      });

      test('should have appropriate descriptions for visibility', () {
        expect(PostVisibility.public.description, equals('Visible to everyone'));
        expect(PostVisibility.coordinatorsOnly.description, equals('Only coordinators can see this'));
        expect(PostVisibility.localCommunity.description, equals('Visible to your local community'));
        expect(PostVisibility.directNetwork.description, equals('Visible to your direct network only'));
      });
    });

    group('Post Model Equality', () {
      test('should be equal when IDs match', () {
        // Arrange
        final post1 = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Test content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
        );

        final post2 = PostModel(
          id: 'test_post',
          authorId: 'different_author',
          authorName: 'Different Author',
          content: 'Different content',
          category: PostCategory.announcement,
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(post1, equals(post2));
        expect(post1.hashCode, equals(post2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        // Arrange
        final post1 = PostModel(
          id: 'test_post_1',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Test content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
        );

        final post2 = PostModel(
          id: 'test_post_2',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Test content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(post1, isNot(equals(post2)));
        expect(post1.hashCode, isNot(equals(post2.hashCode)));
      });
    });

    group('Post Model CopyWith', () {
      test('should create copy with updated fields', () {
        // Arrange
        final originalPost = PostModel(
          id: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Original content',
          category: PostCategory.generalDiscussion,
          createdAt: DateTime.now(),
          likesCount: 5,
          commentsCount: 2,
        );

        // Act
        final updatedPost = originalPost.copyWith(
          content: 'Updated content',
          likesCount: 10,
        );

        // Assert
        expect(updatedPost.id, equals(originalPost.id));
        expect(updatedPost.authorId, equals(originalPost.authorId));
        expect(updatedPost.content, equals('Updated content'));
        expect(updatedPost.likesCount, equals(10));
        expect(updatedPost.commentsCount, equals(2)); // Unchanged
      });
    });
  });
}
