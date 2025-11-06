// Comments Screen for TALOWA Instagram-like Comments
// Comprehensive comments interface with nested replies and real-time updates
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../../models/social_feed/comment_model.dart';
import '../../services/social_feed/comment_service.dart';
import '../../widgets/common/user_avatar_widget.dart';
import '../../widgets/common/error_boundary_widget.dart';

class CommentsScreen extends StatefulWidget {
  final InstagramPostModel post;

  const CommentsScreen({
    super.key,
    required this.post,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();

  List<CommentThread> _commentThreads = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isPosting = false;
  String? _replyingToCommentId;
  String? _replyingToUsername;
  CommentSortOption _sortOption = CommentSortOption.newest;

  StreamSubscription<List<CommentThread>>? _commentsSubscription;
  StreamSubscription<String>? _commentUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeComments();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    _commentsSubscription?.cancel();
    _commentUpdateSubscription?.cancel();
    super.dispose();
  }

  void _initializeComments() async {
    try {
      await _commentService.initialize();
      _setupStreamListeners();
      await _loadComments();
    } catch (e) {
      debugPrint('❌ Failed to initialize comments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupStreamListeners() {
    // Listen to comments stream
    _commentsSubscription = _commentService.getCommentsStream(widget.post.id).listen(
      (threads) {
        if (mounted) {
          setState(() {
            _commentThreads = threads;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('❌ Comments stream error: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );

    // Listen to comment updates
    _commentUpdateSubscription = _commentService.commentUpdateStream.listen(
      (commentId) {
        // Comments will be updated via the stream
      },
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreComments();
      }
    });
  }

  Future<void> _loadComments() async {
    try {
      setState(() => _isLoading = true);
      await _commentService.getComments(
        widget.post.id,
        sortOption: _sortOption,
      );
    } catch (e) {
      debugPrint('❌ Failed to load comments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || _commentThreads.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      // Implementation for pagination would go here
      // For now, we'll just mark as not loading
    } catch (e) {
      debugPrint('❌ Failed to load more comments: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isPosting) return;

    setState(() => _isPosting = true);

    try {
      await _commentService.addComment(
        postId: widget.post.id,
        content: content,
        parentCommentId: _replyingToCommentId,
      );

      _commentController.clear();
      _clearReply();
      _commentFocusNode.unfocus();

      HapticFeedback.lightImpact();

    } catch (e) {
      debugPrint('❌ Failed to post comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  void _replyToComment(CommentModel comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToUsername = comment.authorName;
    });
    _commentController.text = '@${comment.authorName} ';
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    _commentFocusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  void _changeSortOption(CommentSortOption newOption) {
    if (newOption != _sortOption) {
      setState(() {
        _sortOption = newOption;
        _isLoading = true;
      });
      _loadComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundaryWidget(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildCommentsBody()),
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.black),
      ),
      title: const Text(
        'Comments',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        PopupMenuButton<CommentSortOption>(
          onSelected: _changeSortOption,
          icon: const Icon(Icons.sort, color: Colors.black),
          itemBuilder: (context) => CommentSortOption.values.map((option) {
            return PopupMenuItem(
              value: option,
              child: Row(
                children: [
                  if (option == _sortOption)
                    const Icon(Icons.check, color: AppTheme.talowaGreen, size: 20),
                  if (option == _sortOption) const SizedBox(width: 8),
                  Text(option.displayName),
                ],
              ),
            );
          }).toList(),
        ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  Widget _buildCommentsBody() {
    if (_isLoading && _commentThreads.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.talowaGreen),
      );
    }

    if (_commentThreads.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _commentThreads.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _commentThreads.length) {
          return _buildCommentThread(_commentThreads[index]);
        } else {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.talowaGreen),
            ),
          );
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to comment on this post',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentThread(CommentThread thread) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentItem(thread.parentComment, isParent: true),
        
        // Show replies
        if (thread.replies.isNotEmpty) ...[
          ...thread.replies.map((reply) => Padding(
            padding: const EdgeInsets.only(left: 48),
            child: _buildCommentItem(reply, isReply: true),
          )),
        ],
        
        // Show "View more replies" if there are more
        if (thread.hasMoreReplies) ...[
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () => _loadMoreReplies(thread.parentComment.id),
              child: Text(
                'View ${thread.totalRepliesCount - thread.replies.length} more replies',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        
        const Divider(height: 1, color: Colors.grey),
      ],
    );
  }

  Widget _buildCommentItem(CommentModel comment, {bool isParent = false, bool isReply = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isReply ? 4 : 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatarWidget(
            name: comment.authorName,
            imageUrl: comment.authorProfileImageUrl,
            size: isReply ? 24 : 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isReply ? 13 : 14,
                      ),
                    ),
                    if (comment.isAuthorVerified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: isReply ? 12 : 14,
                      ),
                    ],
                    if (comment.isPinned) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.push_pin,
                        color: AppTheme.talowaGreen,
                        size: isReply ? 12 : 14,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isReply ? 11 : 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: isReply ? 13 : 14,
                    height: 1.3,
                  ),
                ),
                if (comment.isEdited) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Edited',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _commentService.toggleCommentLike(comment.id),
                      child: Row(
                        children: [
                          Icon(
                            comment.isLikedByCurrentUser 
                                ? Icons.favorite 
                                : Icons.favorite_border,
                            color: comment.isLikedByCurrentUser 
                                ? Colors.red 
                                : Colors.grey[600],
                            size: 16,
                          ),
                          if (comment.likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              comment.likesCount.toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (isParent) ...[
                      GestureDetector(
                        onTap: () => _replyToComment(comment),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_replyingToUsername != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Replying to $_replyingToUsername',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearReply,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  maxLines: null,
                  maxLength: 2200,
                  decoration: InputDecoration(
                    hintText: _replyingToUsername != null 
                        ? 'Reply to $_replyingToUsername...'
                        : 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppTheme.talowaGreen),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    counterText: '',
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isPosting ? null : _postComment,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isPosting ? Colors.grey[300] : AppTheme.talowaGreen,
                    shape: BoxShape.circle,
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 16,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadMoreReplies(String commentId) async {
    try {
      final replies = await _commentService.getReplies(commentId);
      // Update the specific thread with more replies
      // This would require more complex state management
      debugPrint('✅ Loaded ${replies.length} more replies');
    } catch (e) {
      debugPrint('❌ Failed to load more replies: $e');
    }
  }
}