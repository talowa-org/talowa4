// Algolia Search Widget - Lightning-fast search with advanced features
// Production-ready search interface for TALOWA platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/search/search_result_model.dart';
import '../../models/search/search_filter_model.dart';
import '../../services/search/production_algolia_service.dart';

class AlgoliaSearchWidget extends StatefulWidget {
  final String? initialQuery;
  final Function(SearchHitModel)? onResultTap;
  final Function(String)? onQueryChanged;
  final bool showFilters;
  final bool enableVoiceSearch;

  const AlgoliaSearchWidget({
    super.key,
    this.initialQuery,
    this.onResultTap,
    this.onQueryChanged,
    this.showFilters = true,
    this.enableVoiceSearch = true,
  });

  @override
  State<AlgoliaSearchWidget> createState() => _AlgoliaSearchWidgetState();
}

class _AlgoliaSearchWidgetState extends State<AlgoliaSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  UniversalSearchResultModel? _searchResults;
  List<String> _suggestions = [];
  SearchFilterModel _filters = const SearchFilterModel();
  
  bool _isLoading = false;
  bool _showSuggestions = false;
  String? _errorMessage;
  
  // Search performance metrics
  int _lastSearchTime = 0;
  int _totalSearches = 0;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
    
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    
    _initializeAlgoliaService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeAlgoliaService() async {
    try {
      await ProductionAlgoliaService.instance.initialize();
    } catch (e) {
      debugPrint('Failed to initialize Algolia service: $e');
      setState(() {
        _errorMessage = 'Search service initialization failed';
      });
    }
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    
    if (widget.onQueryChanged != null) {
      widget.onQueryChanged!(query);
    }
    
    if (query.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    if (query.length >= 2) {
      _getSuggestions(query);
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty) {
      setState(() => _showSuggestions = true);
    } else {
      setState(() => _showSuggestions = false);
    }
  }

  Future<void> _getSuggestions(String query) async {
    try {
      final suggestions = await ProductionAlgoliaService.instance
          .getIntelligentSuggestions(query, maxSuggestions: 8);
      
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty && _searchFocusNode.hasFocus;
        });
      }
    } catch (e) {
      debugPrint('Failed to get suggestions: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showSuggestions = false;
    });

    // Add haptic feedback
    HapticFeedback.lightImpact();

    final startTime = DateTime.now();

    try {
      final results = await ProductionAlgoliaService.instance.universalSearch(
        query,
        filters: _filters,
        hitsPerPage: 20,
        enablePersonalization: true,
        enableAnalytics: true,
      );

      final endTime = DateTime.now();
      final searchTime = endTime.difference(startTime).inMilliseconds;

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
          _lastSearchTime = searchTime;
          _totalSearches++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Search failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _onSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _searchFocusNode.unfocus();
    _performSearch(suggestion);
  }

  void _onFiltersChanged(SearchFilterModel newFilters) {
    setState(() {
      _filters = newFilters;
    });
    
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchHeader(),
        if (_showSuggestions && _suggestions.isNotEmpty)
          _buildSuggestions(),
        if (_isLoading)
          _buildLoadingIndicator(),
        if (_errorMessage != null)
          _buildErrorMessage(),
        if (_searchResults != null)
          _buildSearchResults(),
        if (_searchResults == null && !_isLoading && _errorMessage == null)
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSearchBar(),
          if (_lastSearchTime > 0)
            _buildSearchMetrics(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onSubmitted: _performSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search with lightning speed...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(
            Icons.search,
            color: _searchFocusNode.hasFocus 
                ? AppTheme.primaryColor 
                : Colors.grey[500],
          ),
          suffixIcon: _buildSuffixIcons(),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget? _buildSuffixIcons() {
    final icons = <Widget>[];

    if (_searchController.text.isNotEmpty) {
      icons.add(
        IconButton(
          onPressed: () {
            _searchController.clear();
            setState(() {
              _searchResults = null;
              _suggestions.clear();
              _showSuggestions = false;
            });
          },
          icon: Icon(Icons.clear, color: Colors.grey[500], size: 20),
          tooltip: 'Clear search',
        ),
      );
    }

    if (widget.enableVoiceSearch) {
      icons.add(
        IconButton(
          onPressed: () {
            // Voice search implementation would go here
            HapticFeedback.lightImpact();
          },
          icon: Icon(Icons.mic, color: Colors.grey[500], size: 20),
          tooltip: 'Voice search',
        ),
      );
    }

    if (icons.isEmpty) return null;
    if (icons.length == 1) return icons.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons,
    );
  }

  Widget _buildSearchMetrics() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flash_on,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            'Search completed in ${_lastSearchTime}ms',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_totalSearches > 1) ...[
            const SizedBox(width: 8),
            Text(
              '• ${_totalSearches} searches',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _suggestions.asMap().entries.map((entry) {
          final index = entry.key;
          final suggestion = entry.value;
          
          return InkWell(
            onTap: () => _onSuggestionTap(suggestion),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: index < _suggestions.length - 1
                    ? Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  Icon(Icons.north_west, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching at lightning speed...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => _performSearch(_searchController.text.trim()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults!.isEmpty) {
      return _buildNoResults();
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults!.allHits.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildResultsHeader();
          }

          final hit = _searchResults!.allHits[index - 1];
          return _buildResultItem(hit, index - 1);
        },
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Found ${_searchResults!.totalHits} results for "${_searchResults!.query}"',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${_lastSearchTime}ms',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(SearchHitModel hit, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => widget.onResultTap?.call(hit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildResultTypeIcon(hit),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hit.title ?? hit.name ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              if (hit.content != null || hit.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  hit.content ?? hit.description ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultTypeIcon(SearchHitModel hit) {
    IconData icon;
    Color color;

    switch (hit.type) {
      case 'post':
        icon = Icons.article;
        color = Colors.blue;
        break;
      case 'user':
        icon = Icons.person;
        color = Colors.green;
        break;
      case 'news':
        icon = Icons.newspaper;
        color = Colors.orange;
        break;
      case 'legal_case':
        icon = Icons.gavel;
        color = Colors.red;
        break;
      default:
        icon = Icons.description;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or check your spelling',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flash_on, size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Lightning-fast search',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search across all content with sub-millisecond speed',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


