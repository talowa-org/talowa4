// Enhanced Conversation List Widget for TALOWA Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/conversation_model.dart';
import '../../services/messaging/messaging_service.dart';
import '../../services/auth_service.dart';
import 'conversation_tile_widget.dart';

class EnhancedConversationListWidget extends StatefulWidget {
  final ConversationType? filterType;
  final Function(ConversationModel)? onConversationTap;
  final Function(ConversationModel)? onConversationLongPress;
  final String searchQuery;

  const EnhancedConversationListWidget({
    super.key,
    this.filterType,
    this.onConversationTap,
    this.onConversationLongPress,
    this.searchQuery = '',
  });

  @override
  State<EnhancedConversationListWidget> createState() => _EnhancedConversationListWidgetState();
}

class _EnhancedConversationListWidgetState extends State<EnhancedConversationListWidget> {
  List<ConversationModel> _allConversations = [];
  List<ConversationModel> _filteredConversations = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void didUpdateWidget(EnhancedConversationListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.filterType != widget.filterType) {
      _filterConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading conversations...'),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading conversations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredConversations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshConversations,
      child: ListView.builder(
        itemCount: _filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = _filteredConversations[index];
          return _buildConversationTile(conversation, index);
        },
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conversation, int index) {
    final currentUserId = AuthService.currentUser?.uid ?? '';
    
    return Dismissible(
      key: Key(conversation.id),
      background: _buildSwipeBackground(isArchive: true),
      secondaryBackground: _buildSwipeBackground(isArchive: false),
      confirmDismiss: (direction) => _handleSwipeAction(conversation, direction),
      child: ConversationTileWidget(
        conversation: conversation,
        currentUserId: currentUserId,
        onTap: () => widget.onConversationTap?.call(conversation),
        onLongPress: () => widget.onConversationLongPress?.call(conversation),
      ),
    );
  }

  Widget _buildSwipeBackground({required bool isArchive}) {
    return Container(
      color: isArchive ? Colors.blue : Colors.red,
      alignment: isArchive ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        isArchive ? Icons.archive : Icons.delete,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildEmptyState() {
    String title;
    String subtitle;
    IconData icon;

    if (widget.searchQuery.isNotEmpty) {
      title = 'No conversations found';
      subtitle = 'Try searching with different keywords';
      icon = Icons.search_off;
    } else {
      switch (widget.filterType) {
        case ConversationType.group:
          title = 'No group chats';
          subtitle = 'Create a group to start collaborating';
          icon = Icons.group;
          break;
        case ConversationType.direct:
          title = 'No direct messages';
          subtitle = 'Start a conversation with someone';
          icon = Icons.person;
          break;
        case ConversationType.anonymous:
          title = 'No anonymous reports';
          subtitle = 'Anonymous reports will appear here';
          icon = Icons.visibility_off;
          break;
        default:
          title = 'No conversations yet';
          subtitle = 'Start a conversation to connect with your network';
          icon = Icons.chat_bubble_outline;
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.filterType == null && widget.searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateConversationDialog,
              icon: const Icon(Icons.add),
              label: const Text('Start Conversation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.talowaGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      MessagingService().getUserConversations().listen(
        (conversations) {
          if (mounted) {
            setState(() {
              _allConversations = conversations;
              _isLoading = false;
            });
            _filterConversations();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error.toString();
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshConversations() async {
    // Force refresh by reloading conversations
    await _loadConversations();
  }

  void _filterConversations() {
    List<ConversationModel> filtered = _allConversations;

    // Apply type filter
    if (widget.filterType != null) {
      filtered = filtered.where((conv) => conv.type == widget.filterType).toList();
    }

    // Apply search filter
    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filtered = filtered.where((conv) {
        return conv.name.toLowerCase().contains(query) ||
               conv.lastMessage.toLowerCase().contains(query);
      }).toList();
    }

    // Sort by last message time (newest first)
    filtered.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    setState(() {
      _filteredConversations = filtered;
    });
  }

  Future<bool> _handleSwipeAction(ConversationModel conversation, DismissDirection direction) async {
    if (direction == DismissDirection.startToEnd) {
      // Archive conversation
      return await _showArchiveConfirmation(conversation);
    } else {
      // Delete conversation
      return await _showDeleteConfirmation(conversation);
    }
  }

  Future<bool> _showArchiveConfirmation(ConversationModel conversation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Conversation'),
        content: Text('Archive "${conversation.name}"? You can find it in archived chats.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // TODO: Implement archive functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${conversation.name} archived')),
        );
        return true;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    return false;
  }

  Future<bool> _showDeleteConfirmation(ConversationModel conversation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Delete "${conversation.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // TODO: Implement delete functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${conversation.name} deleted')),
        );
        return true;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    return false;
  }

  void _showCreateConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Conversation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: AppTheme.talowaGreen),
              title: const Text('Direct Message'),
              subtitle: const Text('Chat with a specific person'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to contact selection
              },
            ),
            ListTile(
              leading: const Icon(Icons.group, color: Colors.blue),
              title: const Text('Group Chat'),
              subtitle: const Text('Create a group conversation'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to group creation
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.orange),
              title: const Text('Broadcast'),
              subtitle: const Text('Send message to multiple people'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to broadcast creation
              },
            ),
          ],
        ),
      ),
    );
  }
}

