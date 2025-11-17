// Share Service for TALOWA
// Handles post sharing functionality

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../auth_service.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _sharesCollection = 'post_shares';
  final String _postsCollection = 'posts';

  /// Share a post (increment share count and record share)
  Future<void> sharePost(
    String postId, {
    String shareType = 'general',
    String? platform,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(
          _firestore.collection(_postsCollection).doc(postId),
        );

        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        // Update share count
        transaction.update(_firestore.collection(_postsCollection).doc(postId), {
          'sharesCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Record share activity
        final shareId = '${postId}_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';
        transaction.set(_firestore.collection(_sharesCollection).doc(shareId), {
          'postId': postId,
          'userId': currentUser.uid,
          'shareType': shareType,
          'platform': platform,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('✅ Post shared successfully: $postId');
    } catch (e) {
      debugPrint('❌ Error sharing post: $e');
      rethrow;
    }
  }

  /// Get share link for a post
  String getShareLink(String postId) {
    // TODO: Replace with your actual app domain
    return 'https://talowa.web.app/post/$postId';
  }

  /// Copy post link to clipboard
  Future<void> copyPostLink(String postId) async {
    try {
      final link = getShareLink(postId);
      await Clipboard.setData(ClipboardData(text: link));
      debugPrint('✅ Post link copied to clipboard');
    } catch (e) {
      debugPrint('❌ Error copying link: $e');
      rethrow;
    }
  }

  /// Share via email (opens email client)
  Future<void> shareViaEmail(String postId, String postContent) async {
    try {
      final link = getShareLink(postId);
      final subject = 'Check out this post on TALOWA';
      final body = '$postContent\n\nView full post: $link';
      
      // This would typically use url_launcher package
      // For now, just copy to clipboard
      await Clipboard.setData(ClipboardData(
        text: 'Subject: $subject\n\n$body',
      ));
      
      debugPrint('✅ Email content copied to clipboard');
    } catch (e) {
      debugPrint('❌ Error sharing via email: $e');
      rethrow;
    }
  }

  /// Share to native platforms (WhatsApp, Instagram, Facebook, etc.)
  Future<void> shareToNativePlatforms({
    required String postId,
    required String postContent,
    String? authorName,
  }) async {
    try {
      final link = getShareLink(postId);
      final shareText = authorName != null
          ? '$authorName shared: $postContent\n\nView on TALOWA: $link'
          : '$postContent\n\nView on TALOWA: $link';

      if (kIsWeb) {
        // On web, copy to clipboard as fallback since Web Share API is limited
        await Clipboard.setData(ClipboardData(text: shareText));
        debugPrint('✅ Share content copied to clipboard (Web)');
        // Still try to use Web Share API if available
        try {
          await Share.share(shareText, subject: 'Check out this post on TALOWA');
        } catch (e) {
          debugPrint('ℹ️ Web Share API not available, content copied to clipboard');
        }
      } else {
        // On mobile/desktop, use native share sheet
        final result = await Share.share(
          shareText,
          subject: 'Check out this post on TALOWA',
        );

        // Track the share
        if (result.status == ShareResultStatus.success) {
          await sharePost(postId, shareType: 'native', platform: 'system_share');
          debugPrint('✅ Post shared via native share sheet');
        } else if (result.status == ShareResultStatus.dismissed) {
          debugPrint('ℹ️ Share dismissed by user');
        }
      }
    } catch (e) {
      debugPrint('❌ Error sharing to native platforms: $e');
      // Fallback: copy to clipboard
      try {
        final link = getShareLink(postId);
        final shareText = authorName != null
            ? '$authorName shared: $postContent\n\nView on TALOWA: $link'
            : '$postContent\n\nView on TALOWA: $link';
        await Clipboard.setData(ClipboardData(text: shareText));
        debugPrint('✅ Fallback: Content copied to clipboard');
      } catch (clipboardError) {
        debugPrint('❌ Clipboard fallback also failed: $clipboardError');
      }
      rethrow;
    }
  }

  /// Share with specific text and optional files
  Future<void> shareWithFiles({
    required String postId,
    required String text,
    List<String>? imageUrls,
  }) async {
    try {
      // For now, just share text
      // In future, can download images and share them
      await Share.share(text);
      
      await sharePost(postId, shareType: 'native_with_media', platform: 'system_share');
      debugPrint('✅ Post shared with media');
    } catch (e) {
      debugPrint('❌ Error sharing with files: $e');
      rethrow;
    }
  }

  /// Get WhatsApp share URL (works on web and mobile)
  String getWhatsAppShareUrl(String text) {
    final encodedText = Uri.encodeComponent(text);
    return 'https://wa.me/?text=$encodedText';
  }

  /// Get Facebook share URL (works on web)
  String getFacebookShareUrl(String url) {
    return 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}';
  }

  /// Get Twitter share URL (works on web)
  String getTwitterShareUrl(String text, String url) {
    return 'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(url)}';
  }

  /// Get LinkedIn share URL (works on web)
  String getLinkedInShareUrl(String url) {
    return 'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(url)}';
  }

  /// Get Telegram share URL (works on web)
  String getTelegramShareUrl(String text, String url) {
    return 'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent(text)}';
  }

  /// Get share statistics for a post
  Future<Map<String, dynamic>> getShareStats(String postId) async {
    try {
      final snapshot = await _firestore
          .collection(_sharesCollection)
          .where('postId', isEqualTo: postId)
          .get();

      final shares = snapshot.docs;
      final totalShares = shares.length;

      // Count shares by platform
      final platformCounts = <String, int>{};
      for (final doc in shares) {
        final platform = doc.data()['platform'] as String? ?? 'unknown';
        platformCounts[platform] = (platformCounts[platform] ?? 0) + 1;
      }

      return {
        'totalShares': totalShares,
        'platformBreakdown': platformCounts,
      };
    } catch (e) {
      debugPrint('❌ Error getting share stats: $e');
      return {
        'totalShares': 0,
        'platformBreakdown': <String, int>{},
      };
    }
  }

  /// Check if current user has shared a post
  Future<bool> hasUserShared(String postId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _firestore
          .collection(_sharesCollection)
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking share status: $e');
      return false;
    }
  }
}
