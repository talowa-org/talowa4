// Geographic Discovery Widget - Discover content by location
// Part of Task 8: Create content discovery features

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/discovery/content_discovery_screen.dart';

class GeographicDiscoveryWidget extends StatelessWidget {
  final GeographicScope selectedScope;
  final Function(GeographicScope) onScopeChanged;

  const GeographicDiscoveryWidget({
    super.key,
    required this.selectedScope,
    required this.onScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discover Content Near You',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Text(
          'Find posts and updates from your local community',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingLarge),
        
        // Geographic scope selector
        _buildScopeSelector(context),
        
        const SizedBox(height: AppTheme.spacingLarge),
        
        // Location info card
        _buildLocationInfoCard(context),
      ],
    );
  }

  Widget _buildScopeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: GeographicScope.values.map((scope) {
          final isSelected = selectedScope == scope;
          return Expanded(
            child: GestureDetector(
              onTap: () => onScopeChanged(scope),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      _getScopeIcon(scope),
                      size: 20,
                      color: isSelected ? AppTheme.talowaGreen : Colors.grey[600],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scope.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppTheme.talowaGreen : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLocationInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.talowaGreen.withOpacity(0.1),
            AppTheme.talowaGreen.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.talowaGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.talowaGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getScopeIcon(selectedScope),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your ${selectedScope.displayName}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.talowaGreen,
                      ),
                    ),
                    Text(
                      _getMockLocationName(selectedScope),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.my_location,
                color: AppTheme.talowaGreen,
                size: 20,
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingMedium),
          
          // Statistics row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Active Users',
                  _getMockActiveUsers(selectedScope).toString(),
                  Icons.people,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Recent Posts',
                  _getMockRecentPosts(selectedScope).toString(),
                  Icons.article,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'This Week',
                  '+${_getMockWeeklyGrowth(selectedScope)}',
                  Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.talowaGreen,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.talowaGreen,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  IconData _getScopeIcon(GeographicScope scope) {
    switch (scope) {
      case GeographicScope.village:
        return Icons.home;
      case GeographicScope.mandal:
        return Icons.location_city;
      case GeographicScope.district:
        return Icons.domain;
      case GeographicScope.state:
        return Icons.map;
    }
  }

  String _getMockLocationName(GeographicScope scope) {
    switch (scope) {
      case GeographicScope.village:
        return 'Ramachandrapuram Village';
      case GeographicScope.mandal:
        return 'Ramachandrapuram Mandal';
      case GeographicScope.district:
        return 'East Godavari District';
      case GeographicScope.state:
        return 'Andhra Pradesh State';
    }
  }

  int _getMockActiveUsers(GeographicScope scope) {
    switch (scope) {
      case GeographicScope.village:
        return 156;
      case GeographicScope.mandal:
        return 1234;
      case GeographicScope.district:
        return 8567;
      case GeographicScope.state:
        return 45678;
    }
  }

  int _getMockRecentPosts(GeographicScope scope) {
    switch (scope) {
      case GeographicScope.village:
        return 23;
      case GeographicScope.mandal:
        return 89;
      case GeographicScope.district:
        return 234;
      case GeographicScope.state:
        return 567;
    }
  }

  int _getMockWeeklyGrowth(GeographicScope scope) {
    switch (scope) {
      case GeographicScope.village:
        return 12;
      case GeographicScope.mandal:
        return 34;
      case GeographicScope.district:
        return 78;
      case GeographicScope.state:
        return 156;
    }
  }
}
