// Admin Analytics Screen - Advanced analytics and insights
import 'package:flutter/material.dart';
import '../../services/admin/admin_dashboard_enhanced_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  Map<String, dynamic>? _dashboardStats;
  Map<String, dynamic>? _predictiveInsights;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = await Future.wait([
        AdminDashboardEnhancedService.getDashboardStats(),
        AdminDashboardEnhancedService.getPredictiveInsights(),
      ]);

      setState(() {
        _dashboardStats = futures[0];
        _predictiveInsights = futures[1];
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
        title: const Text('Analytics'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading analytics...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Error loading analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[800])),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAnalyticsData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserAnalytics(),
            const SizedBox(height: 24),
            _buildReferralAnalytics(),
            const SizedBox(height: 24),
            _buildGrowthAnalytics(),
            const SizedBox(height: 24),
            _buildPredictiveInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAnalytics() {
    final userStats = _dashboardStats?['userStats'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2,
              children: [
                _buildAnalyticsCard('Total Users', '${userStats['totalUsers'] ?? 0}', Icons.people, Colors.blue),
                _buildAnalyticsCard('Active Users', '${userStats['activeUsers'] ?? 0}', Icons.people_alt, Colors.green),
                _buildAnalyticsCard('New Today', '${userStats['newUsersToday'] ?? 0}', Icons.person_add, Colors.orange),
                _buildAnalyticsCard('Banned Users', '${userStats['bannedUsers'] ?? 0}', Icons.block, Colors.red),
              ],
            ),
            
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (userStats['activeUserPercentage'] as int? ?? 0) / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
            ),
            const SizedBox(height: 8),
            Text('${userStats['activeUserPercentage'] ?? 0}% Active Users', style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralAnalytics() {
    final referralStats = _dashboardStats?['referralStats'] as Map<String, dynamic>? ?? {};
    final referralFunnel = referralStats['referralFunnel'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Referral Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildAnalyticsCard('Total Referrals', '${referralStats['totalReferrals'] ?? 0}', Icons.share, Colors.purple)),
                const SizedBox(width: 16),
                Expanded(child: _buildAnalyticsCard('Avg Team Size', '${referralStats['averageTeamSize'] ?? 0}', Icons.group, Colors.teal)),
              ],
            ),
            
            const SizedBox(height: 16),
            const Text('Referral Distribution:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            
            ...referralFunnel.map<Widget>((tier) {
              final tierData = tier as Map<String, dynamic>;
              final percentage = tierData['percentage'] as int? ?? 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tierData['tier'] as String? ?? 'Unknown'),
                        Text('${tierData['count'] ?? 0} users ($percentage%)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthAnalytics() {
    final growthStats = _dashboardStats?['growthStats'] as Map<String, dynamic>? ?? {};
    final dailyGrowth = growthStats['dailyGrowth'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Growth Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${growthStats['weeklyGrowthRate'] ?? 0}% weekly',
                    style: TextStyle(color: Colors.green[800], fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildAnalyticsCard('30-Day Growth', '${growthStats['totalGrowthLast30Days'] ?? 0}', Icons.trending_up, Colors.green)),
                const SizedBox(width: 16),
                Expanded(child: _buildAnalyticsCard('Daily Average', '${growthStats['averageDailyGrowth'] ?? 0}', Icons.today, Colors.blue)),
              ],
            ),
            
            const SizedBox(height: 16),
            const Text('Growth Trend (Last 30 Days):', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            
            SizedBox(
              height: 100,
              child: dailyGrowth.isNotEmpty ? _buildGrowthChart(dailyGrowth) : const Center(child: Text('No growth data')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictiveInsights() {
    final insights = _predictiveInsights ?? {};
    final trends = insights['trends'] as List<dynamic>? ?? [];
    final recommendations = insights['recommendations'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Predictive Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            if (insights['predictedGrowth30Days'] != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue[800]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('30-Day Prediction', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('Expected growth: ${insights['predictedGrowth30Days']} new users'),
                          Text('Projected total: ${insights['predictedTotalUsers']} users'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            if (trends.isNotEmpty) ...[
              const Text('Trends:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...trends.map<Widget>((trend) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(trend.toString(), style: const TextStyle(fontSize: 14))),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
            
            if (recommendations.isNotEmpty) ...[
              const Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...recommendations.map<Widget>((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(rec.toString(), style: const TextStyle(fontSize: 14))),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGrowthChart(List<dynamic> dailyGrowth) {
    final maxValue = dailyGrowth
        .map((day) => (day['newUsers'] as int? ?? 0))
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    if (maxValue == 0) return const Center(child: Text('No data'));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: dailyGrowth.map<Widget>((day) {
        final value = (day['newUsers'] as int? ?? 0).toDouble();
        final height = (value / maxValue * 80).clamp(2.0, 80.0);
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: height,
            decoration: BoxDecoration(
              color: Colors.green[400],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

