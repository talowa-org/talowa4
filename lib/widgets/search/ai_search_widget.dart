// AI Search Widget - Natural language and semantic search interface
// Complete AI-powered search for TALOWA platform

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/search/search_result_model.dart';
import '../../services/search/ai_search_service.dart';

class AISearchWidget extends StatefulWidget {
  final String? initialQuery;
  final Function(SearchHitModel)? onResultTap;
  final Function(String)? onQueryChanged;

  const AISearchWidget({
    super.key,
    this.initialQuery,
    this.onResultTap,
    this.onQueryChanged,
  });

  @override
  State<AISearchWidget> createState() => _AISearchWidgetState();
}

class _AISearchWidgetState extends State<AISearchWidget>
    with TickerProviderStateMixin {
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  UniversalSearchResultModel? _searchResults;
  ProcessedQuery? _processedQuery;
  List<SmartRecommendation> _recommendations = [];
  
  bool _isLoading = false;
  bool _isProcessingNL = false;
  bool _showRecommendations = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performAISearch(widget.initialQuery!);
    } else {
      _loadRecommendations();
    }
    
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    
    if (widget.onQueryChanged != null) {
      widget.onQueryChanged!(query);
    }
    
    if (query.isEmpty) {
      setState(() {
        _showRecommendations = true;
      });
      _animationController.forward();
    } else {
      setState(() {
        _showRecommendations = false;
      });
      _animationController.reverse();
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() => _showRecommendations = true);
      _animationController.forward();
    }
  }

  Future<void> _performAISearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _isProcessingNL = true;
      _errorMessage = null;
      _showRecommendations = false;
    });

    HapticFeedback.lightImpact();

    try {
      // First, process the natural language query
      final processedQuery = await AISearchService.instance
          .processNaturalLanguageQuery(query);
      
      setState(() {
        _processedQuery = processedQuery;
        _isProcessingNL = false;
      });

      // Then perform semantic search
      final results = await AISearchService.instance.semanticSearch(
        query,
        hitsPerPage: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'AI search failed: ${e.toString()}';
          _isLoading = false;
          _isProcessingNL = false;
        });
      }
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final recommendations = await AISearchService.instance
          .generateSmartRecommendations(
        'current_user_id', // Replace with actual user ID
        userProfile: {
          'location': {'state': 'Bihar'},
          'profession': 'Farmer',
        },
      );

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _showRecommendations = true;
        });
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Failed to load recommendations: $e');
    }
  }

  void _onRecommendationTap(SmartRecommendation recommendation) {
    _searchController.text = recommendation.query;
    _performAISearch(recommendation.query);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAISearchHeader(),
        if (_isProcessingNL || _isLoading)
          _buildProcessingIndicator(),
        if (_processedQuery != null && !_isLoading)
          _buildQueryAnalysis(),
        if (_showRecommendations && _recommendations.isNotEmpty)
          _buildRecommendations(),
        if (_searchResults != null)
          _buildSearchResults(),
        if (_errorMessage != null)
          _buildErrorMessage(),
      ],
    );
  }

  Widget _buildAISearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Powered Search',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Ask in natural language',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNaturalLanguageSearchBar(),
        ],
      ),
    );
  }

  Widget _buildNaturalLanguageSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onSubmitted: _performAISearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Ask me anything... "Find a land lawyer in Bihar"',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.psychology,
              color: _searchFocusNode.hasFocus 
                  ? AppTheme.primaryColor 
                  : Colors.grey[500],
              size: 24,
            ),
          ),
          suffixIcon: _buildSearchActions(),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        maxLines: null,
      ),
    );
  }

  Widget? _buildSearchActions() {
    final actions = <Widget>[];

    if (_searchController.text.isNotEmpty) {
      actions.add(
        IconButton(
          onPressed: () {
            _searchController.clear();
            setState(() {
              _searchResults = null;
              _processedQuery = null;
              _showRecommendations = true;
            });
          },
          icon: Icon(Icons.clear, color: Colors.grey[500]),
          tooltip: 'Clear',
        ),
      );
    }

    actions.add(
      IconButton(
        onPressed: () => _performAISearch(_searchController.text),
        icon: Icon(
          Icons.search,
          color: AppTheme.primaryColor,
        ),
        tooltip: 'Search',
      ),
    );

    if (actions.length == 1) return actions.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  strokeWidth: 3,
                ),
              ),
              Icon(
                Icons.psychology,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isProcessingNL 
                ? 'Understanding your question...'
                : 'Searching with AI intelligence...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryAnalysis() {
    if (_processedQuery == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Understanding',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(_processedQuery!.confidence * 100).toInt()}% confident',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildIntentChip(_processedQuery!.intent),
            if (_processedQuery!.entities.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildEntitiesChips(_processedQuery!.entities),
            ],
            if (_processedQuery!.suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Related suggestions:',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildSuggestionsChips(_processedQuery!.suggestions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntentChip(String intent) {
    final intentLabels = {
      'find_lawyer': 'Looking for legal help',
      'land_dispute': 'Land dispute inquiry',
      'legal_documents': 'Legal document search',
      'government_schemes': 'Government scheme inquiry',
      'success_stories': 'Success story search',
      'general_search': 'General search',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            intentLabels[intent] ?? intent,
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntitiesChips(Map<String, List<String>> entities) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: entities.entries.expand((entry) {
        return entry.value.map((entity) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            entity,
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ));
      }).toList(),
    );
  }

  Widget _buildSuggestionsChips(List<String> suggestions) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: suggestions.take(3).map((suggestion) => GestureDetector(
        onTap: () {
          _searchController.text = suggestion;
          _performAISearch(suggestion);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Text(
            suggestion,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 11,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildRecommendations() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.recommend,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Smart Recommendations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recommendations.length,
              itemBuilder: (context, index) {
                final recommendation = _recommendations[index];
                return _buildRecommendationCard(recommendation);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(SmartRecommendation recommendation) {
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
        onTap: () => _onRecommendationTap(recommendation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendation.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults == null || _searchResults!.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Search Results (${_searchResults!.totalHits})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults!.allHits.length,
              itemBuilder: (context, index) {
                final hit = _searchResults!.allHits[index];
                return _buildResultCard(hit);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(SearchHitModel hit) {
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
              Text(
                hit.title ?? hit.name ?? 'Untitled',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            onPressed: () => _performAISearch(_searchController.text.trim()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}


