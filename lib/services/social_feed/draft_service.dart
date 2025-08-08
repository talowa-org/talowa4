// Draft Service - Handle post drafts
// Part of Task 9: Build PostCreationScreen for coordinators

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/social_feed/index.dart';

class DraftService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _draftsCollection = _firestore.collection('drafts');
  
  /// Save a post draft
  static Future<String> saveDraft({
    required String authorId,
    String? title,
    required String content,
    List<String>? imageUrls,
    List<String>? documentUrls,
    List<String>? hashtags,
    PostCategory? category,
    PostPriority? priority,
    GeographicTargeting? targeting,
    PostVisibility? visibility,
    bool? isPinned,
    bool? allowComments,
    bool? allowShares,
    String? draftId, // For updating existing draft
  }) async {
    try {
      debugPrint('DraftService: Saving draft for author $authorId');
      
      final draftData = {
        'authorId': authorId,
        'title': title,
        'content': content,
        'imageUrls': imageUrls ?? [],
        'documentUrls': documentUrls ?? [],
        'hashtags': hashtags ?? [],
        'category': category?.toString().split('.').last,
        'priority': priority?.toString().split('.').last,
        'targeting': targeting?.toMap(),
        'visibility': visibility?.toString().split('.').last,
        'isPinned': isPinned ?? false,
        'allowComments': allowComments ?? true,
        'allowShares': allowShares ?? true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (draftId != null) {
        // Update existing draft
        await _draftsCollection.doc(draftId).update(draftData);
        debugPrint('DraftService: Draft updated successfully');
        return draftId;
      } else {
        // Create new draft
        draftData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await _draftsCollection.add(draftData);
        debugPrint('DraftService: Draft saved with ID: ${docRef.id}');
        return docRef.id;
      }
    } catch (e) {
      debugPrint('DraftService: Error saving draft: $e');
      rethrow;
    }
  }
  
  /// Get all drafts for a user
  static Future<List<DraftModel>> getUserDrafts(String userId) async {
    try {
      debugPrint('DraftService: Getting drafts for user $userId');
      
      final querySnapshot = await _draftsCollection
          .where('authorId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();
      
      final drafts = querySnapshot.docs
          .map((doc) => DraftModel.fromFirestore(doc))
          .toList();
      
      debugPrint('DraftService: Found ${drafts.length} drafts');
      return drafts;
    } catch (e) {
      debugPrint('DraftService: Error getting drafts: $e');
      rethrow;
    }
  }
  
  /// Get a specific draft
  static Future<DraftModel?> getDraft(String draftId) async {
    try {
      debugPrint('DraftService: Getting draft $draftId');
      
      final doc = await _draftsCollection.doc(draftId).get();
      
      if (!doc.exists) {
        debugPrint('DraftService: Draft not found');
        return null;
      }
      
      return DraftModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('DraftService: Error getting draft: $e');
      rethrow;
    }
  }
  
  /// Delete a draft
  static Future<void> deleteDraft(String draftId) async {
    try {
      debugPrint('DraftService: Deleting draft $draftId');
      
      await _draftsCollection.doc(draftId).delete();
      
      debugPrint('DraftService: Draft deleted successfully');
    } catch (e) {
      debugPrint('DraftService: Error deleting draft: $e');
      rethrow;
    }
  }
  
  /// Delete all drafts for a user
  static Future<void> deleteUserDrafts(String userId) async {
    try {
      debugPrint('DraftService: Deleting all drafts for user $userId');
      
      final querySnapshot = await _draftsCollection
          .where('authorId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      debugPrint('DraftService: All user drafts deleted successfully');
    } catch (e) {
      debugPrint('DraftService: Error deleting user drafts: $e');
      rethrow;
    }
  }
}

/// Draft model for storing post drafts
class DraftModel {
  final String id;
  final String authorId;
  final String? title;
  final String content;
  final List<String> imageUrls;
  final List<String> documentUrls;
  final List<String> hashtags;
  final PostCategory? category;
  final PostPriority? priority;
  final GeographicTargeting? targeting;
  final PostVisibility? visibility;
  final bool isPinned;
  final bool allowComments;
  final bool allowShares;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const DraftModel({
    required this.id,
    required this.authorId,
    this.title,
    required this.content,
    this.imageUrls = const [],
    this.documentUrls = const [],
    this.hashtags = const [],
    this.category,
    this.priority,
    this.targeting,
    this.visibility,
    this.isPinned = false,
    this.allowComments = true,
    this.allowShares = true,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Create DraftModel from Firestore document
  factory DraftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DraftModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      title: data['title'],
      content: data['content'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      category: data['category'] != null
          ? PostCategory.values.firstWhere(
              (e) => e.toString().split('.').last == data['category'],
              orElse: () => PostCategory.generalDiscussion,
            )
          : null,
      priority: data['priority'] != null
          ? PostPriority.values.firstWhere(
              (e) => e.toString().split('.').last == data['priority'],
              orElse: () => PostPriority.normal,
            )
          : null,
      targeting: data['targeting'] != null
          ? GeographicTargeting.fromMap(data['targeting'])
          : null,
      visibility: data['visibility'] != null
          ? PostVisibility.values.firstWhere(
              (e) => e.toString().split('.').last == data['visibility'],
              orElse: () => PostVisibility.public,
            )
          : null,
      isPinned: data['isPinned'] ?? false,
      allowComments: data['allowComments'] ?? true,
      allowShares: data['allowShares'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
  
  /// Convert to PostModel for preview
  PostModel toPostModel({
    required String authorName,
    String? authorRole,
    String? authorAvatarUrl,
  }) {
    return PostModel(
      id: 'draft_$id',
      authorId: authorId,
      authorName: authorName,
      authorRole: authorRole,
      authorAvatarUrl: authorAvatarUrl,
      title: title,
      content: content,
      imageUrls: imageUrls,
      documentUrls: documentUrls,
      hashtags: hashtags,
      category: category ?? PostCategory.generalDiscussion,
      priority: priority ?? PostPriority.normal,
      targeting: targeting,
      visibility: visibility ?? PostVisibility.public,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPinned: isPinned,
      allowComments: allowComments,
      allowShares: allowShares,
    );
  }
  
  /// Get formatted time ago string
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}