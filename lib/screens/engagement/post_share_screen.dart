// Post Share Screen - Share post with network options
// Part of Task 7: Build post engagement interface

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../services/social_feed/index.dart';

class PostShareScreen extends StatefulWidget {
  final PostModel post;

  const PostShareScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostShareScreen> createState() => _PostShareScreenState();
}

class _PostShareScreenState extends State<PostShareScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSharing = false;
  ShareOption? _selectedOption;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Post'),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSharing ? null : _sharePost,
            child: _isSharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Post preview
          _buildPostPreview(),
          const Divider(),
          
          // Share options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              children: [
                _buildSectionTitle('Share to'),
                const SizedBox(height: AppTheme.spacingMedium),
                
                // Share options
                ...ShareOption.values.map((option) => _buildShareOption(option)),
                
                const SizedBox(height: AppTheme.spacingLarge),
                
                // Add message
                _buildSectionTitle('Add a message (optional)'),
                const SizedBox(height: AppTheme.spacingMedium),
                _buildMessageInput(),
                
                const SizedBox(height: AppTheme.spacingLarge),
                
                // Quick actions
                _buildQuickActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostPreview() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
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
                Text(
                  widget.post.authorName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.post.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.post.likesCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.post.commentsCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildShareOption(ShareOption option) {
    final isSelected = _selectedOption == option;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: option.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            option.icon,
            color: option.color,
            size: 20,
          ),
        ),
        title: Text(
          option.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          option.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        trailing: Radio<ShareOption>(
          value: option,
          groupValue: _selectedOption,
          onChanged: (value) {
            setState(() {
              _selectedOption = value;
            });
          },
          activeColor: AppTheme.talowaGreen,
        ),
        onTap: () {
          setState(() {
            _selectedOption = option;
          });
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? AppTheme.talowaGreen : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _messageController,
        maxLines: 3,
        maxLength: 200,
        decoration: const InputDecoration(
          hintText: 'Add your thoughts about this post...',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.link),
                label: const Text('Copy Link'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareExternal,
                icon: const Icon(Icons.share),
                label: const Text('More Options'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _sharePost() async {
    if (_selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sharing option')),
      );
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      // TODO: Implement actual sharing logic based on selected option
      await FeedService.sharePost(widget.post.id, 'current_user_id');
      
      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post shared to ${_selectedOption!.title}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSharing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share post: ${e.toString()}')),
        );
      }
    }
  }

  void _copyLink() {
    final link = 'https://talowa.app/posts/${widget.post.id}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  void _shareExternal() {
    // TODO: Implement system share sheet
    debugPrint('Opening system share sheet');
  }
}

enum ShareOption {
  myNetwork('My Network', 'Share with your direct connections', Icons.people, Colors.blue),
  localCommunity('Local Community', 'Share with your village/mandal', Icons.location_city, Colors.green),
  publicFeed('Public Feed', 'Share publicly on TALOWA', Icons.public, Colors.orange),
  coordinators('Coordinators Only', 'Share with coordinators', Icons.admin_panel_settings, Colors.purple);

  const ShareOption(this.title, this.description, this.icon, this.color);
  
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}