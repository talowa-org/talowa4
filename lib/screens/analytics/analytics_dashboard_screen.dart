// Analytics Dashboard Screen for TALOWA
// Implements Task 23: Implement content analytics - Dashboard UI

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics/post_analytics_service.dart';
import '../../services/auth_service.dart';
import '../../models/social_feed/post_model.dart';
import '../../widgets/social_feed/post_widget.dart';
import '../../utils/app_colors.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PostAnalyticsService _analyticsService = PostAnalyticsService();
  
  UserAnalyticsDashboard? _dashboardData;
  List<TrendingPostAnalytics> _trendingPosts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = AuthService.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final dashboardData = await _analyticsService.getUserAnalyticsDashboard(currentUserId);
      final trendingPosts = await _analyticsService.getTrendingPosts(limit: 10);

      setState(() {
        _dashboardData = dashboardData;
        _trendingPosts = trendingPosts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Performance', icon: Icon(Icons.trending_up)),
            Tab(text: 'Trending', icon: Icon(Icons.whatshot)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildPerformanceTab(),
                    _buildTrendingTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Failed to load analytics data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAnalyticsData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_dashboardData == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            _buildEngagementChart(),
            const SizedBox(height: 24),
            _buildTopPerformingPosts(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final data = _dashboardData!;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Posts',
          data.totalPosts.toString(),
          Icons.article,
          AppColors.primary,
        ),
        _buildMetricCard(
          'Total Impressions',
          _formatNumber(data.totalImpressions),
          Icons.visibility,
          Colors.blue,
        ),
        _buildMetricCard(
          'Total Engagements',
          _formatNumber(data.totalEngagements),
          Icons.favorite,
          Colors.red,
        ),
        _buildMetricCard(
          'Engagement Rate',
          '${data.averageEngagementRate.toStringAsFixed(1)}%',
          Icons.trending_up,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
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
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementChart() {
    final data = _dashboardData!;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engagement Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: data.totalLikes.toDouble(),
                      title: 'Likes\n${data.totalLikes}',
                      color: Colors.red,
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: data.totalComments.toDouble(),
                      title: 'Comments\n${data.totalComments}',
                      color: Colors.blue,
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: data.totalShares.toDouble(),
                      title: 'Shares\n${data.totalShares}',
                      color: Colors.green,
                      radius: 60,
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformingPosts() {
    final data = _dashboardData!;
    
    if (data.topPerformingPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Posts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...data.topPerformingPosts.take(3).map((post) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PostWidget(post: post, isCompact: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTab() {
    if (_dashboardData == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPerformanceMetrics(),
          const SizedBox(height: 24),
          _buildRecentPosts(),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final data = _dashboardData!;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Total Posts', data.totalPosts.toString()),
            _buildMetricRow('Total Impressions', _formatNumber(data.totalImpressions)),
            _buildMetricRow('Total Engagements', _formatNumber(data.totalEngagements)),
            _buildMetricRow('Total Likes', _formatNumber(data.totalLikes)),
            _buildMetricRow('Total Comments', _formatNumber(data.totalComments)),
            _buildMetricRow('Total Shares', _formatNumber(data.totalShares)),
            _buildMetricRow('Avg. Engagement Rate', '${data.averageEngagementRate.toStringAsFixed(2)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPosts() {
    final data = _dashboardData!;
    
    if (data.recentPosts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No recent posts found'),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Posts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...data.recentPosts.map((post) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PostWidget(post: post, isCompact: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingTab() {
    if (_trendingPosts.isEmpty) {
      return const Center(
        child: Text('No trending posts found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trendingPosts.length,
        itemBuilder: (context, index) {
          final trendingPost = _trendingPosts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text('Trending Score: ${trendingPost.trendingScore.toStringAsFixed(1)}'),
                  subtitle: Text(
                    '${trendingPost.analytics.totalEngagements} engagements â€¢ '
                    '${trendingPost.analytics.totalImpressions} impressions',
                  ),
                ),
                PostWidget(post: trendingPost.post, isCompact: true),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }


















}
