// Comment Widget - Individual comment display
// Part of Task 7: Build post engagement interface

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';

class CommentWidget extends StatefulWidget {
  final CommentModel comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onUserTap;
  final VoidCallback onReport;

  const CommentWidget({
    super.key,
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.onUserTap,
    required this.onReport,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> with TickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: widget.comment.isReply ? 48.0 : 16.0,
        right: 16.0,
        top: 12.0,
        bottom: 8.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentHeader(),
          const SizedBox(height: 4),
          _buildCommentContent(),
          const SizedBox(height: 8),
          _buildCommentActions(),
          if (widget.comment.hasReplies && !widget.comment.isReply)
            _buildRepliesSection(),
        ],
      ),
    );
  }

  Widget _buildCommentHeader() {
    return Row(
      children: [
        // Author avatar
        GestureDetector(
          onTap: widget.onUserTap,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.talowaGreen,
            backgroundImage: widget.comment.authorAvatarUrl != null
                ? NetworkImage(widget.comment.authorAvatarUrl!)
                : null,
            child: widget.comment.authorAvatarUrl == null
                ? Text(
                    widget.comment.authorName.isNotEmpty
                        ? widget.comment.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 8),
        
        // Author name and time
        Expanded(
          child: GestureDetector(
            onTap: widget.onUserTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.comment.authorName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.comment.authorRole != null) ...[
                      const SizedBox(width: 6),
                      _buildRoleBadge(widget.comment.authorRole!),
                    ],
                  ],
                ),
                Text(
                  widget.comment.getTimeAgo(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // More options
        PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, size: 16, color: Colors.grey[600]),
          onSelected: _handleCommentAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'report',
              child: ListTile(
                leading: Icon(Icons.flag, size: 16),
                title: Text('Report'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'copy',
              child: ListTile(
                leading: Icon(Icons.copy, size: 16),
                title: Text('Copy'),
                dense: true,
              ),
            ),
          ],
        ),
      ],
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
          fontSize: 8,
          fontWeight: FontWeight.w500,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildCommentContent() {
    return Padding(
      padding: const EdgeInsets.only(left: 30),
      child: Text(
        widget.comment.content,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildCommentActions() {
    return Padding(
      padding: const EdgeInsets.only(left: 30),
      child: Row(
        children: [
          // Like button
          ScaleTransition(
            scale: _likeAnimation,
            child: GestureDetector(
              onTap: _handleLike,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.comment.isLikedByCurrentUser
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 16,
                    color: widget.comment.isLikedByCurrentUser
                        ? Colors.red
                        : Colors.grey[600],
                  ),
                  if (widget.comment.likesCount > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      widget.comment.likesCount.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Reply button
          if (!widget.comment.isReply)
            GestureDetector(
              onTap: widget.onReply,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Reply',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepliesSection() {
    if (widget.comment.replies.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTheme.talowaGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  _isExpanded 
                      ? 'Hide replies'
                      : 'View ${widget.comment.replies.length} ${widget.comment.replies.length == 1 ? 'reply' : 'replies'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.talowaGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          ...widget.comment.replies.map((reply) => CommentWidget(
            comment: reply,
            onLike: () => _likeReply(reply),
            onReply: () {}, // Replies can't have replies
            onUserTap: () => _openUserProfile(reply.authorId),
            onReport: () => _reportReply(reply),
          )),
        ],
      ],
    );
  }

  void _handleLike() {
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });
    HapticFeedback.selectionClick();
    widget.onLike();
  }

  void _handleCommentAction(String action) {
    switch (action) {
      case 'report':
        widget.onReport();
        break;
      case 'copy':
        _copyComment();
        break;
    }
  }

  void _copyComment() {
    Clipboard.setData(ClipboardData(text: widget.comment.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comment copied to clipboard')),
    );
  }

  void _likeReply(CommentModel reply) {
    // TODO: Implement reply like functionality
  }

  void _openUserProfile(String userId) {
    // TODO: Navigate to user profile
  }

  void _reportReply(CommentModel reply) {
    // TODO: Implement reply reporting
  }
}


