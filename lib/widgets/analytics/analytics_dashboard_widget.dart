// Analytics Dashboard Widget - Comprehensive analytics and insights interface
// Complete analytics dashboard for TALOWA platform

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/analytics/analytics_model.dart';
import '../../services/analytics/advanced_analytics_service.dart';

class AnalyticsDashboardWidget extends StatefulWidget {
  final String? userId;
  final bool showPlatformAnalytics;

  const AnalyticsDashboardWidget({
    super.key,
    this.userId,
    this.showPlatformAnalytics = false,
  });

  @override
  State<AnalyticsDashboardWidget> createState() => _AnalyticsDashboardWidgetState();
}

class _AnalyticsDashboardWidgetState extends State<AnalyticsDashboardWidget>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  
  UserAnalyticsModel? _userAnalytics;
  PlatformAnalyticsModel? _platformAnalytics;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Date range selection
  final DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  final DateTime _endDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(
      length: widget.showPlatformAnalytics ? 6 : 5,
      vsync: this,
    );
    
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.userId != null) {
        final userAnalytics = await AdvancedAnalyticsService.instance
            .getUserAnalytics(
          widget.userId!,
          startDate: _startDate,
          endDate: _endDate,
        );
        
        setState(() {
          _userAnalytics = userAnalytics;
        });
      }

      if (widget.showPlatformAnalytics) {
        final platformAnalytics = await AdvancedAnalyticsService.instance
            .getPlatformAnalytics(
          startDate: _startDate,
          endDate: _endDate,
        );
        
        setState(() {
          _platformAnalytics = platformAnalytics;
        });
      }

      setState(() => _isLoading = false);

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load analytics: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          if (_isLoading)
            _buildLoadingIndicator()
          else if (_errorMessage != null)
            _buildErrorMessage()
          else
            Expanded(child: _buildAnalyticsTabs()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.showPlatformAnalytics 
                          ? 'Platform Analytics'
                          : 'Your Analytics',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Insights and performance metrics',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildDateRangeSelector(),
            ],
          ),
          const SizedBox(height: 20),
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    if (_userAnalytics == null && _platformAnalytics == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (_userAnalytics != null) ...[
          _buildQuickStatCard(
            'Total Posts',
            _userAnalytics!.contentMetrics.totalPosts.toString(),
            Icons.article,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _buildQuickStatCard(
            'Total Views',
            _formatNumber(_userAnalytics!.contentMetrics.totalViews),
            Icons.visibility,
            Colors.green,
          ),
          const SizedBox(width: 12),
          _buildQuickStatCard(
            'Engagement Rate',
            '${(_userAnalytics!.contentMetrics.averageEngagementRate * 100).toStringAsFixed(1)}%',
            Icons.favorite,
            Colors.red,
          ),
          const SizedBox(width: 12),
          _buildQuickStatCard(
            'Impact Score',
            _userAnalytics!.activismMetrics.impactScore.toStringAsFixed(1),
            Icons.trending_up,
            Colors.orange,
          ),
        ],
        if (_platformAnalytics != null) ...[
          _buildQuickStatCard(
            'Total Users',
            _formatNumber(_platformAnalytics!.userMetrics.totalUsers),
            Icons.people,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _buildQuickStatCard(
            'Active Users',
            _formatNumber(_platformAnalytics!.userMetrics.activeUsers),
            Icons.person,
            Colors.green,
          ),
          const SizedBox(width: 12),
          _buildQuickStatCard(
            'Total Posts',
            _formatNumber(_platformAnalytics!.contentMetrics.totalPosts),
            Icons.article,
            Colors.purple,
          ),
          const SizedBox(width: 12),
          _buildQuickStatCard(
            'Cases Resolved',
            _formatNumber(_platformAnalytics!.activismMetrics.resolvedCases),
            Icons.gavel,
            Colors.orange,
          ),
        ],
      ],
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTabs() {
    final tabs = <Widget>[
      const Tab(text: 'Overview'),
      const Tab(text: 'Content'),
      const Tab(text: 'Engagement'),
      const Tab(text: 'Search'),
      const Tab(text: 'Impact'),
    ];

    if (widget.showPlatformAnalytics) {
      tabs.add(const Tab(text: 'Platform'));
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: tabs,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildContentTab(),
              _buildEngagementTab(),
              _buildSearchTab(),
              _buildImpactTab(),
              if (widget.showPlatformAnalytics) _buildPlatformTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Performance Overview'),
          const SizedBox(height: 16),
          _buildOverviewCharts(),
          const SizedBox(height: 24),
          _buildSectionTitle('Key Metrics'),
          const SizedBox(height: 16),
          _buildKeyMetricsGrid(),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Content Performance'),
          const SizedBox(height: 16),
          _buildContentMetricsCards(),
          const SizedBox(height: 24),
          _buildSectionTitle('Top Performing Content'),
          const SizedBox(height: 16),
          _buildTopContentList(),
        ],
      ),
    );
  }

  Widget _buildEngagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Engagement Analytics'),
          const SizedBox(height: 16),
          _buildEngagementChart(),
          const SizedBox(height: 24),
          _buildSectionTitle('Engagement Breakdown'),
          const SizedBox(height: 16),
          _buildEngagementBreakdown(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Search Analytics'),
          const SizedBox(height: 16),
          _buildSearchMetricsCards(),
          const SizedBox(height: 24),
          _buildSectionTitle('Top Search Queries'),
          const SizedBox(height: 16),
          _buildTopQueriesList(),
        ],
      ),
    );
  }

  Widget _buildImpactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Activism Impact'),
          const SizedBox(height: 16),
          _buildImpactMetricsCards(),
          const SizedBox(height: 24),
          _buildSectionTitle('Impact Distribution'),
          const SizedBox(height: 16),
          _buildImpactChart(),
        ],
      ),
    );
  }

  Widget _buildPlatformTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Platform Overview'),
          const SizedBox(height: 16),
          _buildPlatformMetricsGrid(),
          const SizedBox(height: 24),
          _buildSectionTitle('Growth Trends'),
          const SizedBox(height: 16),
          _buildPlatformGrowthChart(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading analytics...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAnalytics,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder methods for chart and content widgets
  Widget _buildOverviewCharts() {
    return Container(
      height: 200,
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
      child: const Center(
        child: Text('Overview Charts Coming Soon'),
      ),
    );
  }

  Widget _buildKeyMetricsGrid() {
    return Container(
      height: 120,
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
      child: const Center(
        child: Text('Key Metrics Grid Coming Soon'),
      ),
    );
  }

  Widget _buildContentMetricsCards() {
    return Container(
      height: 150,
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
      child: const Center(
        child: Text('Content Metrics Coming Soon'),
      ),
    );
  }

  Widget _buildTopContentList() {
    return Container(
      height: 200,
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
      child: const Center(
        child: Text('Top Content List Coming Soon'),
      ),
    );
  }

  Widget _buildEngagementChart() {
    return Container(
      height: 250,
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
      child: const Center(
        child: Text('Engagement Chart Coming Soon'),
      ),
    );
  }

  Widget _buildEngagementBreakdown() {
    return Container(
      height: 180,
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
      child: const Center(
        child: Text('Engagement Breakdown Coming Soon'),
      ),
    );
  }

  Widget _buildSearchMetricsCards() {
    return Container(
      height: 150,
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
      child: const Center(
        child: Text('Search Metrics Coming Soon'),
      ),
    );
  }

  Widget _buildTopQueriesList() {
    return Container(
      height: 200,
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
      child: const Center(
        child: Text('Top Queries List Coming Soon'),
      ),
    );
  }

  Widget _buildImpactMetricsCards() {
    return Container(
      height: 150,
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
      child: const Center(
        child: Text('Impact Metrics Coming Soon'),
      ),
    );
  }

  Widget _buildImpactChart() {
    return Container(
      height: 250,
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
      child: const Center(
        child: Text('Impact Chart Coming Soon'),
      ),
    );
  }

  Widget _buildPlatformMetricsGrid() {
    return Container(
      height: 200,
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
      child: const Center(
        child: Text('Platform Metrics Coming Soon'),
      ),
    );
  }

  Widget _buildPlatformGrowthChart() {
    return Container(
      height: 250,
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
      child: const Center(
        child: Text('Growth Chart Coming Soon'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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


