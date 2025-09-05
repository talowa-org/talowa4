// TALOWA Messages Screen - Real-time Communication
// Reference: in-app-communication/design.md - Messaging Architecture

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/conversation_model.dart';
import '../../services/messaging/simple_messaging_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/messages/conversation_tile_widget.dart';
import '../../widgets/messages/emergency_alert_banner.dart';
import '../../widgets/messages/message_search_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../onboarding/onboarding_screen.dart';
import '../help/help_center_screen.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  List<ConversationModel> _allConversations = [];
  List<ConversationModel> _filteredConversations = [];
  bool _hasEmergencyAlert = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadConversations();
    _checkEmergencyAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
        elevation: AppTheme.elevationLow,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _openSearch,
            tooltip: 'Search Messages',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _createNewChat,
            tooltip: 'New Chat',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Message Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archived',
                child: Row(
                  children: [
                    Icon(Icons.archive),
                    SizedBox(width: 8),
                    Text('Archived Chats'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'emergency',
                child: Row(
                  children: [
                    Icon(Icons.emergency, color: AppTheme.emergencyRed),
                    SizedBox(width: 8),
                    Text('Emergency Broadcast'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tutorial',
                child: Row(
                  children: [
                    Icon(Icons.school),
                    SizedBox(width: 8),
                    Text('Messaging Tutorial'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help),
                    SizedBox(width: 8),
                    Text('Help Center'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Groups'),
            Tab(text: 'Direct'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Emergency Alert Banner
          if (_hasEmergencyAlert)
            const EmergencyAlertBanner(
              message: 'Emergency: Land grabbing reported in your area',
              onTap: null, // TODO: Handle emergency alert tap
            ),
          
          // Search Bar
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            color: AppTheme.background,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterConversations('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
              ),
              onChanged: _filterConversations,
            ),
          ),
          
          // Conversations List
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'Loading conversations...')
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllConversations(),
                      _buildGroupChats(),
                      _buildDirectMessages(),
                      _buildAnonymousReports(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        tooltip: 'New Message',
        heroTag: "messages_new_chat",
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildAllConversations() {
    return _buildConversationsList(_filteredConversations);
  }

  Widget _buildGroupChats() {
    final groupChats = _filteredConversations
        .where((conv) => conv.type == ConversationType.group)
        .toList();
    return _buildConversationsList(groupChats);
  }

  Widget _buildDirectMessages() {
    final directMessages = _filteredConversations
        .where((conv) => conv.type == ConversationType.direct)
        .toList();
    return _buildConversationsList(directMessages);
  }

  Widget _buildAnonymousReports() {
    final anonymousReports = _filteredConversations
        .where((conv) => conv.type == ConversationType.anonymous)
        .toList();
    return _buildConversationsList(anonymousReports);
  }

  Widget _buildConversationsList(List<ConversationModel> conversations) {
    if (conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.secondaryText,
            ),
            SizedBox(height: AppTheme.spacingMedium),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText,
              ),
            ),
            SizedBox(height: AppTheme.spacingSmall),
            Text(
              'Start a conversation to connect with your network',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final currentUserId = AuthService.currentUser?.uid ?? '';
        
        return ConversationTileWidget(
          conversation: conversation,
          currentUserId: currentUserId,
          onTap: () => _openConversation(conversation),
          onLongPress: () => _showConversationOptions(conversation),
        );
      },
    );
  }

  // Data Loading Methods
  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Listen to real-time conversation updates
      SimpleMessagingService().getUserConversations().listen((conversations) {
        if (mounted) {
          setState(() {
            _allConversations = conversations;
            _filterConversations(_searchQuery);
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading conversations: $e');
    }
  }

  Future<void> _checkEmergencyAlerts() async {
    // TODO: Check for emergency alerts
    setState(() {
      _hasEmergencyAlert = true; // Mock emergency alert
    });
  }

  // Action Methods
  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageSearchWidget(
          onMessageTap: (message, conversation) {
            Navigator.pop(context);
            _openConversation(conversation);
          },
        ),
      ),
    );
  }

  void _createNewChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Direct Message'),
              subtitle: const Text('Chat with a specific person'),
              onTap: () {
                Navigator.pop(context);
                _showCreateDirectChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Group Chat'),
              subtitle: const Text('Create a group conversation'),
              onTap: () {
                Navigator.pop(context);
                _showCreateGroupChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('Broadcast Message'),
              subtitle: const Text('Send message to multiple people'),
              onTap: () {
                Navigator.pop(context);
                _showCreateBroadcast();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCreateDirectChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Direct Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search contacts',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // TODO: Implement contact search
              },
            ),
            const SizedBox(height: 16),
            const Text('Recent contacts:'),
            ListTile(
              leading: const CircleAvatar(child: Text('A')),
              title: const Text('Adv. Rajesh Kumar'),
              subtitle: const Text('Legal Advisor'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting chat with Adv. Rajesh Kumar')),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(child: Text('S')),
              title: const Text('Suresh Reddy'),
              subtitle: const Text('Village Coordinator'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting chat with Suresh Reddy')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group Chat'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Group Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),
            Text('Select members:'),
            // Add member selection UI here
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group chat created successfully!')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateBroadcast() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text('Send to:'),
            CheckboxListTile(
              title: const Text('All Network Members'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Village Coordinators'),
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Broadcast message sent!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'settings':
        // TODO: Navigate to message settings
        debugPrint('Opening message settings');
        break;
      case 'archived':
        // TODO: Navigate to archived chats
        debugPrint('Opening archived chats');
        break;
      case 'emergency':
        // TODO: Navigate to emergency broadcast
        debugPrint('Opening emergency broadcast');
        break;
      case 'tutorial':
        _openMessagingTutorial();
        break;
      case 'help':
        _openHelpCenter();
        break;
    }
  }

  void _openMessagingTutorial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(
          tutorialType: 'messaging',
          onCompleted: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Messaging tutorial completed! You\'re ready to communicate securely.'),
                backgroundColor: AppTheme.talowaGreen,
              ),
            );
          },
        ),
      ),
    );
  }

  void _openHelpCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpCenterScreen(),
      ),
    );
  }

  void _filterConversations(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredConversations = _allConversations;
      } else {
        _filteredConversations = _allConversations.where((conversation) {
          return conversation.name.toLowerCase().contains(query.toLowerCase()) ||
                 conversation.lastMessage.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _openConversation(ConversationModel conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversation: conversation),
      ),
    );
  }

  void _showConversationOptions(ConversationModel conversation) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ConversationOptionsSheet(
        conversation: conversation,
        onDelete: () => _deleteConversation(conversation.id),
        onArchive: () => _archiveConversation(conversation.id),
      ),
    );
  }

  Future<void> _deleteConversation(String conversationId) async {
    // TODO: Implement conversation deletion
    debugPrint('Deleting conversation: $conversationId');
  }

  Future<void> _archiveConversation(String conversationId) async {
    // TODO: Implement conversation archiving
    debugPrint('Archiving conversation: $conversationId');
  }
}

// Conversation Options Sheet
class ConversationOptionsSheet extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  const ConversationOptionsSheet({
    super.key,
    required this.conversation,
    required this.onDelete,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            conversation.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Options
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Conversation Info'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Show conversation info
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.notifications_off),
            title: const Text('Mute Notifications'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Mute notifications
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Archive Conversation'),
            onTap: () {
              Navigator.pop(context);
              onArchive();
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Conversation', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Are you sure you want to delete "${conversation.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Message Search Delegate
class MessageSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, '');
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final suggestions = [
      'Adv. Rajesh Kumar',
      'Suresh Reddy',
      'Village Group',
      'Legal Updates',
      'Emergency Alerts',
    ];

    final filteredSuggestions = suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filteredSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = filteredSuggestions[index];
        return ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text(suggestion),
          subtitle: const Text('Last message preview...'),
          onTap: () {
            close(context, suggestion);
          },
        );
      },
    );
  }
}
