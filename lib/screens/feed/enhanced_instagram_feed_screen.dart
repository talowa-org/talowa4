// Enhanced Instagram Feed Screen with Full Media Support
// Complete Instagram-like experience with images, videos, stories, and infinite scroll
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../../widgets/feed/enhanced_post_widget.dart';
import '../../widgets/feed/feed_skeleton_loader.dart';
import '../post_creation/enhanced_post_creation_screen.dart';
import '../../services/auth/auth_service.dart';

class EnhancedInstagramFeedScreen extends StatefulWidget {
  const EnhancedInstagramFeedScreen({super.key});

  @override
  State<EnhancedInstagramFeedScreen> createState() => _EnhancedInstagramFeedScreenState();
}

class _EnhancedInstagramFeedScreenState extends State<EnhancedInstagramFeedScreen>
    with AutomaticKeepAliveClientMixin {
  
  final ScrollController _scrollController = ScrollController();
  final List<InstagramPostModel> _posts = [];
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  static const int _postsPerPage = 10;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialFeed();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore) {
          _loadMorePosts();
        }
      }
    });
  }

  Future<void> _loadInitialFeed() async {
    setState(() {
      _isLoading = true;
      _posts.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    try {
      final query = FirebaseFirestore.instance
          .collection('posts')
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(_postsPerPage);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        
        final posts = snapshot.docs
            .map((doc) => InstagramPostModel.fromFirestore(doc))
            .toList();

        // Enrich with user-specific data
        final enrichedPosts = await _enrichPostsWithUserData(posts);

        setState(() {
          _posts.addAll(enrichedPosts);
          _hasMore = snapshot.docs.length == _postsPerPage;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading feed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load feed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final query = FirebaseFirestore.instance
          .collection('posts')
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        
        final posts = snapshot.docs
            .map((doc) => InstagramPostModel.fromFirestore(doc))
            .toList();

        final enrichedPosts = await _enrichPostsWithUserData(posts);

        setState(() {
          _posts.addAll(enrichedPosts);
          _hasMore = snapshot.docs.length == _postsPerPage;
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading more posts: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<List<InstagramPostModel>> _enrichPostsWithUserData(
    List<InstagramPostModel> posts,
  ) async {
    final currentUserId = AuthService.currentUser?.uid;
    if (currentUserId == null) return posts;

    try {
      final enrichedPosts = <InstagramPostModel>[];

      for (final post in posts) {
        // Check if user liked this post
        final likeDoc = await FirebaseFirestore.instance
            .collection('post_likes')
            .doc('${post.id}_$currentUserId')
            .get();

        // Check if user bookmarked this post
        final bookmarkDoc = await FirebaseFirestore.instance
            .collection('post_bookmarks')
            .doc('${post.id}_$currentUserId')
            .get();

        enrichedPosts.add(post.copyWith(
          isLikedByCurrentUser: likeDoc.exists,
          isBookmarkedByCurrentUser: bookmarkDoc.exists,
        ));
      }

      return enrichedPosts;
    } catch (e) {
      debugPrint('❌ Error enriching posts: $e');
      return posts;
    }
  }

  Future<void> _refreshFeed() async {
    HapticFeedback.lightImpact();
    await _loadInitialFeed();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'TALOWA',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // TODO: Implement notifications
          },
          icon: const Icon(Icons.favorite_border, color: Colors.black),
          tooltip: 'Activity',
        ),
        IconButton(
          onPressed: () {
            // TODO: Implement direct messages
          },
          icon: const Icon(Icons.send_outlined, color: Colors.black),
          tooltip: 'Messages',
        ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const FeedSkeletonLoader();
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: AppTheme.talowaGreen,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _posts.length) {
            final post = _posts[index];
            return EnhancedPostWidget(
              key: ValueKey('post_${post.id}'),
              post: post,
              onLike: () => _toggleLike(post),
              onComment: () => _openComments(post),
              onShare: () => _sharePost(post),
              onBookmark: () => _toggleBookmark(post),
              onViewProfile: () => _viewProfile(post.authorId),
            );
          } else {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.talowaGreen,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.talowaGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Post'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _createPost,
      backgroundColor: AppTheme.talowaGreen,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  // Event handlers
  void _createPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnhancedPostCreationScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _refreshFeed();
      }
    });
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
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = _posts[index].copyWith(
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

      // Update local state
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = _posts[index].copyWith(
            isBookmarkedByCurrentUser: !post.isBookmarkedByCurrentUser,
          );
        }
      });

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
    // TODO: Navigate to comments screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comments feature coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _sharePost(InstagramPostModel post) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _viewProfile(String userId) {
    // TODO: Navigate to user profile
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View profile: $userId'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
