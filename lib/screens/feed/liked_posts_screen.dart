// Liked Posts Screen - Shows all posts liked by the current user
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../../widgets/feed/enhanced_post_widget.dart';
import '../../widgets/feed/feed_skeleton_loader.dart';
import '../../services/auth/auth_service.dart';

class LikedPostsScreen extends StatefulWidget {
  const LikedPostsScreen({super.key});

  @override
  State<LikedPostsScreen> createState() => _LikedPostsScreenState();
}

class _LikedPostsScreenState extends State<LikedPostsScreen> {
  final List<InstagramPostModel> _likedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  Future<void> _loadLikedPosts() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all liked post IDs
      final likesSnapshot = await FirebaseFirestore.instance
          .collection('post_likes')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final postIds = likesSnapshot.docs
          .map((doc) => doc.data()['postId'] as String)
          .toList();

      if (postIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch posts in batches (Firestore 'in' query limit is 10)
      final List<InstagramPostModel> posts = [];
      for (int i = 0; i < postIds.length; i += 10) {
        final batch = postIds.skip(i).take(10).toList();
        final postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where(FieldPath.documentId, whereIn: batch)
            .where('isDeleted', isEqualTo: false)
            .get();

        posts.addAll(
          postsSnapshot.docs.map((doc) => InstagramPostModel.fromFirestore(doc)),
        );
      }

      // Sort by like date (maintain order from likes collection)
      final orderedPosts = <InstagramPostModel>[];
      for (final postId in postIds) {
        final post = posts.firstWhere(
          (p) => p.id == postId,
          orElse: () => InstagramPostModel.empty(),
        );
        if (post.id.isNotEmpty) {
          orderedPosts.add(post.copyWith(isLikedByCurrentUser: true));
        }
      }

      setState(() {
        _likedPosts.clear();
        _likedPosts.addAll(orderedPosts);
      });
    } catch (e) {
      debugPrint('❌ Error loading liked posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load liked posts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(InstagramPostModel post) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      final likeId = '${post.id}_${currentUser.uid}';
      final likeRef = FirebaseFirestore.instance
          .collection('post_likes')
          .doc(likeId);

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final likeDoc = await transaction.get(likeRef);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) return;

        if (likeDoc.exists) {
          // Unlike
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likesCount': FieldValue.increment(-1),
          });
        } else {
          // Like
          transaction.set(likeRef, {
            'postId': post.id,
            'userId': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {
            'likesCount': FieldValue.increment(1),
          });
        }
      });

      // Remove from list if unliked
      setState(() {
        _likedPosts.removeWhere((p) => p.id == post.id);
      });
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Liked Posts',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const FeedSkeletonLoader();
    }

    if (_likedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No liked posts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Posts you like will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _likedPosts.length,
      itemBuilder: (context, index) {
        final post = _likedPosts[index];
        return EnhancedPostWidget(
          key: ValueKey('liked_post_${post.id}'),
          post: post,
          onLike: () => _toggleLike(post),
          onComment: () => _openComments(post),
          onShare: () => _sharePost(post),
          onBookmark: () => _toggleBookmark(post),
          onViewProfile: () => _viewProfile(post.authorId),
        );
      },
    );
  }

  Future<void> _toggleBookmark(InstagramPostModel post) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      final bookmarkId = '${post.id}_${currentUser.uid}';
      final bookmarkRef = FirebaseFirestore.instance
          .collection('post_bookmarks')
          .doc(bookmarkId);

      final bookmarkDoc = await bookmarkRef.get();

      if (bookmarkDoc.exists) {
        await bookmarkRef.delete();
      } else {
        await bookmarkRef.set({
          'postId': post.id,
          'userId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bookmarkDoc.exists ? 'Removed from bookmarks' : 'Added to bookmarks',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error toggling bookmark: $e');
    }
  }

  void _openComments(InstagramPostModel post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comments feature coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _sharePost(InstagramPostModel post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _viewProfile(String userId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View profile: $userId'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
