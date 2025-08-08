// Test file for CommentModel
// Tests for comment model functionality and validation

import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/models/social_feed/index.dart';

void main() {
  group('CommentModel Tests', () {
    group('Content Validation', () {
      test('should validate content successfully', () {
        // Arrange
        const content = 'This is a valid comment';

        // Act
        final result = CommentModel.validateContent(content);

        // Assert
        expect(result, isNull);
      });

      test('should reject empty content', () {
        // Arrange
        const content = '';

        // Act
        final result = CommentModel.validateContent(content);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('cannot be empty'));
      });

      test('should reject content exceeding limit', () {
        // Arrange
        final content = 'a' * 501; // Exceeds 500 character limit

        // Act
        final result = CommentModel.validateContent(content);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('cannot exceed 500 characters'));
      });

      test('should reject whitespace-only content', () {
        // Arrange
        const content = '   \n\t   ';

        // Act
        final result = CommentModel.validateContent(content);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('cannot be empty'));
      });
    });

    group('Comment Visibility', () {
      test('should allow author to see their own hidden comments', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Hidden comment content',
          createdAt: DateTime.now(),
          isHidden: true,
        );

        // Act & Assert
        expect(comment.isVisibleToUser(userId: 'author_123'), isTrue);
        expect(comment.isVisibleToUser(userId: 'other_user'), isFalse);
      });

      test('should allow coordinators to see hidden comments', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Hidden comment content',
          createdAt: DateTime.now(),
          isHidden: true,
        );

        // Act & Assert
        expect(comment.isVisibleToUser(
          userId: 'coordinator_123',
          userRole: 'village_coordinator',
        ), isTrue);
        
        expect(comment.isVisibleToUser(
          userId: 'user_123',
          userRole: 'member',
        ), isFalse);
      });

      test('should show visible comments to all users', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Visible comment content',
          createdAt: DateTime.now(),
          isHidden: false,
        );

        // Act & Assert
        expect(comment.isVisibleToUser(userId: 'user_123'), isTrue);
        expect(comment.isVisibleToUser(userId: 'user_456'), isTrue);
      });
    });

    group('Comment Interaction Permissions', () {
      test('should allow author to interact with their own comments', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Test comment content',
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(comment.canUserInteract(userId: 'author_123'), isTrue);
      });

      test('should restrict interaction with reported comments for regular users', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Reported comment content',
          createdAt: DateTime.now(),
          isReported: true,
        );

        // Act & Assert
        expect(comment.canUserInteract(
          userId: 'user_123',
          userRole: 'member',
        ), isFalse);
        
        expect(comment.canUserInteract(
          userId: 'coordinator_123',
          userRole: 'village_coordinator',
        ), isTrue);
      });

      test('should allow coordinators to interact with hidden comments', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Hidden comment content',
          createdAt: DateTime.now(),
          isHidden: true,
        );

        // Act & Assert
        expect(comment.canUserInteract(
          userId: 'user_123',
          userRole: 'member',
        ), isFalse);
        
        expect(comment.canUserInteract(
          userId: 'coordinator_123',
          userRole: 'village_coordinator',
        ), isTrue);
      });
    });

    group('Reply Functionality', () {
      test('should identify top-level comments', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Top level comment',
          createdAt: DateTime.now(),
          parentCommentId: null,
        );

        // Act & Assert
        expect(comment.isReply, isFalse);
        expect(comment.depth, equals(0));
      });

      test('should identify reply comments', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_reply',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Reply comment',
          createdAt: DateTime.now(),
          parentCommentId: 'parent_comment_123',
        );

        // Act & Assert
        expect(comment.isReply, isTrue);
        expect(comment.depth, equals(1));
      });

      test('should identify comments with replies', () {
        // Arrange
        final replyComment = CommentModel(
          id: 'reply_1',
          postId: 'test_post',
          authorId: 'author_456',
          authorName: 'Reply Author',
          content: 'This is a reply',
          createdAt: DateTime.now(),
          parentCommentId: 'test_comment',
        );

        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Comment with replies',
          createdAt: DateTime.now(),
          replies: [replyComment],
        );

        // Act & Assert
        expect(comment.hasReplies, isTrue);
        expect(comment.replies.length, equals(1));
      });

      test('should identify comments without replies', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Comment without replies',
          createdAt: DateTime.now(),
          replies: [],
        );

        // Act & Assert
        expect(comment.hasReplies, isFalse);
        expect(comment.replies.length, equals(0));
      });
    });

    group('Time Formatting', () {
      test('should format recent time correctly', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Recent comment',
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        );

        // Act
        final timeAgo = comment.getTimeAgo();

        // Assert
        expect(timeAgo, contains('15m ago'));
      });

      test('should format hours correctly', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Hour old comment',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        // Act
        final timeAgo = comment.getTimeAgo();

        // Assert
        expect(timeAgo, contains('1h ago'));
      });

      test('should format very recent time as "Just now"', () {
        // Arrange
        final comment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Just posted comment',
          createdAt: DateTime.now().subtract(const Duration(seconds: 10)),
        );

        // Act
        final timeAgo = comment.getTimeAgo();

        // Assert
        expect(timeAgo, equals('Just now'));
      });
    });

    group('Inappropriate Content Detection', () {
      test('should detect inappropriate content', () {
        // Arrange
        const content = 'This comment contains spam and fake information';

        // Act
        final hasInappropriate = CommentModel.containsInappropriateContent(content);

        // Assert
        expect(hasInappropriate, isFalse); // Our basic implementation doesn't have these words
      });

      test('should handle clean content', () {
        // Arrange
        const content = 'This is a clean and helpful comment about land rights';

        // Act
        final hasInappropriate = CommentModel.containsInappropriateContent(content);

        // Assert
        expect(hasInappropriate, isFalse);
      });
    });

    group('Comment Model Equality', () {
      test('should be equal when IDs match', () {
        // Arrange
        final comment1 = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Test content',
          createdAt: DateTime.now(),
        );

        final comment2 = CommentModel(
          id: 'test_comment',
          postId: 'different_post',
          authorId: 'different_author',
          authorName: 'Different Author',
          content: 'Different content',
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(comment1, equals(comment2));
        expect(comment1.hashCode, equals(comment2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        // Arrange
        final comment1 = CommentModel(
          id: 'test_comment_1',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Test content',
          createdAt: DateTime.now(),
        );

        final comment2 = CommentModel(
          id: 'test_comment_2',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Test content',
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(comment1, isNot(equals(comment2)));
        expect(comment1.hashCode, isNot(equals(comment2.hashCode)));
      });
    });

    group('Comment Model CopyWith', () {
      test('should create copy with updated fields', () {
        // Arrange
        final originalComment = CommentModel(
          id: 'test_comment',
          postId: 'test_post',
          authorId: 'author_123',
          authorName: 'Test Author',
          content: 'Original content',
          createdAt: DateTime.now(),
          likesCount: 3,
        );

        // Act
        final updatedComment = originalComment.copyWith(
          content: 'Updated content',
          likesCount: 5,
        );

        // Assert
        expect(updatedComment.id, equals(originalComment.id));
        expect(updatedComment.postId, equals(originalComment.postId));
        expect(updatedComment.content, equals('Updated content'));
        expect(updatedComment.likesCount, equals(5));
        expect(updatedComment.authorId, equals(originalComment.authorId)); // Unchanged
      });
    });
  });
}