import 'package:flutter/material.dart';
import '../../services/referral/comprehensive_stats_service.dart';

/// Widget that displays real-time referral statistics
class RealtimeStatsWidget extends StatelessWidget {
  final String userId;
  final Widget Function(Map<String, dynamic> stats) builder;

  const RealtimeStatsWidget({
    super.key,
    required this.userId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: ComprehensiveStatsService.streamUserStats(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error loading stats: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Force refresh
                    ComprehensiveStatsService.updateUserStats(userId);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final stats = snapshot.data!;
        
        // Check if stats are stale and need updating
        final lastUpdate = stats['lastUpdate'] as DateTime?;
        if (lastUpdate != null && 
            DateTime.now().difference(lastUpdate).inMinutes > 5) {
          // Trigger background update
          ComprehensiveStatsService.updateUserStats(userId);
        }

        return builder(stats);
      },
    );
  }
}

/// Simple stats card widget for displaying key metrics
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress indicator widget for role progression
class RoleProgressWidget extends StatelessWidget {
  final Map<String, dynamic>? roleProgression;

  const RoleProgressWidget({
    super.key,
    this.roleProgression,
  });

  @override
  Widget build(BuildContext context) {
    if (roleProgression == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
              const SizedBox(height: 12),
              Text(
                'Maximum Role Achieved!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have reached the highest role available.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final nextRole = roleProgression!['nextRole'] as Map<String, dynamic>;
    final requirements = roleProgression!['requirements'] as Map<String, dynamic>;
    final overallProgress = roleProgression!['overallProgress'] as int;
    final readyForPromotion = roleProgression!['readyForPromotion'] as bool;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next Role: ${nextRole['name']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (readyForPromotion)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'READY!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (readyForPromotion) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Congratulations! You qualify for promotion.',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildProgressItem(
              'Direct Referrals',
              requirements['directReferrals']['current'],
              requirements['directReferrals']['required'],
              requirements['directReferrals']['progress'],
            ),
            const SizedBox(height: 12),
            _buildProgressItem(
              'Team Size',
              requirements['teamSize']['current'],
              requirements['teamSize']['required'],
              requirements['teamSize']['progress'],
            ),
            const SizedBox(height: 16),
            Text(
              'Overall Progress: $overallProgress%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: overallProgress >= 100 ? Colors.green : null,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: overallProgress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                overallProgress >= 100 ? Colors.green : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String title, int current, int required, int progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text('$current / $required'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 100 ? Colors.green : Colors.blue,
          ),
        ),
      ],
    );
  }
}


