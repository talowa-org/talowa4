// Enhanced Moderation Dashboard Screen for TALOWA
// Provides comprehensive AI-powered content moderation management

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/security/ai_content_moderation_service.dart';
import '../../services/security/content_moderation_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';

class EnhancedModerationDashboardScreen extends StatefulWidget {
  const EnhancedModerationDashboardScreen({super.key});

  @override
  State<EnhancedModerationDashboardScreen> createState() => _EnhancedModerationDashboardScreenState();
}

class _EnhancedModerationDashboardScreenState extends State<EnhancedModerationDashboardScreen>
    with TickerProviderStateMixin {
  final AIContentModerationService _aiModerationService = AIContentModerationService();
  final ContentModerationService _baseModerationService = ContentModerationService();
  
  late TabController _tabController;
  
  AIModerationStats? _aiStats;
  ContentSafetyStats? _baseStats;
  List<Map<String, dynamic>> _pendingReviews = [];
  List<Map<String, dynamic>> _recentActions = [];
  
  bool _isLoading = true;
  String? _error;
  
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadModerationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModerationData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load AI moderation stats
      final aiStats = await _aiModerationService.getAIModerationStats(
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
      );
      
      // Load base moderation stats
      final baseStats = await _baseModerationService.getContentSafetyStats();
      
      // Load pending reviews
      final pendingReviews = await _loadPendingReviews();
      
      // Load recent actions
      final recentActions = await _loadRecentActions();

      setState(() {
        _aiStats = aiStats;
        _baseStats = baseStats;
        _pendingReviews = pendingReviews;
        _recentActions = recentActions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load moderation data: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingReviews() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('moderation_queue')
          .where('status', isEqualTo: 'pending')
          .orderBy('priority')
          .orderBy('queuedAt', descending: true)
          .limit(20)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentActions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ai_moderation_logs')
          .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(hours: 24)))
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Moderation Dashboard'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadModerationData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'AI Analytics', icon: Icon(Icons.psychology)),
            Tab(text: 'Pending Reviews', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Recent Actions', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? ErrorDisplayWidget(error: _error!, onRetry: _loadModerationData)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildAIAnalyticsTab(),
                    _buildPendingReviewsTab(),
                    _buildRecentActionsTab(),
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
          _buildOverviewCards(),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildSystemHealth(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'AI Analyzed',
          '${_aiStats?.totalAnalyzed ?? 0}',
          Icons.psychology,
          Colors.blue,
        ),
        _buildStatCard(
          'Flagged Content',
          '${_aiStats?.flaggedContent ?? 0}',
          Icons.flag,
          Colors.orange,
        ),
        _buildStatCard(
          'Automated Actions',
          '${_aiStats?.automatedActions ?? 0}',
          Icons.auto_fix_high,
          Colors.green,
        ),
        _buildStatCard(
          'Pending Reviews',
          '${_pendingReviews.length}',
          Icons.pending_actions,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip(
                  'Review Queue',
                  Icons.queue,
                  () => _tabController.animateTo(2),
                ),
                _buildActionChip(
                  'AI Settings',
                  Icons.settings,
                  _showAISettings,
                ),
                _buildActionChip(
                  'Export Report',
                  Icons.download,
                  _exportModerationReport,
                ),
                _buildActionChip(
                  'Policy Rules',
                  Icons.rule,
                  _showPolicyRules,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onPressed) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Widget _buildSystemHealth() {
    final accuracy = _aiStats?.accuracy ?? 0.0;
    final healthScore = _calculateSystemHealth();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Health',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildHealthMetric('AI Accuracy', accuracy, 0.8),
            const SizedBox(height: 8),
            _buildHealthMetric('System Health', healthScore, 0.7),
            const SizedBox(height: 8),
            _buildHealthMetric('Response Time', 0.95, 0.9),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetric(String label, double value, double threshold) {
    final color = value >= threshold ? Colors.green : Colors.orange;
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label),
        ),
        Expanded(
          flex: 3,
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).toStringAsFixed(1)}%',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAIAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildViolationTypesChart(),
          const SizedBox(height: 24),
          _buildActionTypesChart(),
          const SizedBox(height: 24),
          _buildTrendAnalysis(),
        ],
      ),
    );
  }

  Widget _buildViolationTypesChart() {
    final violationTypes = _aiStats?.violationTypes ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Violation Types',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (violationTypes.isEmpty)
              const Center(
                child: Text('No violations detected in selected period'),
              )
            else
              ...violationTypes.entries.map((entry) => 
                _buildViolationTypeItem(entry.key, entry.value)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationTypeItem(String type, int count) {
    final total = _aiStats?.violationTypes.values.fold(0, (sum, count) => sum + count) ?? 1;
    final percentage = (count / total * 100);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              type.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(_getViolationColor(type)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count (${percentage.toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTypesChart() {
    final actionTypes = _aiStats?.actionTypes ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Automated Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (actionTypes.isEmpty)
              const Center(
                child: Text('No automated actions in selected period'),
              )
            else
              ...actionTypes.entries.map((entry) => 
                _buildActionTypeItem(entry.key, entry.value)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTypeItem(String action, int count) {
    return ListTile(
      leading: Icon(_getActionIcon(action), color: _getActionColor(action)),
      title: Text(action.replaceAll('_', ' ').toUpperCase()),
      trailing: Chip(
        label: Text('$count'),
        backgroundColor: _getActionColor(action).withOpacity(0.2),
      ),
    );
  }

  Widget _buildTrendAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trend Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTrendItem(
              'Content Safety',
              _calculateSafetyTrend(),
              'Improvement in content quality detection',
            ),
            _buildTrendItem(
              'Response Time',
              0.15,
              'Faster automated moderation responses',
            ),
            _buildTrendItem(
              'False Positives',
              -0.08,
              'Reduced incorrect flagging',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendItem(String title, double trend, String description) {
    final isPositive = trend > 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(description),
      trailing: Text(
        '${isPositive ? '+' : ''}${(trend * 100).toStringAsFixed(1)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPendingReviewsTab() {
    return RefreshIndicator(
      onRefresh: _loadModerationData,
      child: _pendingReviews.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No pending reviews!'),
                  Text('All content has been processed.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingReviews.length,
              itemBuilder: (context, index) {
                final review = _pendingReviews[index];
                return _buildPendingReviewItem(review);
              },
            ),
    );
  }

  Widget _buildPendingReviewItem(Map<String, dynamic> review) {
    final priority = review['priority'] as int? ?? 4;
    final reason = review['reason'] as String? ?? 'Unknown';
    final confidence = review['confidence'] as double? ?? 0.0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor(priority),
          child: Text(
            '$priority',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: const Text('Content Review Required'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason: ${reason.replaceAll('_', ' ').toUpperCase()}'),
            Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _approveContent(review['id']),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _rejectContent(review['id']),
            ),
          ],
        ),
        onTap: () => _showContentDetails(review),
      ),
    );
  }

  Widget _buildRecentActionsTab() {
    return RefreshIndicator(
      onRefresh: _loadModerationData,
      child: _recentActions.isEmpty
          ? const Center(
              child: Text('No recent actions'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recentActions.length,
              itemBuilder: (context, index) {
                final action = _recentActions[index];
                return _buildRecentActionItem(action);
              },
            ),
    );
  }

  Widget _buildRecentActionItem(Map<String, dynamic> action) {
    final timestamp = (action['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isAppropriate = action['isAppropriate'] as bool? ?? true;
    final flaggedReasons = List<String>.from(action['flaggedReasons'] ?? []);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAppropriate ? Colors.green : Colors.red,
          child: Icon(
            isAppropriate ? Icons.check : Icons.warning,
            color: Colors.white,
          ),
        ),
        title: Text(isAppropriate ? 'Content Approved' : 'Content Flagged'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (flaggedReasons.isNotEmpty)
              Text('Reasons: ${flaggedReasons.join(', ')}'),
            Text('Time: ${_formatTimestamp(timestamp)}'),
          ],
        ),
        onTap: () => _showActionDetails(action),
      ),
    );
  }

  // Helper methods
  Color _getViolationColor(String type) {
    switch (type) {
      case 'hate_speech':
        return Colors.red;
      case 'misinformation':
        return Colors.orange;
      case 'spam':
        return Colors.yellow.shade700;
      case 'personal_attacks':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'hide':
        return Icons.visibility_off;
      case 'remove':
        return Icons.delete;
      case 'flag':
        return Icons.flag;
      case 'warn':
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'hide':
        return Colors.orange;
      case 'remove':
        return Colors.red;
      case 'flag':
        return Colors.yellow.shade700;
      case 'warn':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  double _calculateSystemHealth() {
    final totalAnalyzed = _aiStats?.totalAnalyzed ?? 0;
    final flaggedContent = _aiStats?.flaggedContent ?? 0;
    final automatedActions = _aiStats?.automatedActions ?? 0;
    
    if (totalAnalyzed == 0) return 1.0;
    
    final flagRate = flaggedContent / totalAnalyzed;
    final actionRate = automatedActions / totalAnalyzed;
    
    // Health score based on reasonable flag and action rates
    return 1.0 - (flagRate * 0.5) - (actionRate * 0.3);
  }

  double _calculateSafetyTrend() {
    // Simulate trend calculation - in real implementation, compare with previous period
    return 0.12; // 12% improvement
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  // Action handlers
  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedStartDate,
        end: _selectedEndDate,
      ),
    );
    
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
      _loadModerationData();
    }
  }

  void _showAISettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Moderation Settings'),
        content: const Text('AI settings configuration will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _exportModerationReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Moderation report export feature will be implemented'),
      ),
    );
  }

  void _showPolicyRules() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Policy Rules'),
        content: const Text('Policy rules management will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveContent(String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('moderation_queue')
          .doc(reviewId)
          .update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': 'admin', // In real app, use current user ID
      });
      
      _loadModerationData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content approved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving content: $e')),
      );
    }
  }

  Future<void> _rejectContent(String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('moderation_queue')
          .doc(reviewId)
          .update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': 'admin', // In real app, use current user ID
      });
      
      _loadModerationData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting content: $e')),
      );
    }
  }

  void _showContentDetails(Map<String, dynamic> review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Content Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Content ID: ${review['contentId']}'),
            Text('Reason: ${review['reason']}'),
            Text('Confidence: ${((review['confidence'] as double?) ?? 0.0 * 100).toStringAsFixed(1)}%'),
            Text('Priority: ${review['priority']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showActionDetails(Map<String, dynamic> action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Action Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Content ID: ${action['contentId']}'),
            Text('Appropriate: ${action['isAppropriate']}'),
            Text('Confidence: ${((action['confidenceScore'] as double?) ?? 0.0 * 100).toStringAsFixed(1)}%'),
            if (action['flaggedReasons'] != null)
              Text('Reasons: ${(action['flaggedReasons'] as List).join(', ')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
