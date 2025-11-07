// Database Monitoring Service for TALOWA Social Feed System
// Real-time performance monitoring and alerting

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../performance/performance_monitoring_service.dart';

/// Database Monitoring Service for performance tracking
class DatabaseMonitoringService {
  static DatabaseMonitoringService? _instance;
  static DatabaseMonitoringService get instance => _instance ??= DatabaseMonitoringService._internal();
  
  DatabaseMonitoringService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final PerformanceMonitoringService _performanceService;
  
  // Monitoring configuration
  static const Duration _monitoringInterval = Duration(minutes: 1);
  static const Duration _alertThreshold = Duration(seconds: 5);
  static const int _maxLatencyHistory = 100;
  static const double _errorRateThreshold = 0.05; // 5%
  
  // Monitoring state
  final Map<String, List<double>> _latencyHistory = {};
  final Map<String, int> _operationCounts = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastOperation = {};
  Timer? _monitoringTimer;
  
  // Alerts
  final List<DatabaseAlert> _activeAlerts = [];
  final List<DatabaseAlert> _alertHistory = [];
  
  bool _isInitialized = false;

  /// Initialize monitoring service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing Database Monitoring Service...');
      
      // Initialize dependencies
      _performanceService = PerformanceMonitoringService.instance;
      
      // Initialize monitoring collections
      _initializeMonitoringCollections();
      
      // Start monitoring timer
      _startMonitoring();
      
      _isInitialized = true;
      debugPrint('✅ Database Monitoring Service initialized');
      
    } catch (error) {
      debugPrint('❌ Failed to initialize Database Monitoring Service: $error');
      rethrow;
    }
  }

  /// Initialize monitoring collections
  void _initializeMonitoringCollections() {
    final collections = [
      'posts',
      'users',
      'messages',
      'conversations',
      'live_streams',
      'analytics',
    ];
    
    for (final collection in collections) {
      _latencyHistory[collection] = [];
      _operationCounts[collection] = 0;
      _errorCounts[collection] = 0;
      _lastOperation[collection] = DateTime.now();
    }
  }

  /// Start monitoring timer
  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _performMonitoringCheck();
    });
    
    debugPrint('⏰ Database monitoring started (${_monitoringInterval.inSeconds}s interval)');
  }

  /// Perform monitoring check
  Future<void> _performMonitoringCheck() async {
    try {
      // Check database health
      await _checkDatabaseHealth();
      
      // Check query performance
      await _checkQueryPerformance();
      
      // Check error rates
      _checkErrorRates();
      
      // Check connection status
      await _checkConnectionStatus();
      
      // Process alerts
      _processAlerts();
      
      // Save monitoring metrics
      await _saveMonitoringMetrics();
      
    } catch (error) {
      debugPrint('❌ Monitoring check failed: $error');
    }
  }

  /// Check database health
  Future<void> _checkDatabaseHealth() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Simple health check query
      await _firestore.collection('health_check').limit(1).get();
      
      final latency = stopwatch.elapsedMilliseconds.toDouble();
      _recordLatency('health_check', latency);
      
      // Check if latency exceeds threshold
      if (latency > _alertThreshold.inMilliseconds) {
        _createAlert(
          AlertType.highLatency,
          'Database health check latency: ${latency}ms',
          AlertSeverity.warning,
        );
      }
      
    } catch (error) {
      _recordError('health_check');
      _createAlert(
        AlertType.connectionError,
        'Database health check failed: $error',
        AlertSeverity.critical,
      );
    } finally {
      stopwatch.stop();
    }
  }

  /// Check query performance for each collection
  Future<void> _checkQueryPerformance() async {
    final collections = ['posts', 'users', 'messages'];
    
    for (final collection in collections) {
      await _checkCollectionPerformance(collection);
    }
  }

  /// Check performance for a specific collection
  Future<void> _checkCollectionPerformance(String collection) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Test query performance
      await _firestore
          .collection(collection)
          .limit(1)
          .get();
      
      final latency = stopwatch.elapsedMilliseconds.toDouble();
      _recordLatency(collection, latency);
      _recordOperation(collection);
      
      // Check if latency exceeds threshold
      if (latency > _alertThreshold.inMilliseconds) {
        _createAlert(
          AlertType.highLatency,
          'High latency for $collection: ${latency}ms',
          AlertSeverity.warning,
        );
      }
      
    } catch (error) {
      _recordError(collection);
      _createAlert(
        AlertType.queryError,
        'Query error for $collection: $error',
        AlertSeverity.error,
      );
    } finally {
      stopwatch.stop();
    }
  }

  /// Check error rates
  void _checkErrorRates() {
    for (final collection in _operationCounts.keys) {
      final operations = _operationCounts[collection]!;
      final errors = _errorCounts[collection]!;
      
      if (operations > 0) {
        final errorRate = errors / operations;
        
        if (errorRate > _errorRateThreshold) {
          _createAlert(
            AlertType.highErrorRate,
            'High error rate for $collection: ${(errorRate * 100).toStringAsFixed(1)}%',
            AlertSeverity.error,
          );
        }
      }
    }
  }

  /// Check connection status
  Future<void> _checkConnectionStatus() async {
    try {
      // Check if we can write to the database
      await _firestore.collection('health_check').add({
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'connection_test',
      });
      
      // Clean up test document
      final snapshot = await _firestore
          .collection('health_check')
          .where('type', isEqualTo: 'connection_test')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
      }
      
    } catch (error) {
      _createAlert(
        AlertType.connectionError,
        'Database connection test failed: $error',
        AlertSeverity.critical,
      );
    }
  }

  /// Record latency for a collection
  void _recordLatency(String collection, double latency) {
    if (!_latencyHistory.containsKey(collection)) {
      _latencyHistory[collection] = [];
    }
    
    final history = _latencyHistory[collection]!;
    history.add(latency);
    
    // Keep only recent measurements
    if (history.length > _maxLatencyHistory) {
      history.removeAt(0);
    }
    
    // Record in performance service
    _performanceService.recordMetric('${collection}_latency', latency);
  }

  /// Record operation for a collection
  void _recordOperation(String collection) {
    _operationCounts[collection] = (_operationCounts[collection] ?? 0) + 1;
    _lastOperation[collection] = DateTime.now();
  }

  /// Record error for a collection
  void _recordError(String collection) {
    _errorCounts[collection] = (_errorCounts[collection] ?? 0) + 1;
    _performanceService.recordError('${collection}_error', 'Database operation failed');
  }

  /// Create alert
  void _createAlert(AlertType type, String message, AlertSeverity severity) {
    final alert = DatabaseAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      message: message,
      severity: severity,
      createdAt: DateTime.now(),
      isActive: true,
    );
    
    // Check if similar alert already exists
    final existingAlert = _activeAlerts.firstWhere(
      (a) => a.type == type && a.message == message,
      orElse: () => alert,
    );
    
    if (existingAlert == alert) {
      _activeAlerts.add(alert);
      _alertHistory.add(alert);
      
      debugPrint('🚨 Database Alert [${severity.name.toUpperCase()}]: $message');
    }
  }

  /// Process and resolve alerts
  void _processAlerts() {
    final now = DateTime.now();
    final alertsToResolve = <DatabaseAlert>[];
    
    for (final alert in _activeAlerts) {
      // Auto-resolve alerts after 5 minutes if conditions improve
      if (now.difference(alert.createdAt).inMinutes >= 5) {
        if (_shouldResolveAlert(alert)) {
          alertsToResolve.add(alert);
        }
      }
    }
    
    // Resolve alerts
    for (final alert in alertsToResolve) {
      _resolveAlert(alert);
    }
  }

  /// Check if alert should be resolved
  bool _shouldResolveAlert(DatabaseAlert alert) {
    switch (alert.type) {
      case AlertType.highLatency:
        // Check if recent latency is below threshold
        final collection = _extractCollectionFromMessage(alert.message);
        if (collection != null && _latencyHistory.containsKey(collection)) {
          final recentLatencies = _latencyHistory[collection]!.take(10).toList();
          if (recentLatencies.isNotEmpty) {
            final avgLatency = recentLatencies.reduce((a, b) => a + b) / recentLatencies.length;
            return avgLatency < _alertThreshold.inMilliseconds;
          }
        }
        break;
      case AlertType.highErrorRate:
        // Check if error rate has improved
        final collection = _extractCollectionFromMessage(alert.message);
        if (collection != null) {
          final operations = _operationCounts[collection] ?? 0;
          final errors = _errorCounts[collection] ?? 0;
          if (operations > 0) {
            final errorRate = errors / operations;
            return errorRate <= _errorRateThreshold;
          }
        }
        break;
      case AlertType.connectionError:
      case AlertType.queryError:
        // These require manual resolution or successful operations
        return false;
    }
    
    return false;
  }

  /// Extract collection name from alert message
  String? _extractCollectionFromMessage(String message) {
    final collections = ['posts', 'users', 'messages', 'conversations', 'live_streams'];
    
    for (final collection in collections) {
      if (message.contains(collection)) {
        return collection;
      }
    }
    
    return null;
  }

  /// Resolve alert
  void _resolveAlert(DatabaseAlert alert) {
    alert.isActive = false;
    alert.resolvedAt = DateTime.now();
    
    _activeAlerts.remove(alert);
    
    debugPrint('✅ Resolved alert: ${alert.message}');
  }

  /// Save monitoring metrics to database
  Future<void> _saveMonitoringMetrics() async {
    try {
      final metrics = {
        'timestamp': FieldValue.serverTimestamp(),
        'latencyHistory': _latencyHistory.map((key, value) => MapEntry(key, {
          'average': value.isEmpty ? 0 : value.reduce((a, b) => a + b) / value.length,
          'min': value.isEmpty ? 0 : value.reduce(math.min),
          'max': value.isEmpty ? 0 : value.reduce(math.max),
          'count': value.length,
        })),
        'operationCounts': _operationCounts,
        'errorCounts': _errorCounts,
        'activeAlerts': _activeAlerts.length,
      };
      
      await _firestore
          .collection('system')
          .doc('monitoring')
          .collection('metrics')
          .add(metrics);
      
    } catch (error) {
      debugPrint('❌ Error saving monitoring metrics: $error');
    }
  }

  /// Get monitoring statistics
  Map<String, dynamic> getMonitoringStatistics() {
    final stats = <String, dynamic>{};
    
    for (final collection in _latencyHistory.keys) {
      final latencies = _latencyHistory[collection]!;
      final operations = _operationCounts[collection] ?? 0;
      final errors = _errorCounts[collection] ?? 0;
      
      stats[collection] = {
        'averageLatency': latencies.isEmpty ? 0 : latencies.reduce((a, b) => a + b) / latencies.length,
        'minLatency': latencies.isEmpty ? 0 : latencies.reduce(math.min),
        'maxLatency': latencies.isEmpty ? 0 : latencies.reduce(math.max),
        'operations': operations,
        'errors': errors,
        'errorRate': operations > 0 ? errors / operations : 0,
        'lastOperation': _lastOperation[collection]?.toIso8601String(),
      };
    }
    
    return {
      'collections': stats,
      'activeAlerts': _activeAlerts.length,
      'totalAlerts': _alertHistory.length,
      'monitoringInterval': _monitoringInterval.inSeconds,
    };
  }

  /// Get active alerts
  List<DatabaseAlert> getActiveAlerts() {
    return List.from(_activeAlerts);
  }

  /// Get alert history
  List<DatabaseAlert> getAlertHistory({int limit = 50}) {
    return _alertHistory.take(limit).toList();
  }

  /// Shutdown monitoring service
  Future<void> shutdown() async {
    try {
      debugPrint('🔄 Shutting down Database Monitoring Service...');
      
      // Cancel monitoring timer
      _monitoringTimer?.cancel();
      
      // Clear monitoring data
      _latencyHistory.clear();
      _operationCounts.clear();
      _errorCounts.clear();
      _lastOperation.clear();
      _activeAlerts.clear();
      _alertHistory.clear();
      
      _isInitialized = false;
      
      debugPrint('✅ Database Monitoring Service shutdown complete');
      
    } catch (error) {
      debugPrint('❌ Error during monitoring service shutdown: $error');
    }
  }
}

/// Database alert model
class DatabaseAlert {
  final String id;
  final AlertType type;
  final String message;
  final AlertSeverity severity;
  final DateTime createdAt;
  bool isActive;
  DateTime? resolvedAt;

  DatabaseAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.severity,
    required this.createdAt,
    this.isActive = true,
    this.resolvedAt,
  });
}

/// Alert types
enum AlertType {
  highLatency,
  highErrorRate,
  connectionError,
  queryError,
}

/// Alert severity levels
enum AlertSeverity {
  info,
  warning,
  error,
  critical,
}