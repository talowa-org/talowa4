// Search Suggestions Widget for TALOWA
// Requirements: 4.4, 4.5, 4.6
// Task: Display search suggestions and search history

import 'package:flutter/material.dart';

/// Widget to display search suggestions
class SearchSuggestionsWidget extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionSelected;

  const SearchSuggestionsWidget({
    Key? key,
    required this.suggestions,
    required this.onSuggestionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Suggestions',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Suggestions list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return _buildSuggestionTile(context, suggestion);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(BuildContext context, String suggestion) {
    return ListTile(
      dense: true,
      leading: Icon(
        _getSuggestionIcon(suggestion),
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        suggestion,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onTap: () => onSuggestionSelected(suggestion),
      trailing: Icon(
        Icons.north_west,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  IconData _getSuggestionIcon(String suggestion) {
    final lowerSuggestion = suggestion.toLowerCase();
    
    if (lowerSuggestion.contains('from') || lowerSuggestion.contains('by')) {
      return Icons.person;
    } else if (lowerSuggestion.contains('image') || lowerSuggestion.contains('photo')) {
      return Icons.image;
    } else if (lowerSuggestion.contains('document') || lowerSuggestion.contains('file')) {
      return Icons.description;
    } else if (lowerSuggestion.contains('today') || lowerSuggestion.contains('week')) {
      return Icons.calendar_today;
    } else {
      return Icons.search;
    }
  }
}