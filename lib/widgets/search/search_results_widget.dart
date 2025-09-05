// Search Results Widget - Display search results with different layouts
// Complete search results display for TALOWA platform

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/search/search_result_model.dart';
import '../../widgets/common/loading_widget.dart';

class SearchResultsWidget extends StatefulWidget {
  final UniversalSearchResultModel results;
  final bool showAllTypes;
  final String? filterByIndex;
  final Function(SearchHitModel)? onResultTap;
  final Function(SearchHitModel)? onResultLongPress;

  const SearchResultsWidget({
    super.key,
    required this.results,
    this.showAllTypes = false,
    this.filterByIndex,
    this.onResultTap,
    this.onResultLongPress,
  });

  @override
  State<SearchResultsWidget> createState() => _SearchResultsWidgetState();
}

class _SearchResultsWidgetState extends State<SearchResultsWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return _buildEmptyState();
    }

    return _buildResultsList();
  }

  Widget _buildEmptyState() {
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
            'No results found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms or filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    final hits = _getFilteredHits();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: hits.length + 1, // +1 for results summary
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildResultsSummary(hits.length);
        }

        final hit = hits[index - 1];
        return _buildResultItem(hit);
      },
    );
  }

  List<SearchHitModel> _getFilteredHits() {
    if (widget.showAllTypes) {
      return widget.results.allHits;
    }

    if (widget.filterByIndex != null) {
      return widget.results.getHitsByIndex(widget.filterByIndex!);
    }

    return widget.results.allHits;
  }

  Widget _buildResultsSummary(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Found $count results for "${widget.results.query}"',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${widget.results.processingTimeMS}ms',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(SearchHitModel hit) {
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
        onLongPress: () => widget.onResultLongPress?.call(hit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultHeader(hit),
              const SizedBox(height: 8),
              _buildResultContent(hit),
              if (_shouldShowMetadata(hit)) ...[
                const SizedBox(height: 12),
                _buildResultMetadata(hit),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(SearchHitModel hit) {
    return Row(
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
        if (hit.createdAt != null)
          Text(
            _formatDate(hit.createdAt!),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
      ],
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
      case 'organization':
        icon = Icons.business;
        color = Colors.purple;
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
      child: Icon(
        icon,
        size: 16,
        color: color,
      ),
    );
  }

  Widget _buildResultContent(SearchHitModel hit) {
    final content = hit.content ?? hit.description ?? '';
    
    if (content.isEmpty) return const SizedBox.shrink();

    return Text(
      content,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[700],
        height: 1.4,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  bool _shouldShowMetadata(SearchHitModel hit) {
    return hit.authorName != null || 
           hit.location != null || 
           hit.tags != null && hit.tags!.isNotEmpty;
  }

  Widget _buildResultMetadata(SearchHitModel hit) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (hit.authorName != null)
          _buildMetadataChip(
            icon: Icons.person,
            label: hit.authorName!,
            color: Colors.blue,
          ),
        if (hit.state != null)
          _buildMetadataChip(
            icon: Icons.location_on,
            label: hit.state!,
            color: Colors.green,
          ),
        if (hit.category != null)
          _buildMetadataChip(
            icon: Icons.category,
            label: hit.category!,
            color: Colors.orange,
          ),
        if (hit.tags != null && hit.tags!.isNotEmpty)
          ...hit.tags!.take(2).map((tag) => _buildMetadataChip(
            icon: Icons.tag,
            label: tag,
            color: Colors.purple,
          )),
      ],
    );
  }

  Widget _buildMetadataChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}


