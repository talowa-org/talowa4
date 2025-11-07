// Database Connection Pool Service for TALOWA Social Feed System
// Intelligent connection routing and load balancing

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Database Connection Pool with intelligent routing
class DatabaseConnectionPool {
  static DatabaseConnectionPool? _instance;
  static DatabaseConnectionPool get instance => _instance ??= DatabaseConnectionPool._internal();
  
  DatabaseConnectionPool._internal();

  // Connection pools
  final Map<String, List<DatabaseConnection>> _pools = {};
  final Map<String, int> _roundRobinIndex = {};
  
  // Health monitoring
  final Map<String, ConnectionHealth> _connectionHealth = {};
  Timer? _healthCheckTimer;
  
  // Configuration
  static const int _maxConnectionsPerPool = 10;
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 10);
  
  bool _isInitialized = false;

  /// Initialize connection pools
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing Database Connection Pool...');
      
      // Create primary pool
      await _createPool('primary', _maxConnectionsPerPool);
      
      // Create read replica pools
      await _createPool('read_replica_1', _maxConnectionsPerPool ~/ 2);
      await _createPool('read_replica_2', _maxConnectionsPerPool ~/ 2);
      
      // Create analytics pool
      await _createPool('analytics', _maxConnectionsPerPool ~/ 4);
      
      // Start health monitoring
      _startHealthMonitoring();
      
      _isInitialized = true;
      debugPrint('✅ Database Connection Pool initialized');
      
    } catch (error) {
      debugPrint('❌ Failed to initialize Database Connection Pool: $error');
      rethrow;
    }
  }

  /// Create a connection pool
  Future<void> _createPool(String poolName, int maxConnections) async {
    final connections = <DatabaseConnection>[];
    
    for (int i = 0; i < maxConnections; i++) {
      final connection = DatabaseConnection(
        id: '${poolName}_$i',
        firestore: FirebaseFirestore.instance,
        poolName: poolName,
      );
      
      await connection.initialize();
      connections.add(connection);
      
      // Initialize health status
      _connectionHealth['${poolName}_$i'] = ConnectionHealth.healthy;
    }
    
    _pools[poolName] = connections;
    _roundRobinIndex[poolName] = 0;
    
    debugPrint('✅ Created pool "$poolName" with $maxConnections connections');
  }

  /// Get optimal connection from pool
  DatabaseConnection getConnection(String poolName, {ConnectionStrategy strategy = ConnectionStrategy.leastLatency}) {
    final pool = _pools[poolName];
    if (pool == null || pool.isEmpty) {
      throw Exception('Pool "$poolName" not found or empty');
    }

    switch (strategy) {
      case ConnectionStrategy.roundRobin:
        return _getRoundRobinConnection(poolName);
      case ConnectionStrategy.leastLatency:
        return _getLeastLatencyConnection(poolName);
      case ConnectionStrategy.leastConnections:
        return _getLeastConnectionsConnection(poolName);
      case ConnectionStrategy.random:
        return _getRandomConnection(poolName);
    }
  }

  /// Get connection using round-robin strategy
  DatabaseConnection _getRoundRobinConnection(String poolName) {
    final pool = _pools[poolName]!;
    final index = _roundRobinIndex[poolName]!;
    
    final connection = pool[index % pool.length];
    _roundRobinIndex[poolName] = (index + 1) % pool.length;
    
    return connection;
  }

  /// Get connection with least latency
  DatabaseConnection _getLeastLatencyConnection(String poolName) {
    final pool = _pools[poolName]!;
    
    DatabaseConnection bestConnection = pool[0];
    double bestLatency = bestConnection.averageLatency;
    
    for (final connection in pool) {
      if (connection.averageLatency < bestLatency && 
          _connectionHealth[connection.id] == ConnectionHealth.healthy) {
        bestLatency = connection.averageLatency;
        bestConnection = connection;
      }
    }
    
    return bestConnection;
  }

  /// Get connection with least active connections
  DatabaseConnection _getLeastConnectionsConnection(String poolName) {
    final pool = _pools[poolName]!;
    
    DatabaseConnection bestConnection = pool[0];
    int leastConnections = bestConnection.activeConnections;
    
    for (final connection in pool) {
      if (connection.activeConnections < leastConnections && 
          _connectionHealth[connection.id] == ConnectionHealth.healthy) {
        leastConnections = connection.activeConnections;
        bestConnection = connection;
      }
    }
    
    return bestConnection;
  }

  /// Get random connection
  DatabaseConnection _getRandomConnection(String poolName) {
    final pool = _pools[poolName]!;
    final healthyConnections = pool.where((conn) => 
        _connectionHealth[conn.id] == ConnectionHealth.healthy).toList();
    
    if (healthyConnections.isEmpty) {
      return pool[math.Random().nextInt(pool.length)];
    }
    
    return healthyConnections[math.Random().nextInt(healthyConnections.length)];
  }

  /// Start health monitoring
  void _startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  /// Perform health check on all connections
  Future<void> _performHealthCheck() async {
    for (final poolName in _pools.keys) {
      final pool = _pools[poolName]!;
      
      for (final connection in pool) {
        await _checkConnectionHealth(connection);
      }
    }
  }

  /// Check health of individual connection
  Future<void> _checkConnectionHealth(DatabaseConnection connection) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Simple health check query
      await connection.firestore
          .collection('health_check')
          .limit(1)
          .get()
          .timeout(_connectionTimeout);
      
      final latency = stopwatch.elapsedMilliseconds;
      connection.updateLatency(latency.toDouble());
      
      // Determine health based on latency
      if (latency < 1000) {
        _connectionHealth[connection.id] = ConnectionHealth.healthy;
      } else if (latency < 3000) {
        _connectionHealth[connection.id] = ConnectionHealth.degraded;
      } else {
        _connectionHealth[connection.id] = ConnectionHealth.unhealthy;
      }
      
    } catch (error) {
      _connectionHealth[connection.id] = ConnectionHealth.unhealthy;
      connection.updateLatency(double.infinity);
    }
  }

  /// Get pool statistics
  Map<String, PoolStatistics> getPoolStatistics() {
    final stats = <String, PoolStatistics>{};
    
    for (final poolName in _pools.keys) {
      final pool = _pools[poolName]!;
      
      int healthyCount = 0;
      int degradedCount = 0;
      int unhealthyCount = 0;
      double totalLatency = 0;
      int totalActiveConnections = 0;
      
      for (final connection in pool) {
        final health = _connectionHealth[connection.id]!;
        switch (health) {
          case ConnectionHealth.healthy:
            healthyCount++;
            break;
          case ConnectionHealth.degraded:
            degradedCount++;
            break;
          case ConnectionHealth.unhealthy:
            unhealthyCount++;
            break;
        }
        
        totalLatency += connection.averageLatency;
        totalActiveConnections += connection.activeConnections;
      }
      
      stats[poolName] = PoolStatistics(
        totalConnections: pool.length,
        healthyConnections: healthyCount,
        degradedConnections: degradedCount,
        unhealthyConnections: unhealthyCount,
        averageLatency: totalLatency / pool.length,
        totalActiveConnections: totalActiveConnections,
      );
    }
    
    return stats;
  }

  /// Shutdown connection pool
  Future<void> shutdown() async {
    try {
      debugPrint('🔄 Shutting down Database Connection Pool...');
      
      // Cancel health check timer
      _healthCheckTimer?.cancel();
      
      // Shutdown all connections
      for (final pool in _pools.values) {
        for (final connection in pool) {
          await connection.shutdown();
        }
      }
      
      // Clear pools
      _pools.clear();
      _roundRobinIndex.clear();
      _connectionHealth.clear();
      
      _isInitialized = false;
      
      debugPrint('✅ Database Connection Pool shutdown complete');
      
    } catch (error) {
      debugPrint('❌ Error during connection pool shutdown: $error');
    }
  }
}

/// Individual database connection
class DatabaseConnection {
  final String id;
  final FirebaseFirestore firestore;
  final String poolName;
  
  // Performance metrics
  double _averageLatency = 0.0;
  int _activeConnections = 0;
  int _totalQueries = 0;
  final List<double> _latencyHistory = [];
  
  // Configuration
  static const int _maxLatencyHistory = 100;
  
  DatabaseConnection({
    required this.id,
    required this.firestore,
    required this.poolName,
  });

  double get averageLatency => _averageLatency;
  int get activeConnections => _activeConnections;
  int get totalQueries => _totalQueries;

  /// Initialize connection
  Future<void> initialize() async {
    try {
      // Configure Firestore settings
      firestore.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 50 * 1024 * 1024, // 50MB cache per connection
      );
      
    } catch (error) {
      debugPrint('❌ Error initializing connection $id: $error');
      rethrow;
    }
  }

  /// Execute query with connection tracking
  Future<T> executeQuery<T>(Future<T> Function() queryFunction) async {
    _activeConnections++;
    _totalQueries++;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await queryFunction();
      
      final latency = stopwatch.elapsedMilliseconds.toDouble();
      updateLatency(latency);
      
      return result;
      
    } finally {
      _activeConnections--;
      stopwatch.stop();
    }
  }

  /// Update latency metrics
  void updateLatency(double latency) {
    _latencyHistory.add(latency);
    
    // Keep only recent latency measurements
    if (_latencyHistory.length > _maxLatencyHistory) {
      _latencyHistory.removeAt(0);
    }
    
    // Calculate average latency
    _averageLatency = _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length;
  }

  /// Get connection statistics
  ConnectionStatistics getStatistics() {
    return ConnectionStatistics(
      id: id,
      poolName: poolName,
      averageLatency: _averageLatency,
      activeConnections: _activeConnections,
      totalQueries: _totalQueries,
      latencyHistory: List.from(_latencyHistory),
    );
  }

  /// Shutdown connection
  Future<void> shutdown() async {
    try {
      // Clear metrics
      _latencyHistory.clear();
      _activeConnections = 0;
      _totalQueries = 0;
      _averageLatency = 0.0;
      
    } catch (error) {
      debugPrint('❌ Error shutting down connection $id: $error');
    }
  }
}

/// Connection health status
enum ConnectionHealth {
  healthy,
  degraded,
  unhealthy,
}

/// Connection strategy
enum ConnectionStrategy {
  roundRobin,
  leastLatency,
  leastConnections,
  random,
}

/// Pool statistics
class PoolStatistics {
  final int totalConnections;
  final int healthyConnections;
  final int degradedConnections;
  final int unhealthyConnections;
  final double averageLatency;
  final int totalActiveConnections;

  PoolStatistics({
    required this.totalConnections,
    required this.healthyConnections,
    required this.degradedConnections,
    required this.unhealthyConnections,
    required this.averageLatency,
    required this.totalActiveConnections,
  });

  double get healthPercentage => (healthyConnections / totalConnections) * 100;
}

/// Connection statistics
class ConnectionStatistics {
  final String id;
  final String poolName;
  final double averageLatency;
  final int activeConnections;
  final int totalQueries;
  final List<double> latencyHistory;

  ConnectionStatistics({
    required this.id,
    required this.poolName,
    required this.averageLatency,
    required this.activeConnections,
    required this.totalQueries,
    required this.latencyHistory,
  });
}