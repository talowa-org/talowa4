// Performance Dashboard Widget for TALOWA
// Real-time performance monitoring and metrics display

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/performance/enterprise_performance_service.dart';

class PerformanceDashboardWidget extends StatefulWidget {
  final bool showDetailedMetrics;
  final Duration updateInterval;

  const PerformanceDashboardWidget({
    Key? key,
    this.showDetailedMetrics = false,
    this.updateInterval = const Duration(seconds: 5),
  }) : super(key: key);

  @override
  State<PerformanceDashboardWidget> createState() => _PerformanceDashboardWidgetState();
}

class _PerformanceDashboardWidgetState extends State<PerformanceDashboardWidget>
    with SingleTickerProviderStateMixin {
  
  final EnterprisePerformanceService _performanceService = EnterprisePerformanceService();
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Performance data
  List<PerformanceReport> _performanceHistory = [];
  PerformanceReport? _latestReport;
  Timer? _updateTimer;
  
  // UI state
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _startPerformanceMonitoring();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  void _startPerformanceMonitoring() {
    // Listen to performance reports
    _performanceService.performanceReportStream.listen((report) {
      setState(() {
        _latestReport = report;
        _performanceHistory.add(report);
        
        // Keep only last 20 reports for chart
        if (_performanceHistory.length > 20) {
          _performanceHistory.removeAt(0);
        }
      });
    });
    
    // Update timer for real-time updates
    _updateTimer = Timer.periodic(widget.updateInterval, (timer) {
      // Trigger UI update
      if (mounted) {
        setState(() {});
      }
    });
  }

  Widget _buildCompactView() {
    if (_latestReport == null) {
      return _buildLoadingIndicator();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.indigo.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Performance Monitor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricChip(
                'L1 Cache',
                '${(_latestReport!.l1CacheHitRate * 100).toStringAsFixed(1)}%',
                _getCacheColor(_latestReport!.l1CacheHitRate),
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                'Memory',
                '${(_latestReport!.memoryUsage / 1024).toStringAsFixed(1)}KB',
                _getMemoryColor(_latestReport!.memoryUsage),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            _buildDetailedMetrics(),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedView() {
    if (_latestReport == null) {
      return _buildLoadingIndicator();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildMetricsGrid(),
          const SizedBox(height: 20),
          _buildPerformanceChart(),
          const SizedBox(height: 20),
          _buildCacheAnalysis(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.analytics,
            color: Colors.blue.shade700,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                'Real-time system performance monitoring',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    final overallScore = _calculateOverallScore();
    Color statusColor;
    String statusText;
    
    if (overallScore >= 0.8) {
      statusColor = Colors.green;
      statusText = 'Excellent';
    } else if (overallScore >= 0.6) {
      statusColor = Colors.orange;
      statusText = 'Good';
    } else {
      statusColor = Colors.red;
      statusText = 'Needs Attention';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _buildMetricCard(
          'L1 Cache Hit Rate',
          '${(_latestReport!.l1CacheHitRate * 100).toStringAsFixed(1)}%',
          Icons.memory,
          _getCacheColor(_latestReport!.l1CacheHitRate),
        ),
        _buildMetricCard(
          'L2 Cache Hit Rate',
          '${(_latestReport!.l2CacheHitRate * 100).toStringAsFixed(1)}%',
          Icons.storage,
          _getCacheColor(_latestReport!.l2CacheHitRate),
        ),
        _buildMetricCard(
          'Memory Usage',
          '${(_latestReport!.memoryUsage / 1024).toStringAsFixed(1)}KB',
          Icons.memory,
          _getMemoryColor(_latestReport!.memoryUsage),
        ),
        _buildMetricCard(
          'Response Time',
          '${_latestReport!.averageResponseTime.toStringAsFixed(1)}ms',
          Icons.timer,
          _getResponseTimeColor(_latestReport!.averageResponseTime),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    if (_performanceHistory.length < 2) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'Collecting performance data...',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _performanceHistory.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value.l1CacheHitRate,
                );
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: _performanceHistory.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value.l2CacheHitRate,
                );
              }).toList(),
              isCurved: true,
              color: Colors.green,
              barWidth: 2,
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cache Performance Analysis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 12),
          _buildAnalysisItem(
            'Multi-level caching is optimizing data access patterns',
            _latestReport!.l1CacheHitRate > 0.7,
          ),
          _buildAnalysisItem(
            'Memory usage is within acceptable limits',
            _latestReport!.memoryUsage < 50 * 1024, // 50KB threshold
          ),
          _buildAnalysisItem(
            'Response times are meeting performance targets',
            _latestReport!.averageResponseTime < 100, // 100ms threshold
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String text, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.warning,
            color: isGood ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetrics() {
    return Column(
      children: [
        Row(
          children: [
            _buildMetricChip(
              'L2 Cache',
              '${(_latestReport!.l2CacheHitRate * 100).toStringAsFixed(1)}%',
              _getCacheColor(_latestReport!.l2CacheHitRate),
            ),
            const SizedBox(width: 8),
            _buildMetricChip(
              'L3 Cache',
              '${(_latestReport!.l3CacheHitRate * 100).toStringAsFixed(1)}%',
              _getCacheColor(_latestReport!.l3CacheHitRate),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMetricChip(
              'Response',
              '${_latestReport!.averageResponseTime.toStringAsFixed(1)}ms',
              _getResponseTimeColor(_latestReport!.averageResponseTime),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
          const SizedBox(height: 12),
          Text(
            'Initializing performance monitoring...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getCacheColor(double hitRate) {
    if (hitRate >= 0.8) return Colors.green;
    if (hitRate >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getMemoryColor(double memoryUsage) {
    if (memoryUsage < 30 * 1024) return Colors.green; // < 30KB
    if (memoryUsage < 50 * 1024) return Colors.orange; // < 50KB
    return Colors.red;
  }

  Color _getResponseTimeColor(double responseTime) {
    if (responseTime < 50) return Colors.green; // < 50ms
    if (responseTime < 100) return Colors.orange; // < 100ms
    return Colors.red;
  }

  double _calculateOverallScore() {
    if (_latestReport == null) return 0.0;
    
    final cacheScore = (_latestReport!.l1CacheHitRate + _latestReport!.l2CacheHitRate) / 2;
    final memoryScore = _latestReport!.memoryUsage < 50 * 1024 ? 1.0 : 0.5;
    final responseScore = _latestReport!.averageResponseTime < 100 ? 1.0 : 0.5;
    
    return (cacheScore + memoryScore + responseScore) / 3;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.showDetailedMetrics ? _buildDetailedView() : _buildCompactView(),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }
}

