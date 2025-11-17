// Bookmarked Posts Screen - Shows all posts bookmarked by the current user
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../../widgets/feed/enhanced_post_widget.dart';
import '../../widgets/feed/feed_skeleton_loader.dart';
import '../../services/auth/auth_service.dart';

class BookmarkedPostsScreen extends StatefulWidget {
  const BookmarkedPostsScreen({super.key});

  @override
  State<BookmarkedPostsScreen> createState() => _BookmarkedPostsScreenState();
}

class _BookmarkedPostsScreenState extends State<BookmarkedPostsScreen> {
  final List<InstagramPostModel> _bookmarkedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarkedPosts();
  }

  Future<void> _loadBookmarkedPosts() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all bookmarked post IDs
      final bookmarksSnapshot = await FirebaseFirestore.instance
          .collection('post_bookmarks')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final postIds = bookmarksSnapshot.docs
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

      // Check which posts are liked by current user
      final likedPostIds = <String>{};
      final likesSnapshot = await FirebaseFirestore.instance
          .collection('post_likes')
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      
      for (final doc in likesSnapshot.docs) {
        likedPostIds.add(doc.data()['postId'] as String);
      }

      // Sort by bookmark date (maintain order from bookmarks collection)
      final orderedPosts = <InstagramPostModel>[];
      for (final postId in postIds) {
        final post = posts.firstWhere(
          (p) => p.id == postId,
          orElse: () => InstagramPostModel.empty(),
        );
        if (post.id.isNotEmpty) {
          orderedPosts.add(post.copyWith(
            isBookmarkedByCurrentUser: true,
            isLikedByCurrentUser: likedPostIds.contains(post.id),
          ));
        }
      }

      setState(() {
        _bookmarkedPosts.clear();
        _bookmarkedPosts.addAll(orderedPosts);
      });
    } catch (e) {
      debugPrint('❌ Error loading bookmarked posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bookmarked posts: $e'),
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

      // Update local state
      setState(() {
        final index = _bookmarkedPosts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _bookmarkedPosts[index] = _bookmarkedPosts[index].copyWith(
            isLikedByCurrentUser: !post.isLikedByCurrentUser,
            likesCount: post.isLikedByCurrentUser
                ? post.likesCount - 1
                : post.likesCount + 1,
          );
        }
      });
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
    }
  }

  Future<void> _toggleBookmark(InstagramPostModel post) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      final bookmarkId = '${post.id}_${currentUser.uid}';
      final bookmarkRef = FirebaseFirestore.instance
          .collection('post_bookmarks')
          .doc(bookmarkId);

      await bookmarkRef.delete();

      // Remove from list
      setState(() {
        _bookmarkedPosts.removeWhere((p) => p.id == post.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from bookmarks'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error removing bookmark: $e');
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
          'Bookmarked Posts',
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

    if (_bookmarkedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No bookmarked posts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Posts you bookmark will appear here',
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
      itemCount: _bookmarkedPosts.length,
      itemBuilder: (context, index) {
        final post = _bookmarkedPosts[index];
        return EnhancedPostWidget(
          key: ValueKey('bookmarked_post_${post.id}'),
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
