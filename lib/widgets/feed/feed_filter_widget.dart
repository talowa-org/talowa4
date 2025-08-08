// Feed Filter Widget - Filter and sort options for feed
// Part of Task 5: Create FeedScreen main interface

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/social_feed/index.dart';
import '../../screens/feed/feed_screen.dart';

class FeedFilterWidget extends StatelessWidget {
  final PostCategory? selectedCategory;
  final FeedSortOption sortOption;
  final bool showOnlyFollowing;
  final Function(PostCategory?) onCategoryChanged;
  final Function(FeedSortOption) onSortChanged;
  final Function(bool) onFollowingToggled;
  final VoidCallback onClearFilters;
  final bool isBottomSheet;

  const FeedFilterWidget({
    super.key,
    required this.selectedCategory,
    required this.sortOption,
    required this.showOnlyFollowing,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onFollowingToggled,
    required this.onClearFilters,
    this.isBottomSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isBottomSheet) {
      return _buildBottomSheetContent(context);
    } else {
      return _buildInlineContent(context);
    }
  }

  Widget _buildInlineContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active filters display
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 16,
                color: AppTheme.talowaGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Filters:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: _buildActiveFilterChips(context),
                ),
              ),
              TextButton(
                onPressed: onClearFilters,
                child: const Text('Clear All'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(BuildContext context) {
    return ListView(
      children: [
        // Category filter
        _buildFilterSection(
          context,
          'Category',
          Icons.category,
          _buildCategoryFilter(context),
        ),
        
        const Divider(),
        
        // Sort options
        _buildFilterSection(
          context,
          'Sort By',
          Icons.sort,
          _buildSortFilter(context),
        ),
        
        const Divider(),
        
        // Following toggle
        _buildFilterSection(
          context,
          'Content Source',
          Icons.people,
          _buildFollowingFilter(context),
        ),
      ],
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    String title,
    IconData icon,
    Widget content,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.talowaGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    return Column(
      children: [
        // All categories option
        RadioListTile<PostCategory?>(
          title: const Text('All Categories'),
          value: null,
          groupValue: selectedCategory,
          onChanged: onCategoryChanged,
          activeColor: AppTheme.talowaGreen,
        ),
        
        // Individual categories
        ...PostCategory.values.map((category) => RadioListTile<PostCategory?>(
          title: Row(
            children: [
              Icon(category.icon, size: 16),
              const SizedBox(width: 8),
              Text(category.displayName),
            ],
          ),
          subtitle: Text(
            category.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          value: category,
          groupValue: selectedCategory,
          onChanged: onCategoryChanged,
          activeColor: AppTheme.talowaGreen,
        )),
      ],
    );
  }

  Widget _buildSortFilter(BuildContext context) {
    return Column(
      children: FeedSortOption.values.map((option) => RadioListTile<FeedSortOption>(
        title: Text(option.displayName),
        subtitle: Text(_getSortDescription(option)),
        value: option,
        groupValue: sortOption,
        onChanged: onSortChanged,
        activeColor: AppTheme.talowaGreen,
      )).toList(),
    );
  }

  Widget _buildFollowingFilter(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Show only from people I follow'),
          subtitle: const Text('Filter posts from your network only'),
          value: showOnlyFollowing,
          onChanged: onFollowingToggled,
          activeColor: AppTheme.talowaGreen,
        ),
      ],
    );
  }

  List<Widget> _buildActiveFilterChips(BuildContext context) {
    final chips = <Widget>[];
    
    // Category chip
    if (selectedCategory != null) {
      chips.add(_buildFilterChip(
        context,
        selectedCategory!.displayName,
        selectedCategory!.icon,
        () => onCategoryChanged(null),
      ));
    }
    
    // Sort chip (only if not default)
    if (sortOption != FeedSortOption.newest) {
      chips.add(_buildFilterChip(
        context,
        sortOption.displayName,
        Icons.sort,
        () => onSortChanged(FeedSortOption.newest),
      ));
    }
    
    // Following chip
    if (showOnlyFollowing) {
      chips.add(_buildFilterChip(
        context,
        'Following Only',
        Icons.people,
        () => onFollowingToggled(false),
      ));
    }
    
    // Show "No filters" if empty
    if (chips.isEmpty) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'No active filters',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ));
    }
    
    return chips;
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onRemove,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        backgroundColor: AppTheme.talowaGreen.withOpacity(0.1),
        deleteIconColor: AppTheme.talowaGreen,
        side: BorderSide(color: AppTheme.talowaGreen.withOpacity(0.3)),
      ),
    );
  }

  String _getSortDescription(FeedSortOption option) {
    switch (option) {
      case FeedSortOption.newest:
        return 'Show most recent posts first';
      case FeedSortOption.oldest:
        return 'Show oldest posts first';
      case FeedSortOption.mostLiked:
        return 'Show posts with most likes first';
      case FeedSortOption.mostCommented:
        return 'Show posts with most comments first';
      case FeedSortOption.trending:
        return 'Show trending posts based on engagement';
    }
  }
}