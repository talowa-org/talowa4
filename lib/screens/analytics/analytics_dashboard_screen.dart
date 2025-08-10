// Analytics Dashboard Screen for TALOWA
// Implements Task 23: Implement content analytics - Dashboard UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/analytics/content_analytics_service.dart';
import '../../models/analytics_models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/analytics/analytics_chart_widget.dart';
import '../../widgets/analytics/metrics_card_widget.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ContentAnalyticsService _analyticsService = ContentAnalyticsService();
  
  late TabController _tabController;
  RealTimeAnalytics? _realTimeAnalytics;
  MovementAnalytics? _movementAnalytics;
  ContentEffectivenessInsights? _contentInsights;
  bool _isLoading = true;
  String? _error;
  
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        _analyticsService.getRealTimeAnalytics(),
        _analyticsService.getMovementAnalytics(
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
        ),
        _analyticsService.getContentEffectivenessInsights(
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
        ),
      ]);

      setState(() {
        _realTimeAnalytics = results[0] as RealTimeAnalytics;
        _movementAnalytics = results[1] as MovementAnalytics;
        _contentInsights = results[2] as ContentEffectivenessInsights;
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
        title: const Text('Analytics Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Content', icon: Icon(Icons.article, size: 20)),
            Tab(text: 'Movement', icon: Icon(Icons.trending_up, size: 20)),
            Tab(text: 'Real-time', icon: Icon(Icons.live_tv, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? ErrorDisplayWidget(
                  error: _error!,
                  onRetry: _loadAnalyticsData,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildContentTab(),
                    _buildMovementTab(),
                    _buildRealTimeTab(),
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
          _buildDateRangeHeader(),
          const SizedBox(height: 16),
          _buildOverviewMetrics(),
          const SizedBox(height: 16),
          _buildEngagementChart(),
          const SizedBox(height: 16),
          _buildTopPerformingContent(),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    if (_contentInsights == null) return const Center(child: Text('No content insights available'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentMetricsCards(),
          const SizedBox(height: 16),
          _buildContentTrends(),
          const SizedBox(height: 16),
          _buildOptimalPostingTimes(),
          const SizedBox(height: 16),
          _buildContentRecommendations(),
        ],
      ),
    );
  }

  Widget _buildMovementTab() {
    if (_movementAnalytics == null) return const Center(child: Text('No movement analytics available'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGrowthMetrics(),
          const SizedBox(height: 16),
          _buildEngagementTrends(),
          const SizedBox(height: 16),
          _buildGeographicDistribution(),
          const SizedBox(height: 16),
          _buildCampaignEffectiveness(),
        ],
      ),
    );
  }

  Widget _buildRealTimeTab() {
    if (_realTimeAnalytics == null) return const Center(child: Text('No real-time data available'));

    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRealTimeHeader(),
            const SizedBox(height: 16),
            _buildRealTimeEngagement(),
            const SizedBox(height: 16),
            _buildRealTimeUserActivity(),
            const SizedBox(height: 16),
            _buildRealTimeContentMetrics(),
            const SizedBox(height: 16),
            _buildTrendingTopics(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.date_range, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Analytics Period: ${_formatDate(_selectedStartDate)} - ${_formatDate(_selectedEndDate)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: _showDateRangePicker,
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewMetrics() {
    return Row(
      children: [
        Expanded(
          child: MetricsCardWidget(
            title: 'Total Posts',
            value: '1,234',
            change: '+12%',
            changePositive: true,
            icon: Icons.article,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricsCardWidget(
            title: 'Engagement',
            value: '8,567',
            change: '+23%',
            changePositive: true,
            icon: Icons.favorite,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricsCardWidget(
            title: 'Reach',
            value: '45,678',
            change: '+8%',
            changePositive: true,
            icon: Icons.visibility,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engagement Trends',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AnalyticsChartWidget(
                data: _generateSampleChartData(),
                chartType: ChartType.line,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformingContent() {
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
                  'Top Performing Content',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => _navigateToContentAnalytics(),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildTopContentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentMetricsCards() {
    return Row(
      children: [
        Expanded(
          child: MetricsCardWidget(
            title: 'Avg. Engagement Rate',
            value: '4.2%',
            change: '+0.8%',
            changePositive: true,
            icon: Icons.trending_up,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricsCardWidget(
            title: 'Best Performing',
            value: 'Tuesday 2PM',
            change: 'Optimal Time',
            changePositive: true,
            icon: Icons.schedule,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildContentTrends() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content Trends',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildTrendItem('Engagement Growth', '+15.5%', 'This week', Colors.green),
            _buildTrendItem('Video Content', '+32%', 'Performance boost', Colors.blue),
            _buildTrendItem('Hashtag Usage', '+8%', 'Reach improvement', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimalPostingTimes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optimal Posting Times',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: AnalyticsChartWidget(
                data: _generateHourlyEngagementData(),
                chartType: ChartType.bar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Recommendations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildRecommendationItem(
              'Use #LandRights hashtag more frequently',
              'Posts with this hashtag have 23% higher engagement',
              0.87,
            ),
            _buildRecommendationItem(
              'Post more video content',
              'Video posts get 45% more shares than text posts',
              0.92,
            ),
            _buildRecommendationItem(
              'Engage with comments within 2 hours',
              'Quick responses increase follow-up engagement by 18%',
              0.78,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthMetrics() {
    if (_movementAnalytics == null) return const SizedBox.shrink();

    final growth = _movementAnalytics!.growthMetrics;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Movement Growth',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGrowthMetricItem(
                    'New Users',
                    growth.newUsers.toString(),
                    Icons.person_add,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildGrowthMetricItem(
                    'Active Users',
                    growth.activeUsers.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildGrowthMetricItem(
                    'Retention Rate',
                    '${(growth.retentionRate * 100).round()}%',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildGrowthMetricItem(
                    'Growth Rate',
                    '${(growth.growthRate * 100).round()}%',
                    Icons.show_chart,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementTrends() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engagement Trends',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AnalyticsChartWidget(
                data: _generateEngagementTrendData(),
                chartType: ChartType.line,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeographicDistribution() {
    if (_movementAnalytics == null) return const SizedBox.shrink();

    final geo = _movementAnalytics!.geographicDistribution;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Geographic Distribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...geo.regions.entries.take(5).map((entry) {
              final percentage = (entry.value / geo.totalUsers * 100).round();
              return _buildGeographicItem(entry.key, entry.value, percentage);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignEffectiveness() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Campaign Effectiveness',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildCampaignItem(
              'Land Rights Awareness 2024',
              25000,
              3500,
              2.3,
            ),
            _buildCampaignItem(
              'Patta Application Drive',
              18000,
              2800,
              1.8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeHeader() {
    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Live Data - Last updated: ${_formatTime(_realTimeAnalytics!.lastUpdated)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeEngagement() {
    final engagement = _realTimeAnalytics!.engagement;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Real-time Engagement (Last 24h)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRealTimeMetric('Likes', engagement.likes, Icons.favorite, Colors.red),
                ),
                Expanded(
                  child: _buildRealTimeMetric('Comments', engagement.comments, Icons.comment, Colors.blue),
                ),
                Expanded(
                  child: _buildRealTimeMetric('Shares', engagement.shares, Icons.share, Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeUserActivity() {
    final activity = _realTimeAnalytics!.userActivity;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRealTimeMetric('Active Users', activity.activeUsers, Icons.people, Colors.orange),
                ),
                Expanded(
                  child: _buildRealTimeMetric('New Users', activity.newUsers, Icons.person_add, Colors.purple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeContentMetrics() {
    final content = _realTimeAnalytics!.contentMetrics;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content Metrics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRealTimeMetric('New Posts', content.newPosts, Icons.article, Colors.teal),
                ),
                Expanded(
                  child: _buildRealTimeMetric('Total Views', content.totalViews, Icons.visibility, Colors.indigo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingTopics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trending Topics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._realTimeAnalytics!.trendingTopics.map((topic) {
              return _buildTrendingTopicItem(topic);
            }),
          ],
        ),
      ),
    );
  }

  // Helper widget builders

  Widget _buildTrendItem(String title, String value, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String description, double confidence) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(confidence * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthMetricItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGeographicItem(String region, int users, int percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(region)),
          Text('$users users'),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('$percentage%', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignItem(String name, int reach, int engagement, double roi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Reach: ${_formatNumber(reach)}')),
              Expanded(child: Text('Engagement: ${_formatNumber(engagement)}')),
              Text('ROI: ${roi}x', style: TextStyle(color: Colors.green[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeMetric(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            _formatNumber(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingTopicItem(TrendingTopic topic) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              topic.topic,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text('${topic.mentions} mentions'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: topic.growth > 0 ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${topic.growth > 0 ? '+' : ''}${(topic.growth * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopContentList() {
    // Sample data - would come from analytics service
    return [
      _buildTopContentItem('Land Rights Awareness Post', 1250, 89, 4.2),
      _buildTopContentItem('Patta Application Guide', 980, 67, 3.8),
      _buildTopContentItem('Success Story: Village Victory', 856, 45, 3.5),
    ];
  }

  Widget _buildTopContentItem(String title, int engagement, int shares, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('$engagement engagements • $shares shares', 
                     style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              score.toString(),
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _selectedStartDate, end: _selectedEndDate),
    );

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
      _loadAnalyticsData();
    }
  }

  void _navigateToContentAnalytics() {
    Navigator.pushNamed(context, '/content-analytics');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  // Sample data generators
  List<ChartDataPoint> _generateSampleChartData() {
    return List.generate(7, (index) {
      return ChartDataPoint(
        x: DateTime.now().subtract(Duration(days: 6 - index)),
        y: 100 + (index * 50) + (index % 2 * 30),
      );
    });
  }

  List<ChartDataPoint> _generateHourlyEngagementData() {
    return List.generate(24, (index) {
      return ChartDataPoint(
        x: DateTime(2024, 1, 1, index),
        y: 20 + (index % 8 * 15) + (index > 8 && index < 20 ? 30 : 0),
      );
    });
  }

  List<ChartDataPoint> _generateEngagementTrendData() {
    return List.generate(30, (index) {
      return ChartDataPoint(
        x: DateTime.now().subtract(Duration(days: 29 - index)),
        y: 200 + (index * 10) + (index % 5 * 20),
      );
    });
  }
}