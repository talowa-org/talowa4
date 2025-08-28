// Performance Monitor Widget for TALOWA
// Implements Task 21: Performance optimization - Monitoring & Analytics

import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/performance/performance_optimization_service.dart';
import '../../core/theme/app_theme.dart';

class PerformanceMonitorWidget extends StatefulWidget {
  final bool showInProduction;
  final Widget child;

  const PerformanceMonitorWidget({
    super.key,
    this.showInProduction = false,
    required this.child,
  });

  @override
  State<PerformanceMonitorWidget> createState() => _PerformanceMonitorWidgetState();
}

class _PerformanceMonitorWidgetState extends State<PerformanceMonitorWidget> {
  final PerformanceOptimizationService _performanceService = PerformanceOptimizationService();
  Timer? _updateTimer;
  Map<String, dynamic> _metrics = {};
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _metrics = _performanceService.getPerformanceMetrics();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showOverlay) _buildPerformanceOverlay(),
        _buildToggleButton(),
      ],
    );
  }

  Widget _buildToggleButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      child: FloatingActionButton.small(
        onPressed: () {
          setState(() {
            _showOverlay = !_showOverlay;
          });
        },
        backgroundColor: AppTheme.talowaGreen,
        child: Icon(
          _showOverlay ? Icons.close : Icons.speed,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPerformanceOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      right: 10,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.talowaGreen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Performance Monitor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildMetricSection('Memory', [
              'Cache Size: ${_metrics['cache_size'] ?? 0} items',
              'Memory Cache: ${(_metrics['memory_cache_size_mb'] ?? 0).toStringAsFixed(1)} MB',
              'Image Cache: ${(_metrics['image_cache_size_mb'] ?? 0).toStringAsFixed(1)} MB',
            ]),
            const SizedBox(height: 8),
            _buildMetricSection('Performance', [
              'Cache Hit Rate: ${_metrics['metrics']?['cache_hit_rate'] ?? 0}%',
              'Posts Loaded: ${_metrics['metrics']?['posts_loaded'] ?? 0}',
              'Images Cached: ${_metrics['metrics']?['image_cached'] ?? 0}',
            ]),
            const SizedBox(height: 8),
            _buildMetricSection('Optimization', [
              'Compression Ratio: ${_metrics['metrics']?['compression_ratio'] ?? 0}%',
              'Cache Hits: ${_metrics['metrics']?['cache_hit'] ?? 0}',
              'Cache Misses: ${_metrics['metrics']?['cache_miss'] ?? 0}',
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearCaches,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Clear Cache', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showDetailedMetrics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.talowaGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Details', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSection(String title, List<String> metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.talowaGreen,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ...metrics.map((metric) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            metric,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        )),
      ],
    );
  }

  Future<void> _clearCaches() async {
    await _performanceService.clearAllCaches();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All caches cleared'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showDetailedMetrics() {
    showDialog(
      context: context,
      builder: (context) => PerformanceDetailsDialog(metrics: _metrics),
    );
  }
}

class PerformanceDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> metrics;

  const PerformanceDetailsDialog({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detailed Performance Metrics'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Cache Statistics', {
                'Total Cache Items': metrics['cache_size']?.toString() ?? '0',
                'Image Cache Items': metrics['image_cache_size']?.toString() ?? '0',
                'Memory Cache Size': '${(metrics['memory_cache_size_mb'] ?? 0).toStringAsFixed(2)} MB',
                'Image Cache Size': '${(metrics['image_cache_size_mb'] ?? 0).toStringAsFixed(2)} MB',
              }),
              const SizedBox(height: 16),
              _buildSection('Performance Metrics', _getPerformanceMetrics()),
              const SizedBox(height: 16),
              _buildSection('System Info', {
                'Timestamp': metrics['timestamp']?.toString() ?? 'Unknown',
                'Platform': 'Flutter',
                'Environment': 'Development',
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () => _exportMetrics(context),
          child: const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildSection(String title, Map<String, String> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...data.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Text(entry.value),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Map<String, String> _getPerformanceMetrics() {
    final performanceMetrics = metrics['metrics'] as Map<String, dynamic>? ?? {};
    return performanceMetrics.map((key, value) => MapEntry(
      _formatMetricName(key),
      value.toString(),
    ));
  }

  String _formatMetricName(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _exportMetrics(BuildContext context) {
    // In a real implementation, this would export metrics to a file
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metrics export feature coming soon'),
      ),
    );
  }
}

// Performance benchmark widget
class PerformanceBenchmarkWidget extends StatefulWidget {
  final String testName;
  final Future<void> Function() testFunction;
  final Widget child;

  const PerformanceBenchmarkWidget({
    super.key,
    required this.testName,
    required this.testFunction,
    required this.child,
  });

  @override
  State<PerformanceBenchmarkWidget> createState() => _PerformanceBenchmarkWidgetState();
}

class _PerformanceBenchmarkWidgetState extends State<PerformanceBenchmarkWidget> {
  final Stopwatch _stopwatch = Stopwatch();
  String _benchmarkResult = '';

  @override
  void initState() {
    super.initState();
    _runBenchmark();
  }

  Future<void> _runBenchmark() async {
    _stopwatch.start();
    
    try {
      await widget.testFunction();
      _stopwatch.stop();
      
      setState(() {
        _benchmarkResult = '${widget.testName}: ${_stopwatch.elapsedMilliseconds}ms';
      });
      
      if (kDebugMode) {
        debugPrint(_benchmarkResult);
      }
    } catch (e) {
      _stopwatch.stop();
      setState(() {
        _benchmarkResult = '${widget.testName}: Error - $e';
      });
      if (kDebugMode) {
        debugPrint(_benchmarkResult);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_benchmarkResult.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _benchmarkResult,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

// Memory usage indicator widget
class MemoryUsageIndicator extends StatefulWidget {
  const MemoryUsageIndicator({super.key});

  @override
  State<MemoryUsageIndicator> createState() => _MemoryUsageIndicatorState();
}

class _MemoryUsageIndicatorState extends State<MemoryUsageIndicator> {
  final PerformanceOptimizationService _performanceService = PerformanceOptimizationService();
  Timer? _updateTimer;
  double _memoryUsage = 0.0;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final metrics = _performanceService.getPerformanceMetrics();
        setState(() {
          _memoryUsage = metrics['memory_cache_size_mb'] ?? 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const maxMemory = 50.0; // MB
    final usagePercentage = (_memoryUsage / maxMemory).clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Memory: ${_memoryUsage.toStringAsFixed(1)} MB',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: usagePercentage,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              usagePercentage > 0.8 ? Colors.red : AppTheme.talowaGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// FPS counter widget
class FPSCounter extends StatefulWidget {
  const FPSCounter({super.key});

  @override
  State<FPSCounter> createState() => _FPSCounterState();
}

class _FPSCounterState extends State<FPSCounter> with TickerProviderStateMixin {
  late AnimationController _animationController;
  int _frameCount = 0;
  double _fps = 0.0;
  DateTime _lastTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    
    _animationController.addListener(_updateFPS);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateFPS() {
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastTime).inMilliseconds;
    
    if (elapsed >= 1000) {
      setState(() {
        _fps = _frameCount * 1000 / elapsed;
        _frameCount = 0;
        _lastTime = now;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Text(
        'FPS: ${_fps.toStringAsFixed(1)}',
        style: TextStyle(
          fontSize: 12,
          color: _fps < 30 ? Colors.red : AppTheme.talowaGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}