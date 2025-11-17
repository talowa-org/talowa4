// User Search Results Widget for TALOWA
// Requirements: 4.1, 4.2, 4.4, 4.5
// Task: Display user search results with highlighting and navigation

import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/messaging/messaging_search_service.dart';

/// Widget to display user search results
class UserSearchResultsWidget extends StatelessWidget {
  final UserSearchResult? result;
  final String searchQuery;
  final Function(UserModel)? onUserSelected;

  const UserSearchResultsWidget({
    super.key,
    required this.result,
    required this.searchQuery,
    this.onUserSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const SizedBox.shrink();
    }

    if (result!.error != null) {
      return _buildErrorState(context);
    }

    if (result!.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        _buildResultsHeader(context),
        Expanded(
          child: _buildResultsList(context),
        ),
      ],
    );
  }

  Widget _buildResultsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '${result!.totalResults} user${result!.totalResults == 1 ? '' : 's'} found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (result!.appliedFilters != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.filter_list,
              size: 14,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context) {
    return ListView.builder(
      itemCount: result!.users.length + (result!.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == result!.users.length) {
          return _buildLoadMoreButton(context);
        }

        final user = result!.users[index];
        return _buildUserTile(context, user);
      },
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _buildUserAvatar(user),
        title: _buildHighlightedText(
          context,
          user.fullName,
          searchQuery,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHighlightedText(
              context,
              user.phoneNumber,
              searchQuery,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _buildRoleChip(context, user.role),
                const SizedBox(width: 8),
                _buildLocationText(context, user),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOnlineIndicator(context, user),
            const SizedBox(height: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        onTap: () => onUserSelected?.call(user),
      ),
    );
  }

  Widget _buildUserAvatar(UserModel user) {
    return CircleAvatar(
      child: Text(
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRoleChip(BuildContext context, String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getRoleColor(role).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getRoleColor(role).withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        role,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _getRoleColor(role),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLocationText(BuildContext context, UserModel user) {
    final location = '${user.address.villageCity}, ${user.address.district}';
    return Expanded(
      child: _buildHighlightedText(
        context,
        location,
        searchQuery,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildOnlineIndicator(BuildContext context, UserModel user) {
    final isRecentlyActive = user.lastLoginAt != null && DateTime.now()
        .difference(user.lastLoginAt!)
        .inHours < 24;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isRecentlyActive ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    String query, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final searchService = MessagingSearchService();
    final highlights = searchService.getSearchHighlights(text, query);

    if (highlights.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final highlight in highlights) {
      // Add text before highlight
      if (highlight.startIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, highlight.startIndex),
          style: style,
        ));
      }

      // Add highlighted text
      spans.add(TextSpan(
        text: highlight.matchedText,
        style: style?.copyWith(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      lastIndex = highlight.endIndex;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  Widget _buildLoadMoreButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          // TODO: Implement load more functionality
        },
        child: const Text('Load More Users'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final searchService = MessagingSearchService();
    final emptyMessage = searchService.getEmptyStateMessage(searchQuery, isUserSearch: true);
    final suggestions = searchService.getEmptyStateSuggestions();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              emptyMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ...suggestions.map((suggestion) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Search Error',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result!.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement retry functionality
              },
              child: const Text('Retry Search'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'coordinator':
        return Colors.blue;
      case 'volunteer':
        return Colors.green;
      case 'member':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}