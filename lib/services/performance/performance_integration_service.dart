// Performance Integration Service for TALOWA
// Integrates all performance optimization services

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'memory_management_service.dart';
import 'network_optimization_service.dart';
import 'widget_optimization_service.dart';
import 'request_deduplication_service.dart';
import 'performance_optimization_service.dart';

class PerformanceIntegrationService {
  static final PerformanceIntegrationService _instance = PerformanceIntegrationService._internal();
  factory PerformanceIntegrationService() => _instance;
  PerformanceIntegrationService._internal();

  static bool _isInitialized = false;
  static final Map<String, dynamic> _integrationMetrics = {};

  /// Initialize all performance services
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final stopwatch = Stopwatch()..start();

      // Initialize all performance services in parallel
      await Future.wait([
        MemoryManagementService.initialize(),
        NetworkOptimizationService.initialize(),
        WidgetOptimizationService.initialize(),
        PerformanceOptimizationService.initialize(),
      ]);

      stopwatch.stop();
      _integrationMetrics['initialization_time'] = stopwatch.elapsedMilliseconds;
      _integrationMetrics['services_initialized'] = 5;

      _isInitialized = true;
      debugPrint('PerformanceIntegrationService initialized in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('Error initializing PerformanceIntegrationService: $e');
      rethrow;
    }
  }

  /// Get comprehensive performance statistics
  static Map<String, dynamic> getPerformanceStatistics() {
    if (!_isInitialized) return {};

    return {
      'memory_stats': MemoryManagementService.instance.getMemoryStatistics(),
      'widget_stats': WidgetOptimizationService.instance.getPerformanceStatistics(),
      'integration_metrics': _integrationMetrics,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Optimize performance across all services
  static Future<void> optimizePerformance() async {
    if (!_isInitialized) return;

    try {
      await Future.wait([
        WidgetOptimizationService.instance.dispose(),
      ]);

      debugPrint('Performance optimization completed across all services');
    } catch (e) {
      debugPrint('Error during performance optimization: $e');
    }
  }

  /// Dispose all performance services
  static Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await Future.wait([
        MemoryManagementService.instance.dispose(),
        WidgetOptimizationService.instance.dispose(),
      ]);

      _isInitialized = false;
      debugPrint('Performance integration services disposed');
    } catch (e) {
      debugPrint('Error disposing performance services: $e');
    }
  }
}