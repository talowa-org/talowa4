// Safety Education Screen for TALOWA
// Implements Task 19: Build user safety features - Safety Education UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/safety/safety_education_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_widget.dart';

class SafetyEducationScreen extends StatefulWidget {
  const SafetyEducationScreen({super.key});

  @override
  State<SafetyEducationScreen> createState() => _SafetyEducationScreenState();
}

class _SafetyEducationScreenState extends State<SafetyEducationScreen>
    with SingleTickerProviderStateMixin {
  final SafetyEducationService _educationService = SafetyEducationService();
  
  late TabController _tabController;
  List<SafetyModule> _modules = [];
  List<SafetyTip> _tips = [];
  List<SafetyAlert> _alerts = [];
  UserSafetyProgress? _userProgress;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSafetyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSafetyData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = context.read<AuthProvider>().currentUser?.uid;
      if (userId == null) return;

      final results = await Future.wait([
        _educationService.getSafetyModules(language: 'english'),
        _educationService.getSafetyTips(language: 'english'),
        _educationService.getSafetyAlerts(userId: userId, unreadOnly: true),
        _educationService.getUserSafetyProgress(userId),
      ]);

      setState(() {
        _modules = results[0] as List<SafetyModule>;
        _tips = results[1] as List<SafetyTip>;
        _alerts = results[2] as List<SafetyAlert>;
        _userProgress = results[3] as UserSafetyProgress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Education'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Modules', icon: Icon(Icons.school, size: 20)),
            Tab(text: 'Tips', icon: Icon(Icons.lightbulb, size: 20)),
            Tab(text: 'Alerts', icon: Icon(Icons.notification_important, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? ErrorDisplayWidget(
                  error: _error!,
                  onRetry: _loadSafetyData,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildModulesTab(),
                    _buildTipsTab(),
                    _buildAlertsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressCard(),
          const SizedBox(height: 16),
          _buildQuickStatsCard(),
          const SizedBox(height: 16),
          _buildRecentAlertsCard(),
          const SizedBox(height: 16),
          _buildRecommendedModulesCard(),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    if (_userProgress == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Your Safety Score',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        value: _userProgress!.safetyScore / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getSafetyScoreColor(_userProgress!.safetyScore),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_userProgress!.safetyScore}/100',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _getSafetyScoreColor(_userProgress!.safetyScore),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getSafetyScoreLabel(_userProgress!.safetyScore),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressItem(
                        'Completed Modules',
                        '${_userProgress!.completedModules}/${_userProgress!.totalModules}',
                        _userProgress!.totalModules > 0
                            ? _userProgress!.completedModules / _userProgress!.totalModules
                            : 0.0,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildProgressItem(
                        'Overall Progress',
                        '${(_userProgress!.overallProgress * 100).round()}%',
                        _userProgress!.overallProgress,
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, String value, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildQuickStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Available Modules',
                    _modules.length.toString(),
                    Icons.school,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Safety Tips',
                    _tips.length.toString(),
                    Icons.lightbulb,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'New Alerts',
                    _alerts.length.toString(),
                    Icons.notification_important,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlertsCard() {
    if (_alerts.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Alerts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(3),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._alerts.take(3).map((alert) => _buildAlertItem(alert, compact: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedModulesCard() {
    final recommendedModules = _modules.take(3).toList();
    if (recommendedModules.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recommended Modules',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendedModules.map((module) => _buildModuleItem(module, compact: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildModulesTab() {
    return RefreshIndicator(
      onRefresh: _loadSafetyData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _modules.length,
        itemBuilder: (context, index) {
          final module = _modules[index];
          return _buildModuleItem(module);
        },
      ),
    );
  }

  Widget _buildModuleItem(SafetyModule module, {bool compact = false}) {
    final progress = _userProgress?.moduleProgress[module.id];
    final isCompleted = progress?.completed ?? false;
    final progressValue = progress?.progress ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green : Theme.of(context).primaryColor,
          child: Icon(
            isCompleted ? Icons.check : _getCategoryIcon(module.category),
            color: Colors.white,
          ),
        ),
        title: Text(
          module.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(module.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${module.estimatedDuration} min',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                if (progressValue > 0) ...[
                  Text(
                    '${progressValue.round()}% complete',
                    style: TextStyle(fontSize: 12, color: Colors.green[600]),
                  ),
                ],
              ],
            ),
            if (progressValue > 0 && !compact) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progressValue / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? Colors.green : Theme.of(context).primaryColor,
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          isCompleted ? Icons.check_circle : Icons.arrow_forward_ios,
          color: isCompleted ? Colors.green : null,
        ),
        onTap: () => _openModule(module),
      ),
    );
  }

  Widget _buildTipsTab() {
    return RefreshIndicator(
      onRefresh: _loadSafetyData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tips.length,
        itemBuilder: (context, index) {
          final tip = _tips[index];
          return _buildTipItem(tip);
        },
      ),
    );
  }

  Widget _buildTipItem(SafetyTip tip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getScenarioColor(tip.scenario),
          child: Icon(
            _getScenarioIcon(tip.scenario),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          tip.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _getScenarioLabel(tip.scenario),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tip.content),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return RefreshIndicator(
      onRefresh: _loadSafetyData,
      child: _alerts.isEmpty
          ? _buildEmptyAlertsState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildAlertItem(alert);
              },
            ),
    );
  }

  Widget _buildEmptyAlertsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No New Alerts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!\nWe\'ll notify you of any new safety alerts.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(SafetyAlert alert, {bool compact = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAlertSeverityColor(alert.severity),
          child: Icon(
            _getAlertSeverityIcon(alert.severity),
            color: Colors.white,
          ),
        ),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.content),
            const SizedBox(height: 4),
            Text(
              _formatDate(alert.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: alert.actionUrl != null
            ? Icon(Icons.arrow_forward_ios, color: Colors.grey[400])
            : null,
        onTap: () => _handleAlertTap(alert),
      ),
    );
  }

  // Helper methods

  Color _getSafetyScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getSafetyScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Improvement';
  }

  IconData _getCategoryIcon(SafetyCategory category) {
    switch (category) {
      case SafetyCategory.digitalSafety:
        return Icons.security;
      case SafetyCategory.harassment:
        return Icons.shield;
      case SafetyCategory.privacy:
        return Icons.privacy_tip;
      case SafetyCategory.scamPrevention:
        return Icons.warning;
      case SafetyCategory.emergencyResponse:
        return Icons.emergency;
    }
  }

  Color _getScenarioColor(SafetyScenario scenario) {
    switch (scenario) {
      case SafetyScenario.accountSecurity:
        return Colors.blue;
      case SafetyScenario.phishing:
        return Colors.orange;
      case SafetyScenario.harassment:
        return Colors.red;
      case SafetyScenario.dataPrivacy:
        return Colors.purple;
      case SafetyScenario.emergencyContact:
        return Colors.green;
    }
  }

  IconData _getScenarioIcon(SafetyScenario scenario) {
    switch (scenario) {
      case SafetyScenario.accountSecurity:
        return Icons.lock;
      case SafetyScenario.phishing:
        return Icons.phishing;
      case SafetyScenario.harassment:
        return Icons.report;
      case SafetyScenario.dataPrivacy:
        return Icons.privacy_tip;
      case SafetyScenario.emergencyContact:
        return Icons.emergency;
    }
  }

  String _getScenarioLabel(SafetyScenario scenario) {
    switch (scenario) {
      case SafetyScenario.accountSecurity:
        return 'Account Security';
      case SafetyScenario.phishing:
        return 'Phishing Prevention';
      case SafetyScenario.harassment:
        return 'Harassment Prevention';
      case SafetyScenario.dataPrivacy:
        return 'Data Privacy';
      case SafetyScenario.emergencyContact:
        return 'Emergency Response';
    }
  }

  Color _getAlertSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return Colors.blue;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.critical:
        return Colors.red;
    }
  }

  IconData _getAlertSeverityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return Icons.info;
      case AlertSeverity.warning:
        return Icons.warning;
      case AlertSeverity.critical:
        return Icons.dangerous;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _openModule(SafetyModule module) {
    Navigator.pushNamed(
      context,
      '/safety-module',
      arguments: module,
    );
  }

  void _handleAlertTap(SafetyAlert alert) async {
    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId != null) {
      await _educationService.markAlertAsRead(
        userId: userId,
        alertId: alert.id,
      );
      
      // Remove from local list
      setState(() {
        _alerts.removeWhere((a) => a.id == alert.id);
      });
    }

    if (alert.actionUrl != null) {
      // Handle action URL navigation
      Navigator.pushNamed(context, alert.actionUrl!);
    }
  }
}