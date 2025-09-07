// Search Bar Widget - Advanced search input with suggestions
// Complete search bar for TALOWA land rights platform

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmitted;
  final Function(String)? onChanged;
  final String hintText;
  final bool showVoiceSearch;
  final VoidCallback? onVoiceSearch;
  final bool showClearButton;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.onChanged,
    this.hintText = 'Search...',
    this.showVoiceSearch = true,
    this.onVoiceSearch,
    this.showClearButton = true,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  bool _isVoiceSearchActive = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.focusNode.hasFocus 
              ? AppTheme.primaryColor 
              : Colors.grey[300]!,
          width: widget.focusNode.hasFocus ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: widget.focusNode.hasFocus 
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
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget? _buildSuffixIcons() {
    final icons = <Widget>[];

    // Clear button
    if (widget.showClearButton && widget.controller.text.isNotEmpty) {
      icons.add(
        IconButton(
          onPressed: () {
            widget.controller.clear();
            if (widget.onChanged != null) {
              widget.onChanged!('');
            }
          },
          icon: Icon(
            Icons.clear,
            color: Colors.grey[500],
            size: 20,
          ),
          tooltip: 'Clear search',
        ),
      );
    }

    // Voice search button
    if (widget.showVoiceSearch) {
      icons.add(
        IconButton(
          onPressed: _isVoiceSearchActive ? null : _handleVoiceSearch,
          icon: Icon(
            _isVoiceSearchActive ? Icons.mic : Icons.mic_none,
            color: _isVoiceSearchActive 
                ? AppTheme.primaryColor 
                : Colors.grey[500],
            size: 20,
          ),
          tooltip: 'Voice search',
        ),
      );
    }

    if (icons.isEmpty) return null;

    if (icons.length == 1) {
      return icons.first;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons,
    );
  }

  void _handleVoiceSearch() {
    if (widget.onVoiceSearch != null) {
      setState(() => _isVoiceSearchActive = true);
      
      widget.onVoiceSearch!();
      
      // Reset voice search state after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isVoiceSearchActive = false);
        }
      });
    }
  }
}

// Search suggestions widget
class SearchSuggestionsWidget extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionTap;
  final int maxSuggestions;

  const SearchSuggestionsWidget({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
    this.maxSuggestions = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final displaySuggestions = suggestions.take(maxSuggestions).toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
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
        children: displaySuggestions.asMap().entries.map((entry) {
          final index = entry.key;
          final suggestion = entry.value;
          
          return InkWell(
            onTap: () => onSuggestionTap(suggestion),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: index < displaySuggestions.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.north_west,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Recent searches widget
class RecentSearchesWidget extends StatelessWidget {
  final List<String> recentSearches;
  final Function(String) onRecentSearchTap;
  final VoidCallback? onClearRecentSearches;

  const RecentSearchesWidget({
    super.key,
    required this.recentSearches,
    required this.onRecentSearchTap,
    this.onClearRecentSearches,
  });

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onClearRecentSearches != null)
                  TextButton(
                    onPressed: onClearRecentSearches,
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...recentSearches.take(5).map((search) {
            return InkWell(
              onTap: () => onRecentSearchTap(search),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        search,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

