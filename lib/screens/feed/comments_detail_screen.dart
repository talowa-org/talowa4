// Comments Detail Screen for TALOWA
// Full-featured comments system with create, edit, delete
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/instagram_post_model.dart';
import '../../services/auth/auth_service.dart';

class CommentsDetailScreen extends StatefulWidget {
  final InstagramPostModel post;

  const CommentsDetailScreen({super.key, required this.post});

  @override
  State<CommentsDetailScreen> createState() => _CommentsDetailScreenState();
}

class _CommentsDetailScreenState extends State<CommentsDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.black),
        ),
        title: const Text(
          'Comments',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildCommentsList()),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('post_comments')
          .where('postId', isEqualTo: widget.post.id)
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data?.docs ?? [];

        if (comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No comments yet', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Be the first to comment!', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index].data() as Map<String, dynamic>;
            final commentId = comments[index].id;
            return _buildCommentItem(comment, commentId);
          },
        );
      },
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, String commentId) {
    final isOwnComment = comment['authorId'] == AuthService.currentUser?.uid;
    final timestamp = (comment['createdAt'] as Timestamp?)?.toDate();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: Text(
              comment['authorName']?.toString().substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment['authorName'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(comment['content'] ?? '', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (timestamp != null)
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    if (isOwnComment) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _deleteComment(commentId),
                        child: Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red[400])),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          _isSubmitting
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: _submitComment,
                  icon: const Icon(Icons.send, color: AppTheme.talowaGreen),
                  iconSize: 28,
                ),
        ],
      ),
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('post_comments').add({
        'postId': widget.post.id,
        'authorId': currentUser.uid,
        'authorName': userData['fullName'] ?? 'Unknown',
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .update({'commentsCount': FieldValue.increment(1)});

      _commentController.clear();
      
      if (mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('post_comments')
          .doc(commentId)
          .delete();

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .update({'commentsCount': FieldValue.increment(-1)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}
