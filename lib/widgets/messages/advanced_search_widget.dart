// Advanced Search Widget for Premium Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/messaging/message_model.dart';
import '../../services/messaging/advanced_messaging_service.dart';

class AdvancedSearchWidget extends StatefulWidget {
  final Function(List<MessageModel>) onSearchResults;
  final VoidCallback? onClose;

  const AdvancedSearchWidget({
    super.key,
    required this.onSearchResults,
    this.onClose,
  });

  @override
  State<AdvancedSearchWidget> createState() => _AdvancedSearchWidgetState();
}

class _AdvancedSearchWidgetState extends State<AdvancedSearchWidget>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final AdvancedMessagingService _advancedMessaging = AdvancedMessagingService();
  
  late TabController _tabController;
  bool _isSearching = false;
  List<String> _searchSuggestions = [];
  List<MessageModel> _searchResults = [];
  
  // Filter options
  final List<MessageType> _selectedMessageTypes = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedSender;
  bool _includeDeleted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final query = _searchController.text;
    if (query.length >= 2) {
      _getSuggestions(query);
    } else {
      setState(() {
        _searchSuggestions = [];
      });
    }
  }

  Future<void> _getSuggestions(String query) async {
    try {
      final suggestions = await _advancedMessaging.getSearchSuggestions(query);
      setState(() {
        _searchSuggestions = suggestions;
      });
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchSuggestions = [];
    });

    try {
      List<MessageModel> results;
      
      if (_tabController.index == 0) {
        // Basic search
        results = await _advancedMessaging.searchMessages(
          query: query,
          messageTypes: _selectedMessageTypes.isNotEmpty ? _selectedMessageTypes : null,
          startDate: _startDate,
          endDate: _endDate,
          senderId: _selectedSender,
          includeDeleted: _includeDeleted,
        );
      } else {
        // Smart search
        results = await _advancedMessaging.smartSearch(query);
      }

      setState(() {
        _searchResults = results;
      });
      
      widget.onSearchResults(results);
    } catch (e) {
      debugPrint('Error performing search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _performSmartSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _advancedMessaging.smartSearch(query);
      setState(() {
        _searchResults = results;
      });
      widget.onSearchResults(results);
    } catch (e) {
      debugPrint('Error performing smart search: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.talowaGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Advanced Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Search tabs
          Container(
            color: AppTheme.talowaGreen,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Basic Search'),
                Tab(text: 'Smart Search'),
              ],
            ),
          ),

          // Search input
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _performSearch,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),

          // Search suggestions
          if (_searchSuggestions.isNotEmpty)
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suggestions:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _searchSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _searchSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.history, size: 16),
                          title: Text(suggestion),
                          onTap: () {
                            _searchController.text = suggestion;
                            _performSearch();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicSearchTab(),
                _buildSmartSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message type filters
          const Text(
            'Message Types:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: MessageType.values.map((type) {
              final isSelected = _selectedMessageTypes.contains(type);
              return FilterChip(
                label: Text(type.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedMessageTypes.add(type);
                    } else {
                      _selectedMessageTypes.remove(type);
                    }
                  });
                },
                selectedColor: AppTheme.talowaGreen.withValues(alpha: 0.3),
                checkmarkColor: AppTheme.talowaGreen,
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Date range
          const Text(
            'Date Range:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(true),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_startDate != null 
                      ? 'From: ${_formatDate(_startDate!)}'
                      : 'Start Date'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(false),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_endDate != null 
                      ? 'To: ${_formatDate(_endDate!)}'
                      : 'End Date'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Additional options
          const Text(
            'Options:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text('Include deleted messages'),
            value: _includeDeleted,
            onChanged: (value) {
              setState(() {
                _includeDeleted = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),

          const SizedBox(height: 24),

          // Search results count
          if (_searchResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.talowaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: AppTheme.talowaGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Found ${_searchResults.length} messages',
                    style: const TextStyle(
                      color: AppTheme.talowaGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmartSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Smart search info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    Text(
                      'AI-Powered Search',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use natural language to search your messages. Try queries like:',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• "Show me images from last week"\n'
                  '• "Find documents about land rights"\n'
                  '• "Messages from John about the meeting"\n'
                  '• "Urgent messages from yesterday"',
                  style: TextStyle(
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick search buttons
          const Text(
            'Quick Searches:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickSearchChip('Images from today', Icons.image),
              _buildQuickSearchChip('Documents this week', Icons.description),
              _buildQuickSearchChip('Voice messages', Icons.mic),
              _buildQuickSearchChip('Urgent messages', Icons.priority_high),
              _buildQuickSearchChip('Meeting discussions', Icons.meeting_room),
              _buildQuickSearchChip('Legal documents', Icons.gavel),
            ],
          ),

          const SizedBox(height: 24),

          // Search results
          if (_searchResults.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Results (${_searchResults.length}):',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final message = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(message.senderName[0]),
                        ),
                        title: Text(
                          message.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${message.senderName} • ${_formatDate(message.sentAt)}',
                        ),
                        trailing: Icon(_getMessageTypeIcon(message.messageType)),
                        onTap: () {
                          // Navigate to message in conversation
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickSearchChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () {
        _searchController.text = label.toLowerCase();
        _performSmartSearch();
      },
      backgroundColor: AppTheme.talowaGreen.withValues(alpha: 0.1),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        if (isStartDate) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.audio:
        return Icons.mic;
      case MessageType.document:
        return Icons.description;
      case MessageType.location:
        return Icons.location_on;
      default:
        return Icons.message;
    }
  }
}