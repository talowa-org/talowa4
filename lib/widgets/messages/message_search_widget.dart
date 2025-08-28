// Message Search Widget for TALOWA Messaging
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/message_model.dart';
import '../../models/messaging/conversation_model.dart';
import '../../services/messaging/messaging_service.dart';
import '../../services/auth_service.dart';

class MessageSearchWidget extends StatefulWidget {
  final Function(MessageModel, ConversationModel)? onMessageTap;

  const MessageSearchWidget({
    super.key,
    this.onMessageTap,
  });

  @override
  State<MessageSearchWidget> createState() => _MessageSearchWidgetState();
}

class _MessageSearchWidgetState extends State<MessageSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<MessageSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _currentQuery) {
      _currentQuery = query;
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults.clear();
          _hasSearched = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: const InputDecoration(
            hintText: 'Search messages...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          autofocus: true,
        ),
        backgroundColor: AppTheme.talowaGreen,
        foregroundColor: Colors.white,
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search filters
          _buildSearchFilters(),
          
          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', true),
            const SizedBox(width: 8),
            _buildFilterChip('Images', false),
            const SizedBox(width: 8),
            _buildFilterChip('Documents', false),
            const SizedBox(width: 8),
            _buildFilterChip('Links', false),
            const SizedBox(width: 8),
            _buildFilterChip('Voice', false),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // TODO: Implement filter logic
      },
      selectedColor: AppTheme.talowaGreen.withOpacity(0.2),
      checkmarkColor: AppTheme.talowaGreen,
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching messages...'),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildSearchSuggestions();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResultTile(result);
      },
    );
  }

  Widget _buildSearchSuggestions() {
    final suggestions = [
      'Recent searches',
      'land records',
      'court date',
      'patta application',
      'legal advice',
    ];

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              suggestions[index],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          );
        }

        return ListTile(
          leading: const Icon(Icons.history, color: Colors.grey),
          title: Text(suggestions[index]),
          onTap: () {
            _searchController.text = suggestions[index];
            _performSearch(suggestions[index]);
          },
        );
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(MessageSearchResult result) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.talowaGreen,
        child: Text(
          result.conversation.name.isNotEmpty 
              ? result.conversation.name[0].toUpperCase() 
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        result.conversation.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87),
              children: _highlightSearchTerm(
                result.message.content,
                _currentQuery,
              ),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                result.message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                ' • ${_formatDate(result.message.sentAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: _getMessageTypeIcon(result.message.messageType),
      onTap: () => widget.onMessageTap?.call(result.message, result.conversation),
    );
  }

  List<TextSpan> _highlightSearchTerm(String text, String searchTerm) {
    if (searchTerm.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerSearchTerm = searchTerm.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerSearchTerm);
    
    while (index != -1) {
      // Add text before the match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + searchTerm.length),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + searchTerm.length;
      index = lowerText.indexOf(lowerSearchTerm, start);
    }
    
    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    
    return spans;
  }

  Widget? _getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return const Icon(Icons.image, size: 16, color: Colors.blue);
      case MessageType.document:
        return const Icon(Icons.description, size: 16, color: Colors.orange);
      case MessageType.audio:
        return const Icon(Icons.mic, size: 16, color: Colors.purple);
      case MessageType.location:
        return const Icon(Icons.location_on, size: 16, color: Colors.red);
      default:
        return null;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _searchMessages(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      if (kDebugMode) {
        debugPrint('Search error: $e');
      }
    }
  }

  Future<List<MessageSearchResult>> _searchMessages(String query) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return [];

    // Get all conversations for the user
    final conversations = await MessagingService().getUserConversations().first;
    final List<MessageSearchResult> results = [];

    // Search through each conversation
    for (final conversation in conversations) {
      try {
        final messages = await MessagingService()
            .getConversationMessages(conversationId: conversation.id, limit: 100)
            .first;

        // Filter messages that contain the search query
        final matchingMessages = messages.where((message) {
          return message.content.toLowerCase().contains(query.toLowerCase()) &&
                 !message.isDeleted;
        }).toList();

        // Add to results
        for (final message in matchingMessages) {
          results.add(MessageSearchResult(
            message: message,
            conversation: conversation,
          ));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error searching conversation ${conversation.id}: $e');
        }
      }
    }

    // Sort by relevance and date
    results.sort((a, b) {
      // First sort by relevance (exact matches first)
      final aExact = a.message.content.toLowerCase() == query.toLowerCase();
      final bExact = b.message.content.toLowerCase() == query.toLowerCase();
      
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      
      // Then sort by date (newest first)
      return b.message.sentAt.compareTo(a.message.sentAt);
    });

    return results.take(50).toList(); // Limit to 50 results
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults.clear();
      _hasSearched = false;
      _currentQuery = '';
    });
  }
}

// Search result data class
class MessageSearchResult {
  final MessageModel message;
  final ConversationModel conversation;

  MessageSearchResult({
    required this.message,
    required this.conversation,
  });
}

// Global Message Search Delegate
class GlobalMessageSearchDelegate extends SearchDelegate<MessageSearchResult?> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return MessageSearchWidget(
      onMessageTap: (message, conversation) {
        close(context, MessageSearchResult(
          message: message,
          conversation: conversation,
        ));
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return MessageSearchWidget(
      onMessageTap: (message, conversation) {
        close(context, MessageSearchResult(
          message: message,
          conversation: conversation,
        ));
      },
    );
  }
}