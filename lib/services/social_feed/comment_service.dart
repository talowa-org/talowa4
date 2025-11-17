// Comment Service for TALOWA
// Handles all comment-related operations for posts

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/comment_model.dart';
import '../auth_service.dart';

class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _commentsCollection = 'post_comments';
  final String _postsCollection = 'posts';

  /// Add a comment to a post
  Future<String> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Validate comment content
      final validation = CommentModel.validateContent(content);
      if (validation != null) {
        throw Exception(validation);
      }

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final commentId = _firestore.collection(_commentsCollection).doc().id;

      final comment = CommentModel(
        id: commentId,
        postId: postId,
        authorId: currentUser.uid,
        authorName: userData['fullName'] ?? 'Unknown User',
        authorRole: userData['role'],
        content: content,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
      );

      // Use batch write for consistency
      final batch = _firestore.batch();
      
      // Add comment
      batch.set(
        _firestore.collection(_commentsCollection).doc(commentId),
        comment.toFirestore(),
      );
      
      // Update post comment count
      batch.update(_firestore.collection(_postsCollection).doc(postId), {
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      debugPrint('✅ Comment added successfully: $commentId');
      return commentId;
    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a post
  Future<List<CommentModel>> getComments(
    String postId, {
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_commentsCollection)
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      final comments = snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();

      debugPrint('✅ Retrieved ${comments.length} comments for post $postId');
      return comments;
    } catch (e) {
      debugPrint('❌ Error getting comments: $e');
      return [];
    }
  }

  /// Get replies to a comment
  Future<List<CommentModel>> getReplies(
    String commentId, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_commentsCollection)
          .where('parentCommentId', isEqualTo: commentId)
          .orderBy('createdAt', descending: false)
          .limit(limit)
          .get();

      final replies = snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();

      debugPrint('✅ Retrieved ${replies.length} replies for comment $commentId');
      return replies;
    } catch (e) {
      debugPrint('❌ Error getting replies: $e');
      return [];
    }
  }

  /// Update a comment
  Future<void> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Validate comment content
      final validation = CommentModel.validateContent(content);
      if (validation != null) {
        throw Exception(validation);
      }

      // Get existing comment
      final commentDoc = await _firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data()!;
      if (commentData['authorId'] != currentUser.uid) {
        throw Exception('Not authorized to update this comment');
      }

      // Update comment
      await _firestore.collection(_commentsCollection).doc(commentId).update({
        'content': content,
        'updatedAt': FieldValue.serverTimestamp(),
        'isEdited': true,
      });

      debugPrint('✅ Comment updated successfully: $commentId');
    } catch (e) {
      debugPrint('❌ Error updating comment: $e');
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get comment
      final commentDoc = await _firestore
          .collection(_commentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data()!;
      if (commentData['authorId'] != currentUser.uid) {
        throw Exception('Not authorized to delete this comment');
      }

      final postId = commentData['postId'];

      // Use batch write for consistency
      final batch = _firestore.batch();

      // Delete comment
      batch.delete(_firestore.collection(_commentsCollection).doc(commentId));

      // Update post comment count
      batch.update(_firestore.collection(_postsCollection).doc(postId), {
        'commentsCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      debugPrint('✅ Comment deleted successfully: $commentId');
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      rethrow;
    }
  }

  /// Like a comment
  Future<void> toggleCommentLike(String commentId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final likeId = '${commentId}_${currentUser.uid}';
      final likesCollection = 'comment_likes';

      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(
          _firestore.collection(likesCollection).doc(likeId),
        );
        final commentDoc = await transaction.get(
          _firestore.collection(_commentsCollection).doc(commentId),
        );

        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        if (likeDoc.exists) {
          // Unlike
          transaction.delete(_firestore.collection(likesCollection).doc(likeId));
          transaction.update(
            _firestore.collection(_commentsCollection).doc(commentId),
            {'likesCount': FieldValue.increment(-1)},
          );
        } else {
          // Like
          transaction.set(_firestore.collection(likesCollection).doc(likeId), {
            'commentId': commentId,
            'userId': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(
            _firestore.collection(_commentsCollection).doc(commentId),
            {'likesCount': FieldValue.increment(1)},
          );
        }
      });

      debugPrint('✅ Comment like toggled successfully');
    } catch (e) {
      debugPrint('❌ Error toggling comment like: $e');
      rethrow;
    }
  }

  /// Stream comments for real-time updates
  Stream<List<CommentModel>> streamComments(String postId) {
    return _firestore
        .collection(_commentsCollection)
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromFirestore(doc))
            .toList());
  }
}
