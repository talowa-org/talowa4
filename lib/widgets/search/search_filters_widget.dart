// Search Filters Widget for TALOWA
// Implements Task 24: Add advanced search and discovery - Search Filters

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/search/search_filter_model.dart';

class SearchFiltersWidget extends StatefulWidget {
  final SearchFilterModel filters;
  final Function(SearchFilterModel) onFiltersChanged;

  const SearchFiltersWidget({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  State<SearchFiltersWidget> createState() => _SearchFiltersWidgetState();
}

class _SearchFiltersWidgetState extends State<SearchFiltersWidget> {
  late SearchFilterModel _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.filters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCategoryFilter(),
            const SizedBox(width: 8),
            _buildTypeFilter(),
            const SizedBox(width: 8),
            _buildLocationFilter(),
            const SizedBox(width: 8),
            _buildDateFilter(),
            const SizedBox(width: 8),
            _buildClearFiltersButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final hasCategories = _currentFilters.categories?.isNotEmpty ?? false;
    return FilterChip(
      label: Text(hasCategories ? 'Categories (${_currentFilters.categories!.length})' : 'Categories'),
      selected: hasCategories,
      onSelected: (selected) {
        if (selected) {
          _showCategoryDialog();
        } else {
          _updateFilters(_currentFilters.copyWith(categories: []));
        }
      },
      avatar: const Icon(Icons.category, size: 16),
      backgroundColor: hasCategories ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
    );
  }

  Widget _buildTypeFilter() {
    final hasTypes = _currentFilters.types?.isNotEmpty ?? false;
    return FilterChip(
      label: Text(hasTypes ? 'Types (${_currentFilters.types!.length})' : 'Types'),
      selected: hasTypes,
      onSelected: (selected) {
        if (selected) {
          _showTypeDialog();
        } else {
          _updateFilters(_currentFilters.copyWith(types: []));
        }
      },
      avatar: const Icon(Icons.filter_list, size: 16),
      backgroundColor: hasTypes ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
    );
  }

  Widget _buildDateFilter() {
    String label = 'Date';
    final hasStart = _currentFilters.dateRange?.startDate != null;
    final hasEnd = _currentFilters.dateRange?.endDate != null;
    if (hasStart || hasEnd) {
      if (hasStart && hasEnd) {
        label = 'Custom Range';
      } else if (hasStart) {
        label = 'Since ${_formatDate(_currentFilters.dateRange!.startDate!)}';
      } else {
        label = 'Until ${_formatDate(_currentFilters.dateRange!.endDate!)}';
      }
    }

    return FilterChip(
      label: Text(label),
      selected: _currentFilters.dateRange != null,
      onSelected: (selected) {
        if (selected) {
          _showDateDialog();
        } else {
          _updateFilters(_currentFilters.copyWith(dateRange: null));
        }
      },
      avatar: const Icon(Icons.date_range, size: 16),
    );
  }

  Widget _buildLocationFilter() {
    final hasLocation = _currentFilters.location != null;
    return FilterChip(
      label: Text('Location'),
      selected: hasLocation,
      onSelected: (selected) {
        if (selected) {
          _showLocationDialog();
        } else {
          _updateFilters(_currentFilters.copyWith(location: null));
        }
      },
      avatar: const Icon(Icons.location_on, size: 16),
    );
  }

  Widget _buildAuthorFilter() {
    final authorNames = _currentFilters.author?.authorNames;
    final labelText = (authorNames != null && authorNames.isNotEmpty) ? authorNames.first : 'Author';
    return FilterChip(
      label: Text(labelText),
      selected: _currentFilters.author != null,
      onSelected: (selected) {
        if (selected) {
          _showAuthorDialog();
        } else {
          _updateFilters(_currentFilters.copyWith(author: null));
        }
      },
      avatar: const Icon(Icons.person, size: 16),
    );
  }

  Widget _buildClearFiltersButton() {
    final hasFilters = (_currentFilters.categories?.isNotEmpty ?? false) ||
        (_currentFilters.types?.isNotEmpty ?? false) ||
        (_currentFilters.statuses?.isNotEmpty ?? false) ||
        _currentFilters.location != null ||
        _currentFilters.dateRange != null ||
        (_currentFilters.tags?.isNotEmpty ?? false) ||
        _currentFilters.priority != null ||
        _currentFilters.author != null ||
        _currentFilters.rating != null ||
        (_currentFilters.customFilters?.isNotEmpty ?? false);

    if (!hasFilters) return const SizedBox.shrink();

    return ActionChip(
      label: const Text('Clear All'),
      onPressed: () {
        _updateFilters(const SearchFilterModel());
      },
      avatar: const Icon(Icons.clear, size: 16),
      backgroundColor: Colors.red.withValues(alpha: 0.1),
    );
  }

  void _showCategoryDialog() {
    final categories = [
      'Land Rights',
      'Agriculture',
      'Legal Updates',
      'Success Stories',
      'Government Schemes',
      'Community News',
      'Education',
      'Health',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: categories.map((category) {
              return RadioListTile<String>(
                title: Text(category),
                value: category,
                groupValue: (_currentFilters.categories?.isNotEmpty ?? false) ? _currentFilters.categories!.first : null,
                onChanged: (value) {
                  Navigator.pop(context);
                  _updateFilters(_currentFilters.copyWith(categories: value == null ? [] : [value]));
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Today'),
              onTap: () {
                Navigator.pop(context);
                final today = DateTime.now();
                final startOfDay = DateTime(today.year, today.month, today.day);
                _updateFilters(_currentFilters.copyWith(
                  dateRange: DateRangeFilter(startDate: startOfDay, endDate: today),
                ));
              },
            ),
            ListTile(
              title: const Text('This Week'),
              onTap: () {
                Navigator.pop(context);
                final now = DateTime.now();
                final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                _updateFilters(_currentFilters.copyWith(
                  dateRange: DateRangeFilter(startDate: startOfWeek, endDate: now),
                ));
              },
            ),
            ListTile(
              title: const Text('This Month'),
              onTap: () {
                Navigator.pop(context);
                final now = DateTime.now();
                final startOfMonth = DateTime(now.year, now.month, 1);
                _updateFilters(_currentFilters.copyWith(
                  dateRange: DateRangeFilter(startDate: startOfMonth, endDate: now),
                ));
              },
            ),
            ListTile(
              title: const Text('Custom Range'),
              onTap: () {
                Navigator.pop(context);
                _showDateRangePicker();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: (_currentFilters.dateRange?.startDate != null && _currentFilters.dateRange?.endDate != null)
          ? DateTimeRange(
              start: _currentFilters.dateRange!.startDate!,
              end: _currentFilters.dateRange!.endDate!,
            )
          : null,
    );

    if (picked != null) {
      _updateFilters(_currentFilters.copyWith(
        dateRange: DateRangeFilter(startDate: picked.start, endDate: picked.end),
      ));
    }
  }

  void _showLocationDialog() {
    final locations = [
      'Telangana',
      'Andhra Pradesh',
      'Karnataka',
      'Tamil Nadu',
      'Maharashtra',
      'Kerala',
      'Odisha',
      'West Bengal',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: locations.map((location) {
              return RadioListTile<String>(
                title: Text(location),
                value: location,
                groupValue: (_currentFilters.location?.states?.isNotEmpty ?? false) ? _currentFilters.location!.states!.first : null,
                onChanged: (value) {
                  Navigator.pop(context);
                  _updateFilters(_currentFilters.copyWith(location: value == null ? null : LocationFilter(states: [value])));
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAuthorDialog() {
    final controller = TextEditingController(text: _currentFilters.author ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Author'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Author name',
            hintText: 'Enter author name...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final author = controller.text.trim();
              _updateFilters(_currentFilters.copyWith(
                author: author.isEmpty ? null : AuthorFilter(authorNames: [author]),
              ));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _updateFilters(SearchFilterModel newFilters) {
    setState(() {
      _currentFilters = newFilters;
    });
    widget.onFiltersChanged(newFilters);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }
}

class AdvancedSearchFiltersDialog extends StatefulWidget {
  final SearchFilterModel initialFilters;
  final Function(SearchFilterModel) onFiltersApplied;

  const AdvancedSearchFiltersDialog({
    super.key,
    required this.initialFilters,
    required this.onFiltersApplied,
  });

  @override
  State<AdvancedSearchFiltersDialog> createState() => _AdvancedSearchFiltersDialogState();
}

class _AdvancedSearchFiltersDialogState extends State<AdvancedSearchFiltersDialog> {
  late SearchFilterModel _filters;
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _authorController.text = _filters.author?.authorNames?.join(', ') ?? '';
    _hashtagController.text = _filters.tags?.join(', ') ?? '';
  }

  @override
  void dispose() {
    _authorController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Advanced Search Filters'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategorySection(),
            const SizedBox(height: 16),
            _buildAuthorSection(),
            const SizedBox(height: 16),
            _buildDateSection(),
            const SizedBox(height: 16),
            _buildLocationSection(),
            const SizedBox(height: 16),
            _buildHashtagSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _clearAllFilters,
          child: const Text('Clear All'),
        ),
        ElevatedButton(
          onPressed: _applyFilters,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final categories = [
      'Land Rights',
      'Agriculture',
      'Legal Updates',
      'Success Stories',
      'Government Schemes',
      'Community News',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: categories.map((category) {
            return FilterChip(
              label: Text(category),
              selected: _filters.category == category,
              onSelected: (selected) {
                setState(() {
                  _filters = _filters.copyWith(
                    category: selected ? category : null,
                  );
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAuthorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Author',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _authorController,
          decoration: const InputDecoration(
            hintText: 'Enter author name...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _selectStartDate,
                child: Text(
                  _filters.dateRange?.startDate != null
                      ? 'From: ${_formatDate(_filters.dateRange!.startDate!)}'
                      : 'Start Date',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _selectEndDate,
                child: Text(
                  _filters.dateRange?.endDate != null
                      ? 'To: ${_formatDate(_filters.dateRange!.endDate!)}'
                      : 'End Date',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    final locations = [
      'Telangana',
      'Andhra Pradesh',
      'Karnataka',
      'Tamil Nadu',
      'Maharashtra',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: locations.map((location) {
            return FilterChip(
              label: Text(location),
              selected: (_filters.location?.states?.contains(location) ?? false),
              onSelected: (selected) {
                setState(() {
                  _filters = _filters.copyWith(
                    location: selected ? LocationFilter(states: [location]) : null,
                  );
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHashtagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hashtags',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hashtagController,
          decoration: const InputDecoration(
            hintText: 'Enter hashtags separated by commas...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _filters.dateRange?.startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        final existing = _filters.dateRange;
        _filters = _filters.copyWith(dateRange: DateRangeFilter(startDate: date, endDate: existing?.endDate));
      });
    }
  }

  void _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _filters.dateRange?.endDate ?? DateTime.now(),
      firstDate: _filters.dateRange?.startDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        final existing = _filters.dateRange;
        _filters = _filters.copyWith(dateRange: DateRangeFilter(startDate: existing?.startDate, endDate: date));
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _filters = const SearchFilterModel();
      _authorController.clear();
      _hashtagController.clear();
    });
  }

  void _applyFilters() {
    final author = _authorController.text.trim();
    final hashtagText = _hashtagController.text.trim();
    final hashtags = hashtagText.isNotEmpty
        ? hashtagText.split(',').map((h) => h.trim()).where((h) => h.isNotEmpty).toList()
        : null;

    final finalFilters = _filters.copyWith(
      author: author.isEmpty ? null : AuthorFilter(authorNames: [author]),
      tags: tags,
    );

    widget.onFiltersApplied(finalFilters);
    Navigator.pop(context);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
