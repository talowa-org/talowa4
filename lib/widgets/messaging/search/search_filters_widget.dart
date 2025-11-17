// Search Filters Widget for TALOWA
// Requirements: 4.3, 4.4
// Task: Advanced filtering options for search functionality

import 'package:flutter/material.dart';
import '../../../models/messaging/message_model.dart';
import '../../../services/messaging/messaging_search_service.dart';

enum SearchMode { users, messages }

/// Widget for advanced search filters
class SearchFiltersWidget extends StatefulWidget {
  final SearchMode mode;
  final UserSearchFilters? userFilters;
  final MessageSearchFilters? messageFilters;
  final Function(UserSearchFilters?)? onUserFiltersChanged;
  final Function(MessageSearchFilters?)? onMessageFiltersChanged;

  const SearchFiltersWidget({
    super.key,
    required this.mode,
    this.userFilters,
    this.messageFilters,
    this.onUserFiltersChanged,
    this.onMessageFiltersChanged,
  });

  @override
  State<SearchFiltersWidget> createState() => _SearchFiltersWidgetState();
}

class _SearchFiltersWidgetState extends State<SearchFiltersWidget> {
  // User filter state
  List<String> _selectedRoles = [];
  List<String> _selectedLocations = [];
  bool _onlineOnly = false;
  bool _recentActivityOnly = false;

  // Message filter state
  List<MessageType> _selectedMessageTypes = [];
  List<String> _selectedSenderIds = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeDeleted = false;

  // Available options
  final List<String> _availableRoles = [
    'Admin',
    'Coordinator',
    'Volunteer',
    'Member',
    'Legal Advisor',
    'Community Leader',
  ];

  final List<String> _availableLocations = [
    'Telangana',
    'Hyderabad',
    'Warangal',
    'Nizamabad',
    'Karimnagar',
    'Khammam',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  void _initializeFilters() {
    if (widget.mode == SearchMode.users && widget.userFilters != null) {
      _selectedRoles = widget.userFilters!.roles ?? [];
      _selectedLocations = widget.userFilters!.locations ?? [];
      _onlineOnly = widget.userFilters!.onlineOnly ?? false;
      _recentActivityOnly = widget.userFilters!.recentActivityOnly ?? false;
    } else if (widget.mode == SearchMode.messages && widget.messageFilters != null) {
      _selectedMessageTypes = widget.messageFilters!.messageTypes ?? [];
      _selectedSenderIds = widget.messageFilters!.senderIds ?? [];
      _startDate = widget.messageFilters!.startDate;
      _endDate = widget.messageFilters!.endDate;
      _includeDeleted = widget.messageFilters!.includeDeleted;
    }
  }

  void _updateUserFilters() {
    final filters = UserSearchFilters(
      roles: _selectedRoles.isEmpty ? null : _selectedRoles,
      locations: _selectedLocations.isEmpty ? null : _selectedLocations,
      onlineOnly: _onlineOnly ? true : null,
      recentActivityOnly: _recentActivityOnly ? true : null,
    );

    widget.onUserFiltersChanged?.call(
      _hasActiveUserFilters() ? filters : null,
    );
  }

  void _updateMessageFilters() {
    final filters = MessageSearchFilters(
      messageTypes: _selectedMessageTypes.isEmpty ? null : _selectedMessageTypes,
      senderIds: _selectedSenderIds.isEmpty ? null : _selectedSenderIds,
      startDate: _startDate,
      endDate: _endDate,
      includeDeleted: _includeDeleted,
    );

    widget.onMessageFiltersChanged?.call(
      _hasActiveMessageFilters() ? filters : null,
    );
  }

  bool _hasActiveUserFilters() {
    return _selectedRoles.isNotEmpty ||
           _selectedLocations.isNotEmpty ||
           _onlineOnly ||
           _recentActivityOnly;
  }

  bool _hasActiveMessageFilters() {
    return _selectedMessageTypes.isNotEmpty ||
           _selectedSenderIds.isNotEmpty ||
           _startDate != null ||
           _endDate != null ||
           _includeDeleted;
  }

  void _clearAllFilters() {
    setState(() {
      // Clear user filters
      _selectedRoles.clear();
      _selectedLocations.clear();
      _onlineOnly = false;
      _recentActivityOnly = false;

      // Clear message filters
      _selectedMessageTypes.clear();
      _selectedSenderIds.clear();
      _startDate = null;
      _endDate = null;
      _includeDeleted = false;
    });

    if (widget.mode == SearchMode.users) {
      widget.onUserFiltersChanged?.call(null);
    } else {
      widget.onMessageFiltersChanged?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        children: [
          // Filter header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_hasActiveFilters())
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: const Text('Clear All'),
                  ),
              ],
            ),
          ),

          // Filter content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: widget.mode == SearchMode.users
                ? _buildUserFilters()
                : _buildMessageFilters(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role filter
        _buildFilterSection(
          title: 'User Roles',
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableRoles.map((role) {
              final isSelected = _selectedRoles.contains(role);
              return FilterChip(
                label: Text(role),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedRoles.add(role);
                    } else {
                      _selectedRoles.remove(role);
                    }
                  });
                  _updateUserFilters();
                },
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Location filter
        _buildFilterSection(
          title: 'Locations',
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableLocations.map((location) {
              final isSelected = _selectedLocations.contains(location);
              return FilterChip(
                label: Text(location),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedLocations.add(location);
                    } else {
                      _selectedLocations.remove(location);
                    }
                  });
                  _updateUserFilters();
                },
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Activity filters
        _buildFilterSection(
          title: 'Activity Status',
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text('Online users only'),
                subtitle: const Text('Users active in the last 24 hours'),
                value: _onlineOnly,
                onChanged: (value) {
                  setState(() {
                    _onlineOnly = value ?? false;
                  });
                  _updateUserFilters();
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Recently active'),
                subtitle: const Text('Users active in the last 7 days'),
                value: _recentActivityOnly,
                onChanged: (value) {
                  setState(() {
                    _recentActivityOnly = value ?? false;
                  });
                  _updateUserFilters();
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message type filter
        _buildFilterSection(
          title: 'Message Types',
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: MessageType.values.map((type) {
              final isSelected = _selectedMessageTypes.contains(type);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getMessageTypeIcon(type),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(type.displayName),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedMessageTypes.add(type);
                    } else {
                      _selectedMessageTypes.remove(type);
                    }
                  });
                  _updateMessageFilters();
                },
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Date range filter
        _buildFilterSection(
          title: 'Date Range',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDateSelector(
                      label: 'From',
                      date: _startDate,
                      onDateSelected: (date) {
                        setState(() {
                          _startDate = date;
                        });
                        _updateMessageFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateSelector(
                      label: 'To',
                      date: _endDate,
                      onDateSelected: (date) {
                        setState(() {
                          _endDate = date;
                        });
                        _updateMessageFilters();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuickDateButton('Today', () {
                    final now = DateTime.now();
                    setState(() {
                      _startDate = DateTime(now.year, now.month, now.day);
                      _endDate = now;
                    });
                    _updateMessageFilters();
                  }),
                  const SizedBox(width: 8),
                  _buildQuickDateButton('This Week', () {
                    final now = DateTime.now();
                    final weekStart = now.subtract(Duration(days: now.weekday - 1));
                    setState(() {
                      _startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
                      _endDate = now;
                    });
                    _updateMessageFilters();
                  }),
                  const SizedBox(width: 8),
                  _buildQuickDateButton('This Month', () {
                    final now = DateTime.now();
                    setState(() {
                      _startDate = DateTime(now.year, now.month, 1);
                      _endDate = now;
                    });
                    _updateMessageFilters();
                  }),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Additional options
        _buildFilterSection(
          title: 'Options',
          child: CheckboxListTile(
            title: const Text('Include deleted messages'),
            subtitle: const Text('Show messages that have been deleted'),
            value: _includeDeleted,
            onChanged: (value) {
              setState(() {
                _includeDeleted = value ?? false;
              });
              _updateMessageFilters();
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? date,
    required Function(DateTime?) onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        onDateSelected(selectedDate);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Select date',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (date != null)
              InkWell(
                onTap: () => onDateSelected(null),
                child: Icon(
                  Icons.clear,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  IconData _getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.text:
        return Icons.text_fields;
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.audio:
        return Icons.mic;
      case MessageType.document:
        return Icons.description;
      case MessageType.location:
        return Icons.location_on;
      case MessageType.system:
        return Icons.settings;
      case MessageType.emergency:
        return Icons.warning;
    }
  }

  bool _hasActiveFilters() {
    return widget.mode == SearchMode.users
        ? _hasActiveUserFilters()
        : _hasActiveMessageFilters();
  }
}