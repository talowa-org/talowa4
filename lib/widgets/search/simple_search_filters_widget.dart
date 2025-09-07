// Simple Search Filters Widget - Streamlined search filtering
// Complete search filters for TALOWA platform

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/search/search_filter_model.dart';

class SimpleSearchFiltersWidget extends StatefulWidget {
  final SearchFilterModel filters;
  final Function(SearchFilterModel) onFiltersChanged;

  const SimpleSearchFiltersWidget({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  State<SimpleSearchFiltersWidget> createState() => _SimpleSearchFiltersWidgetState();
}

class _SimpleSearchFiltersWidgetState extends State<SimpleSearchFiltersWidget> {
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

  Widget _buildLocationFilter() {
    final hasLocation = _currentFilters.location?.states?.isNotEmpty ?? false;
    return FilterChip(
      label: Text(hasLocation ? 'Location' : 'Location'),
      selected: hasLocation,
      onSelected: (selected) {
        if (selected) {
          _showLocationDialog();
        } else {
          _updateFilters(_currentFilters.copyWith(location: null));
        }
      },
      avatar: const Icon(Icons.location_on, size: 16),
      backgroundColor: hasLocation ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
    );
  }

  Widget _buildDateFilter() {
    final hasDateRange = _currentFilters.dateRange != null;
    return FilterChip(
      label: Text(hasDateRange ? 'Date Range' : 'Date'),
      selected: hasDateRange,
      onSelected: (selected) {
        if (selected) {
          _showDateDialog();
        } else {
          _updateFilters(_currentFilters.copyWith(dateRange: null));
        }
      },
      avatar: const Icon(Icons.date_range, size: 16),
      backgroundColor: hasDateRange ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
    );
  }

  Widget _buildClearFiltersButton() {
    final hasAnyFilters = _currentFilters.isNotEmpty;
    
    if (!hasAnyFilters) return const SizedBox.shrink();

    return ActionChip(
      label: const Text('Clear All'),
      onPressed: () {
        _updateFilters(const SearchFilterModel());
      },
      avatar: const Icon(Icons.clear, size: 16),
      backgroundColor: Colors.red.withValues(alpha: 0.1),
      labelStyle: const TextStyle(color: Colors.red),
    );
  }

  void _updateFilters(SearchFilterModel newFilters) {
    setState(() {
      _currentFilters = newFilters;
    });
    widget.onFiltersChanged(newFilters);
  }

  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => _CategoryFilterDialog(
        selectedCategories: _currentFilters.categories ?? [],
        onCategoriesChanged: (categories) {
          _updateFilters(_currentFilters.copyWith(categories: categories));
        },
      ),
    );
  }

  void _showTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => _TypeFilterDialog(
        selectedTypes: _currentFilters.types ?? [],
        onTypesChanged: (types) {
          _updateFilters(_currentFilters.copyWith(types: types));
        },
      ),
    );
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => _LocationFilterDialog(
        currentLocation: _currentFilters.location,
        onLocationChanged: (location) {
          _updateFilters(_currentFilters.copyWith(location: location));
        },
      ),
    );
  }

  void _showDateDialog() {
    showDialog(
      context: context,
      builder: (context) => _DateFilterDialog(
        currentDateRange: _currentFilters.dateRange,
        onDateRangeChanged: (dateRange) {
          _updateFilters(_currentFilters.copyWith(dateRange: dateRange));
        },
      ),
    );
  }
}

// Category Filter Dialog
class _CategoryFilterDialog extends StatefulWidget {
  final List<String> selectedCategories;
  final Function(List<String>) onCategoriesChanged;

  const _CategoryFilterDialog({
    required this.selectedCategories,
    required this.onCategoriesChanged,
  });

  @override
  State<_CategoryFilterDialog> createState() => _CategoryFilterDialogState();
}

class _CategoryFilterDialogState extends State<_CategoryFilterDialog> {
  late List<String> _selectedCategories;

  final List<String> _availableCategories = [
    'Land Rights',
    'Legal Cases',
    'Success Stories',
    'Government Policies',
    'Community News',
    'Activism',
    'Education',
    'Resources',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategories = List.from(widget.selectedCategories);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Categories'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _availableCategories.length,
          itemBuilder: (context, index) {
            final category = _availableCategories[index];
            final isSelected = _selectedCategories.contains(category);

            return CheckboxListTile(
              title: Text(category),
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
              },
              activeColor: AppTheme.primaryColor,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onCategoriesChanged(_selectedCategories);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// Type Filter Dialog
class _TypeFilterDialog extends StatefulWidget {
  final List<String> selectedTypes;
  final Function(List<String>) onTypesChanged;

  const _TypeFilterDialog({
    required this.selectedTypes,
    required this.onTypesChanged,
  });

  @override
  State<_TypeFilterDialog> createState() => _TypeFilterDialogState();
}

class _TypeFilterDialogState extends State<_TypeFilterDialog> {
  late List<String> _selectedTypes;

  final List<String> _availableTypes = [
    'post',
    'user',
    'news',
    'legal_case',
    'organization',
    'campaign',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTypes = List.from(widget.selectedTypes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Content Types'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _availableTypes.length,
          itemBuilder: (context, index) {
            final type = _availableTypes[index];
            final isSelected = _selectedTypes.contains(type);

            return CheckboxListTile(
              title: Text(_getTypeDisplayName(type)),
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedTypes.add(type);
                  } else {
                    _selectedTypes.remove(type);
                  }
                });
              },
              activeColor: AppTheme.primaryColor,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onTypesChanged(_selectedTypes);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'post':
        return 'Posts';
      case 'user':
        return 'People';
      case 'news':
        return 'News';
      case 'legal_case':
        return 'Legal Cases';
      case 'organization':
        return 'Organizations';
      case 'campaign':
        return 'Campaigns';
      default:
        return type;
    }
  }
}

// Location Filter Dialog (simplified)
class _LocationFilterDialog extends StatelessWidget {
  final LocationFilter? currentLocation;
  final Function(LocationFilter?) onLocationChanged;

  const _LocationFilterDialog({
    required this.currentLocation,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Location Filter'),
      content: const Text('Location filtering will be implemented with state/district selection.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // For now, just close the dialog
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// Date Filter Dialog (simplified)
class _DateFilterDialog extends StatelessWidget {
  final DateRangeFilter? currentDateRange;
  final Function(DateRangeFilter?) onDateRangeChanged;

  const _DateFilterDialog({
    required this.currentDateRange,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Date Range Filter'),
      content: const Text('Date range filtering will be implemented with date pickers.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // For now, just close the dialog
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

