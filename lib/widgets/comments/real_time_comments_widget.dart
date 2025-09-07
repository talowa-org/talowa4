// Real-time Comments Widget for TALOWA Social Feed
// Implements Task 15: Add real-time engagement features - Comments

import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/social_feed/real_time_engagement_service.dart';
import '../../models/social_feed/index.dart';
import '../../core/theme/app_theme.dart';
import '../feed/real_time_engagement_widget.dart';

class RealTimeCommentsWidget extends StatefulWidget {
  final String postId;
  final List<CommentModel> initialComments;
  final VoidCallback? onCommentsChanged;

  const RealTimeCommentsWidget({
    super.key,
    required this.postId,
    required this.initialComments,
    this.onCommentsChanged,
  });

  @override
  State<RealTimeCommentsWidget> createState() => _RealTimeCommentsWidgetState();
}

class _RealTimeCommentsWidgetState extends State<RealTimeCommentsWidget>
    with TickerProviderStateMixin {
  final RealTimeEngagementService _engagementService = RealTimeEngagementService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  
  late StreamSubscription _commentSubscription;
  late AnimationController _newCommentAnimationController;
  
  List<CommentModel> _comments = [];
  bool _isSubmitting = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    
    _comments = List.from(widget.initialComments);
    
    _newCommentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _startCommentTracking();
    _setupTypingIndicator();
  }

  void _startCommentTracking() {
    _engagementService.startCommentTracking(widget.postId);
    
    _commentSubscription = _engagementService.commentUpdates
        .where((update) => update.postId == widget.postId)
        .listen((update) {
      if (mounted) {
        _handleCommentUpdate(update);
      }
    });
  }

  void _setupTypingIndicator() {
    _commentController.addListener(() {
      _typingTimer?.cancel();
      
      if (_commentController.text.isNotEmpty) {
        _engagementService.startTypingIndicator(widget.postId);
        
        _typingTimer = Timer(const Duration(seconds: 2), () {
          _engagementService.stopTypingIndicator(widget.postId);
        });
      } else {
        _engagementService.stopTypingIndicator(widget.postId);
      }
    });
  }

  void _handleCommentUpdate(CommentUpdate update) {
    setState(() {
      switch (update.updateType) {
        case CommentUpdateType.added:
          // Check if comment already exists to avoid duplicates
          if (!_comments.any((c) => c.id == update.comment.id)) {
            _comments.add(update.comment);
            _comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            
            // Animate new comment
            _newCommentAnimationController.forward().then((_) {
              _newCommentAnimationController.reset();
            });
          }
          break;
        case CommentUpdateType.modified:
          final index = _comments.indexWhere((c) => c.id == update.comment.id);
          if (index != -1) {
            _comments[index] = update.comment;
          }
          break;
        case CommentUpdateType.removed:
          _comments.removeWhere((c) => c.id == update.comment.id);
          break;
      }
    });
    
    widget.onCommentsChanged?.call();
  }

  @override
  void dispose() {
    _commentSubscription.cancel();
    _engagementService.stopCommentTracking(widget.postId);
    _engagementService.stopTypingIndicator(widget.postId);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _newCommentAnimationController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comments List
        if (_comments.isNotEmpty) ...[
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              final isNewComment = index == _comments.length - 1;
              
              return AnimatedBuilder(
                animation: _newCommentAnimationController,
                builder: (context, child) {
                  return SlideTransition(
                    position: isNewComment
                        ? Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _newCommentAnimationController,
                            curve: Curves.easeOutBack,
                          ))
                        : const AlwaysStoppedAnimation(Offset.zero),
                    child: FadeTransition(
                      opacity: isNewComment
                          ? _newCommentAnimationController
                          : const AlwaysStoppedAnimation(1.0),
                      child: _buildCommentItem(comment),
                    ),
                  );
                },
              );
            },
          ),
        ],
        
        // Typing Indicator
        TypingIndicatorWidget(postId: widget.postId),
        
        // Comment Input
        _buildCommentInput(),
      ],
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.talowaGreen,
            backgroundImage: comment.authorAvatarUrl != null
                ? NetworkImage(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null
                ? Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
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
          
          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author and Time
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (comment.authorRole != null) ...[
                      const SizedBox(width: AppTheme.spacingSmall),
                      _buildRoleBadge(comment.authorRole!),
                    ],
                    const Spacer(),
                    Text(
                      comment.getTimeAgo(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Comment Text
                Text(
                  comment.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
                ),
                
                // Comment Actions
                const SizedBox(height: AppTheme.spacingSmall),
                Row(
                  children: [
                    // Like Button
                    GestureDetector(
                      onTap: () => _likeComment(comment.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment.isLikedByCurrentUser
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: comment.isLikedByCurrentUser
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          if (comment.likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              comment.likesCount.toString(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: comment.isLikedByCurrentUser
                                    ? Colors.red
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMedium),
                    
                    // Reply Button
                    GestureDetector(
                      onTap: () => _replyToComment(comment),
                      child: Text(
                        'Reply',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // More Options
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      onSelected: (value) => _handleCommentAction(value, comment),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Report'),
                        ),
                        if (comment.isAuthor) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                
                // Replies
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingSmall),
                  ...comment.replies.map((reply) => _buildReplyItem(reply)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(CommentModel reply) {
    return Container(
      margin: const EdgeInsets.only(left: 32, top: AppTheme.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.talowaGreen,
            backgroundImage: reply.authorAvatarUrl != null
                ? NetworkImage(reply.authorAvatarUrl!)
                : null,
            child: reply.authorAvatarUrl == null
                ? Text(
                    reply.authorName.isNotEmpty
                        ? reply.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.authorName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    Text(
                      reply.getTimeAgo(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.content,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    String badgeText;
    
    if (role.contains('coordinator')) {
      badgeColor = AppTheme.talowaGreen;
      badgeText = 'Coordinator';
    } else if (role.contains('admin')) {
      badgeColor = Colors.red;
      badgeText = 'Admin';
    } else {
      badgeColor = Colors.blue;
      badgeText = 'Member';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: _isSubmitting || _commentController.text.trim().isEmpty
                  ? null
                  : _submitComment,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.send,
                      color: _commentController.text.trim().isEmpty
                          ? Colors.grey[400]
                          : AppTheme.talowaGreen,
                    ),
              tooltip: 'Send Comment',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _isSubmitting) return;

    final content = _commentController.text.trim();
    _commentController.clear();
    _engagementService.stopTypingIndicator(widget.postId);

    setState(() {
      _isSubmitting = true;
    });

    try {
      // TODO: Implement comment submission to Firestore
      // This would typically call a service method to create the comment
      
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error submitting comment: $e');
      }
      // Show error message
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
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _likeComment(String commentId) {
    // TODO: Implement comment liking
  }

  void _replyToComment(CommentModel comment) {
    _commentController.text = '@${comment.authorName} ';
    _commentFocusNode.requestFocus();
  }

  void _handleCommentAction(String action, CommentModel comment) {
    switch (action) {
      case 'report':
        // TODO: Implement comment reporting
        break;
      case 'edit':
        // TODO: Implement comment editing
        break;
      case 'delete':
        // TODO: Implement comment deletion
        break;
    }
  }
}


