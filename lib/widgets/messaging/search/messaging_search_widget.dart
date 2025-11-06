// Messaging Search Widget for TALOWA
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
// Task: Implement comprehensive search and filtering functionality

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/messaging/message_model.dart';
import '../../../models/user_model.dart';
import '../../../services/messaging/messaging_search_service.dart';
import 'user_search_results_widget.dart';
import 'message_search_results_widget.dart';
import 'search_filters_widget.dart';
import 'search_suggestions_widget.dart';

/// Main search widget for messaging functionality
class MessagingSearchWidget extends StatefulWidget {
  final SearchMode initialMode;
  final String? initialQuery;
  final Function(UserModel)? onUserSelected;
  final Function(MessageModel)? onMessageSelected;
  final bool showFilters;

  const MessagingSearchWidget({
    Key? key,
    this.initialMode = SearchMode.users,
    this.initialQuery,
    this.onUserSelected,
    this.onMessageSelected,
    this.showFilters = true,
  }) : super(key: key);

  @override
  State<MessagingSearchWidget> createState() => _MessagingSearchWidgetState();
}

class _MessagingSearchWidgetState extends State<MessagingSearchWidget>
    with TickerProviderStateMixin {
  final MessagingSearchService _searchService = MessagingSearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late TabController _tabController;
  Timer? _searchDebounceTimer;
  
  SearchMode _currentMode = SearchMode.users;
  bool _isSearching = false;
  bool _showSuggestions = false;
  bool _showFilters = false;
  
  // Search results
  UserSearchResult? _userSearchResult;
  MessageSearchResult? _messageSearchResult;
  List<String> _searchSuggestions = [];
  
  // Filters
  UserSearchFilters? _userFilters;
  MessageSearchFilters? _messageFilters;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _currentMode == SearchMode.users ? 0 : 1,
    );
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
    
    _setupListeners();
    _initializeSearchService();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _tabController.addListener(_onTabChanged);
  }

  Future<void> _initializeSearchService() async {
    try {
      await _searchService.initialize();
    } catch (e) {
      debugPrint('Error initializing search service: $e');
    }
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    
    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _userSearchResult = null;
        _messageSearchResult = null;
      });
      return;
    }
    
    // Show suggestions for short queries
    if (query.length < 3) {
      _getSuggestions(query);
      return;
    }
    
    // Debounce search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty) {
      _getSuggestions(_searchController.text);
    } else {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _onTabChanged() {
    final newMode = _tabController.index == 0 ? SearchMode.users : SearchMode.messages;
    if (newMode != _currentMode) {
      setState(() {
        _currentMode = newMode;
      });
      
      // Re-search with new mode if there's a query
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      }
    }
  }

  Future<void> _getSuggestions(String query) async {
    try {
      final suggestions = await _searchService.getSearchSuggestions(query);
      setState(() {
        _searchSuggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Error getting search suggestions: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });
    
    try {
      if (_currentMode == SearchMode.users) {
        final result = await _searchService.searchUsers(
          query: query,
          filters: _userFilters,
        );
        setState(() {
          _userSearchResult = result;
        });
      } else {
        final result = await _searchService.searchMessages(
          query: query,
          filters: _messageFilters,
        );
        setState(() {
          _messageSearchResult = result;
        });
      }
    } catch (e) {
      debugPrint('Error performing search: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _onSuggestionSelected(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _performSearch(suggestion);
  }

  void _onUserFiltersChanged(UserSearchFilters? filters) {
    setState(() {
      _userFilters = filters;
    });
    
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text.trim());
    }
  }

  void _onMessageFiltersChanged(MessageSearchFilters? filters) {
    setState(() {
      _messageFilters = filters;
    });
    
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text.trim());
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _userSearchResult = null;
      _messageSearchResult = null;
      _showSuggestions = false;
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Messages', icon: Icon(Icons.message)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),
          
          // Filters
          if (_showFilters) _buildFilters(),
          
          // Search suggestions
          if (_showSuggestions) _buildSuggestions(),
          
          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: _currentMode == SearchMode.users 
                    ? 'Search users by name, phone, or role...'
                    : 'Search messages...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                    if (widget.showFilters)
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: _showFilters ? Theme.of(context).primaryColor : null,
                        ),
                        onPressed: _toggleFilters,
                      ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SearchFiltersWidget(
      mode: _currentMode,
      userFilters: _userFilters,
      messageFilters: _messageFilters,
      onUserFiltersChanged: _onUserFiltersChanged,
      onMessageFiltersChanged: _onMessageFiltersChanged,
    );
  }

  Widget _buildSuggestions() {
    return SearchSuggestionsWidget(
      suggestions: _searchSuggestions,
      onSuggestionSelected: _onSuggestionSelected,
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return _buildEmptyState();
    }

    if (_currentMode == SearchMode.users) {
      return UserSearchResultsWidget(
        result: _userSearchResult,
        searchQuery: _searchController.text.trim(),
        onUserSelected: widget.onUserSelected,
      );
    } else {
      return MessageSearchResultsWidget(
        result: _messageSearchResult,
        searchQuery: _searchController.text.trim(),
        onMessageSelected: widget.onMessageSelected,
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentMode == SearchMode.users ? Icons.people_outline : Icons.message_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _currentMode == SearchMode.users 
                ? 'Search for users to start messaging'
                : 'Search through your message history',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentMode == SearchMode.users
                ? 'Find users by name, phone number, or role'
                : 'Find messages by content or sender',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          _buildSearchHistory(),
        ],
      ),
    );
  }

  Widget _buildSearchHistory() {
    final searchHistory = _searchService.getSearchHistory();
    if (searchHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Searches',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: searchHistory.take(5).map((query) {
            return ActionChip(
              label: Text(query),
              onPressed: () {
                _searchController.text = query;
                _performSearch(query);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

enum SearchMode { users, messages }