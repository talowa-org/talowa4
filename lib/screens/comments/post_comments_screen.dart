// Post Comments Screen - Task 7: Build post engagement interface
// Comprehensive comment display and input interface

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/index.dart';
import '../../widgets/comments/comment_widget.dart';
import '../../widgets/comments/comment_input_widget.dart';
import '../../widgets/common/loading_widget.dart';

class PostCommentsScreen extends StatefulWidget {
  final PostModel post;

  const PostCommentsScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends State<PostCommentsScreen> 
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  
  // State management
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Data
  List<CommentModel> _comments = [];
  bool _hasMoreComments = true;
  
  // Reply state
  CommentModel? _replyingTo;
  
  // Animation controllers
  late AnimationController _inputAnimationController;
  late Animation<double> _inputAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _inputAnimationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _inputAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _inputAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _inputAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Post preview
          _buildPostPreview(),
          const Divider(height: 1),
          
          // Comments list
          Expanded(child: _buildCommentsList()),
          
          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comments'),
          Text(
            '${widget.post.commentsCount} comments',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.talowaGreen,
      foregroundColor: Colors.white,
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'sort_newest',
              child: ListTile(
                leading: Icon(Icons.sort),
                title: Text('Sort by Newest'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'sort_oldest',
              child: ListTile(
                leading: Icon(Icons.sort),
                title: Text('Sort by Oldest'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'sort_popular',
              child: ListTile(
                leading: Icon(Icons.trending_up),
                title: Text('Sort by Popular'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostPreview() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.talowaGreen,
            backgroundImage: widget.post.authorAvatarUrl != null
                ? NetworkImage(widget.post.authorAvatarUrl!)
                : null,
            child: widget.post.authorAvatarUrl == null
                ? Text(
                    widget.post.authorName.isNotEmpty
                        ? widget.post.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          
          // Post content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.post.authorName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    Text(
                      widget.post.getTimeAgo(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.post.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading && _comments.isEmpty) {
      return const LoadingWidget(message: 'Loading comments...');
    }

    if (_hasError && _comments.isEmpty) {
      return CustomErrorWidget(
        message: _errorMessage ?? 'Failed to load comments',
        onRetry: _loadComments,
      );
    }

    if (_comments.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshComments,
      color: AppTheme.talowaGreen,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
        itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _comments.length) {
            return const Padding(
              padding: EdgeInsets.all(AppTheme.spacingMedium),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final comment = _comments[index];
          return CommentWidget(
            comment: comment,
            onLike: () => _likeComment(comment),
            onReply: () => _replyToComment(comment),
            onUserTap: () => _openUserProfile(comment.authorId),
            onReport: () => _reportComment(comment),
          );
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
            Icons.comment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            'No comments yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            'Be the first to comment on this post',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          // Reply indicator
          if (_replyingTo != null) _buildReplyIndicator(),
          
          // Comment input
          CommentInputWidget(
            controller: _commentController,
            focusNode: _commentFocusNode,
            isSubmitting: _isSubmitting,
            onSubmit: _submitComment,
            onCancel: _replyingTo != null ? _cancelReply : null,
            hintText: _replyingTo != null 
                ? 'Reply to ${_replyingTo!.authorName}...'
                : 'Add a comment...',
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      color: Colors.grey[100],
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: Colors.grey[600]),
          const SizedBox(width: AppTheme.spacingSmall),
          Text(
            'Replying to ${_replyingTo!.authorName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _cancelReply,
            child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Data loading methods
  Future<void> _loadComments() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final comments = await FeedService.getPostComments(
        widget.post.id,
        limit: 20,
      );
      
      setState(() {
        _comments = comments;
        _hasMoreComments = comments.length >= 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadComments,
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshComments() async {
    setState(() {
      _comments.clear();
      _hasMoreComments = true;
    });
    await _loadComments();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreComments();
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreComments) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreComments = await FeedService.getPostComments(
        widget.post.id,
        limit: 20,
        // TODO: Add lastDocument parameter for pagination
      );
      
      setState(() {
        _comments.addAll(moreComments);
        _hasMoreComments = moreComments.length >= 20;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more comments: ${e.toString()}')),
        );
      }
    }
  }

  // Action methods
  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final comment = CommentModel(
        id: '', // Will be set by Firestore
        postId: widget.post.id,
        authorId: 'current_user_id', // TODO: Get actual user ID
        authorName: 'Current User', // TODO: Get actual user name
        content: content,
        createdAt: DateTime.now(),
        parentCommentId: _replyingTo?.id,
      );

      final createdComment = await FeedService.addComment(widget.post.id, comment);
      
      setState(() {
        if (_replyingTo != null) {
          // Add as reply to existing comment
          final parentIndex = _comments.indexWhere((c) => c.id == _replyingTo!.id);
          if (parentIndex != -1) {
            final updatedParent = _comments[parentIndex].copyWith(
              replies: [..._comments[parentIndex].replies, createdComment],
            );
            _comments[parentIndex] = updatedParent;
          }
        } else {
          // Add as new top-level comment
          _comments.insert(0, createdComment);
        }
        
        _commentController.clear();
        _replyingTo = null;
        _isSubmitting = false;
      });

      // Provide haptic feedback
      HapticFeedback.lightImpact();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _likeComment(CommentModel comment) async {
    try {
      // Optimistic update
      final updatedComment = comment.copyWith(
        isLikedByCurrentUser: !comment.isLikedByCurrentUser,
        likesCount: comment.isLikedByCurrentUser 
            ? comment.likesCount - 1 
            : comment.likesCount + 1,
      );
      
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _comments[index] = updatedComment;
        }
      });

      // Make API call
      // TODO: Implement comment like/unlike in FeedService
      
      // Provide haptic feedback
      HapticFeedback.selectionClick();
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _comments[index] = comment;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${comment.isLikedByCurrentUser ? 'unlike' : 'like'} comment')),
        );
      }
    }
  }

  void _replyToComment(CommentModel comment) {
    setState(() {
      _replyingTo = comment;
    });
    _commentFocusNode.requestFocus();
    _inputAnimationController.forward();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
    _commentFocusNode.unfocus();
    _inputAnimationController.reverse();
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'sort_newest':
        _sortComments(CommentSortType.newest);
        break;
      case 'sort_oldest':
        _sortComments(CommentSortType.oldest);
        break;
      case 'sort_popular':
        _sortComments(CommentSortType.popular);
        break;
      case 'refresh':
        _refreshComments();
        break;
    }
  }

  void _sortComments(CommentSortType sortType) {
    setState(() {
      switch (sortType) {
        case CommentSortType.newest:
          _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case CommentSortType.oldest:
          _comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case CommentSortType.popular:
          _comments.sort((a, b) => b.likesCount.compareTo(a.likesCount));
          break;
      }
    });
  }

  void _openUserProfile(String userId) {
    // TODO: Navigate to user profile
    debugPrint('Opening profile for user: $userId');
  }

  void _reportComment(CommentModel comment) {
    // TODO: Implement comment reporting
    debugPrint('Reporting comment: ${comment.id}');
  }
}

enum CommentSortType {
  newest,
  oldest,
  popular,
}