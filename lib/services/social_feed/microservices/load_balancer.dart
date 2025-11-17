// Load Balancer - Microservices Traffic Distribution
// Distributes requests across multiple service instances with health checks
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Load balancing strategies
enum LoadBalancingStrategy {
  roundRobin,
  leastConnections,
  weightedRoundRobin,
  random,
  healthBased,
}

/// Service endpoint information
class ServiceEndpoint {
  final String url;
  final int weight;
  final Map<String, dynamic> metadata;
  
  bool isHealthy;
  int activeConnections;
  DateTime lastHealthCheck;
  Duration averageResponseTime;
  int totalRequests;
  int failedRequests;

  ServiceEndpoint({
    required this.url,
    this.weight = 1,
    this.metadata = const {},
    this.isHealthy = true,
    this.activeConnections = 0,
    DateTime? lastHealthCheck,
    this.averageResponseTime = const Duration(milliseconds: 100),
    this.totalRequests = 0,
    this.failedRequests = 0,
  }) : lastHealthCheck = lastHealthCheck ?? DateTime.now();

  double get successRate {
    if (totalRequests == 0) return 1.0;
    return (totalRequests - failedRequests) / totalRequests;
  }

  double get healthScore {
    if (!isHealthy) return 0.0;
    
    final responseScore = 1.0 - (averageResponseTime.inMilliseconds / 5000.0).clamp(0.0, 1.0);
    final successScore = successRate;
    final connectionScore = 1.0 - (activeConnections / 100.0).clamp(0.0, 1.0);
    
    return (responseScore + successScore + connectionScore) / 3.0;
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'weight': weight,
    'isHealthy': isHealthy,
    'activeConnections': activeConnections,
    'lastHealthCheck': lastHealthCheck.toIso8601String(),
    'averageResponseTime': averageResponseTime.inMilliseconds,
    'totalRequests': totalRequests,
    'failedRequests': failedRequests,
    'successRate': successRate,
    'healthScore': healthScore,
    'metadata': metadata,
  };
}

/// Load balancer for microservices
class LoadBalancer {
  static LoadBalancer? _instance;
  static LoadBalancer get instance => _instance ??= LoadBalancer._internal();
  
  LoadBalancer._internal();

  // Service endpoints by service name
  final Map<String, List<ServiceEndpoint>> _serviceEndpoints = {};
  final Map<String, int> _roundRobinCounters = {};
  final Map<String, LoadBalancingStrategy> _strategies = {};

  // Health check configuration
  Timer? _healthCheckTimer;
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _healthCheckTimeout = Duration(seconds: 5);

  /// Initialize load balancer
  Future<void> initialize() async {
    // Start health check timer
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthChecks();
    });

    debugPrint('✅ Load Balancer initialized');
  }

  /// Register service endpoints
  Future<void> registerService(
    String serviceName,
    List<String> endpoints, {
    LoadBalancingStrategy strategy = LoadBalancingStrategy.roundRobin,
    Map<String, int>? weights,
  }) async {
    final serviceEndpoints = <ServiceEndpoint>[];
    
    for (int i = 0; i < endpoints.length; i++) {
      final endpoint = endpoints[i];
      final weight = weights?[endpoint] ?? 1;
      
      serviceEndpoints.add(ServiceEndpoint(
        url: endpoint,
        weight: weight,
      ));
    }

    _serviceEndpoints[serviceName] = serviceEndpoints;
    _strategies[serviceName] = strategy;
    _roundRobinCounters[serviceName] = 0;

    debugPrint('⚖️ Registered $serviceName with ${endpoints.length} endpoints');
  }

  /// Get healthy endpoint for service
  Future<String> getHealthyEndpoint(String serviceName) async {
    final endpoints = _serviceEndpoints[serviceName];
    if (endpoints == null || endpoints.isEmpty) {
      throw Exception('No endpoints registered for service: $serviceName');
    }

    final strategy = _strategies[serviceName] ?? LoadBalancingStrategy.roundRobin;
    final healthyEndpoints = endpoints.where((e) => e.isHealthy).toList();

    if (healthyEndpoints.isEmpty) {
      // Fallback to any endpoint if none are healthy
      debugPrint('⚠️ No healthy endpoints for $serviceName, using fallback');
      return endpoints.first.url;
    }

    final selectedEndpoint = _selectEndpoint(healthyEndpoints, strategy, serviceName);
    selectedEndpoint.activeConnections++;
    
    return selectedEndpoint.url;
  }

  /// Release endpoint connection
  void releaseEndpoint(String serviceName, String endpointUrl) {
    final endpoints = _serviceEndpoints[serviceName];
    if (endpoints != null) {
      final endpoint = endpoints.firstWhere(
        (e) => e.url == endpointUrl,
        orElse: () => endpoints.first,
      );
      
      if (endpoint.activeConnections > 0) {
        endpoint.activeConnections--;
      }
    }
  }

  /// Report endpoint performance
  void reportEndpointPerformance(
    String serviceName,
    String endpointUrl,
    Duration responseTime,
    bool success,
  ) {
    final endpoints = _serviceEndpoints[serviceName];
    if (endpoints != null) {
      final endpoint = endpoints.firstWhere(
        (e) => e.url == endpointUrl,
        orElse: () => endpoints.first,
      );

      endpoint.totalRequests++;
      if (!success) {
        endpoint.failedRequests++;
      }

      // Update average response time (exponential moving average)
      const alpha = 0.1; // Smoothing factor
      final newAverage = Duration(
        milliseconds: ((1 - alpha) * endpoint.averageResponseTime.inMilliseconds + 
                      alpha * responseTime.inMilliseconds).round(),
      );
      endpoint.averageResponseTime = newAverage;
    }
  }

  /// Select endpoint based on strategy
  ServiceEndpoint _selectEndpoint(
    List<ServiceEndpoint> endpoints,
    LoadBalancingStrategy strategy,
    String serviceName,
  ) {
    switch (strategy) {
      case LoadBalancingStrategy.roundRobin:
        return _selectRoundRobin(endpoints, serviceName);
      case LoadBalancingStrategy.leastConnections:
        return _selectLeastConnections(endpoints);
      case LoadBalancingStrategy.weightedRoundRobin:
        return _selectWeightedRoundRobin(endpoints, serviceName);
      case LoadBalancingStrategy.random:
        return _selectRandom(endpoints);
      case LoadBalancingStrategy.healthBased:
        return _selectHealthBased(endpoints);
    }
  }

  ServiceEndpoint _selectRoundRobin(List<ServiceEndpoint> endpoints, String serviceName) {
    final counter = _roundRobinCounters[serviceName] ?? 0;
    final selectedIndex = counter % endpoints.length;
    _roundRobinCounters[serviceName] = counter + 1;
    return endpoints[selectedIndex];
  }

  ServiceEndpoint _selectLeastConnections(List<ServiceEndpoint> endpoints) {
    return endpoints.reduce((a, b) => 
      a.activeConnections <= b.activeConnections ? a : b);
  }

  ServiceEndpoint _selectWeightedRoundRobin(List<ServiceEndpoint> endpoints, String serviceName) {
    final totalWeight = endpoints.fold<int>(0, (sum, e) => sum + e.weight);
    final counter = _roundRobinCounters[serviceName] ?? 0;
    final targetWeight = counter % totalWeight;
    
    int currentWeight = 0;
    for (final endpoint in endpoints) {
      currentWeight += endpoint.weight;
      if (currentWeight > targetWeight) {
        _roundRobinCounters[serviceName] = counter + 1;
        return endpoint;
      }
    }
    
    return endpoints.first;
  }

  ServiceEndpoint _selectRandom(List<ServiceEndpoint> endpoints) {
    final random = Random();
    return endpoints[random.nextInt(endpoints.length)];
  }

  ServiceEndpoint _selectHealthBased(List<ServiceEndpoint> endpoints) {
    // Select endpoint with highest health score
    return endpoints.reduce((a, b) => 
      a.healthScore >= b.healthScore ? a : b);
  }

  /// Perform health checks on all endpoints
  Future<void> _performHealthChecks() async {
    for (final serviceName in _serviceEndpoints.keys) {
      final endpoints = _serviceEndpoints[serviceName]!;
      
      for (final endpoint in endpoints) {
        await _checkEndpointHealth(endpoint);
      }
    }
  }

  /// Check health of individual endpoint
  Future<void> _checkEndpointHealth(ServiceEndpoint endpoint) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // For internal services, assume healthy if recently active
      final timeSinceLastCheck = DateTime.now().difference(endpoint.lastHealthCheck);
      if (timeSinceLastCheck < const Duration(minutes: 2)) {
        endpoint.isHealthy = true;
        endpoint.lastHealthCheck = DateTime.now();
        return;
      }

      // Simulate health check for internal services
      if (endpoint.url.startsWith('internal://')) {
        endpoint.isHealthy = true;
        endpoint.lastHealthCheck = DateTime.now();
        
        // Update response time based on current load
        final loadFactor = (endpoint.activeConnections / 10.0).clamp(0.0, 1.0);
        final simulatedResponseTime = Duration(
          milliseconds: (50 + loadFactor * 200).round(),
        );
        
        const alpha = 0.1;
        endpoint.averageResponseTime = Duration(
          milliseconds: ((1 - alpha) * endpoint.averageResponseTime.inMilliseconds + 
                        alpha * simulatedResponseTime.inMilliseconds).round(),
        );
        
        return;
      }

      // For external endpoints, would perform actual HTTP health check
      // This is a placeholder for demonstration
      endpoint.isHealthy = true;
      endpoint.lastHealthCheck = DateTime.now();
      
      stopwatch.stop();
      
    } catch (error) {
      debugPrint('❌ Health check failed for ${endpoint.url}: $error');
      endpoint.isHealthy = false;
      endpoint.lastHealthCheck = DateTime.now();
    }
  }

  /// Get service statistics
  Map<String, dynamic> getServiceStatistics(String serviceName) {
    final endpoints = _serviceEndpoints[serviceName];
    if (endpoints == null) {
      return {};
    }

    final healthyCount = endpoints.where((e) => e.isHealthy).length;
    final totalConnections = endpoints.fold<int>(0, (sum, e) => sum + e.activeConnections);
    final totalRequests = endpoints.fold<int>(0, (sum, e) => sum + e.totalRequests);
    final totalFailures = endpoints.fold<int>(0, (sum, e) => sum + e.failedRequests);
    
    final averageResponseTime = endpoints.isNotEmpty
        ? endpoints.fold<int>(0, (sum, e) => sum + e.averageResponseTime.inMilliseconds) / endpoints.length
        : 0;

    return {
      'serviceName': serviceName,
      'strategy': _strategies[serviceName]?.name,
      'totalEndpoints': endpoints.length,
      'healthyEndpoints': healthyCount,
      'totalConnections': totalConnections,
      'totalRequests': totalRequests,
      'totalFailures': totalFailures,
      'successRate': totalRequests > 0 ? (totalRequests - totalFailures) / totalRequests : 1.0,
      'averageResponseTime': averageResponseTime,
      'endpoints': endpoints.map((e) => e.toJson()).toList(),
    };
  }

  /// Get all services statistics
  Map<String, dynamic> getAllStatistics() {
    final stats = <String, dynamic>{};
    
    for (final serviceName in _serviceEndpoints.keys) {
      stats[serviceName] = getServiceStatistics(serviceName);
    }

    return {
      'services': stats,
      'totalServices': _serviceEndpoints.length,
      'lastHealthCheck': DateTime.now().toIso8601String(),
    };
  }

  /// Update load balancing strategy for service
  void updateStrategy(String serviceName, LoadBalancingStrategy strategy) {
    _strategies[serviceName] = strategy;
    debugPrint('⚖️ Updated strategy for $serviceName to ${strategy.name}');
  }

  /// Remove service endpoints
  void removeService(String serviceName) {
    _serviceEndpoints.remove(serviceName);
    _strategies.remove(serviceName);
    _roundRobinCounters.remove(serviceName);
    debugPrint('🗑️ Removed service: $serviceName');
  }

  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _serviceEndpoints.clear();
    _strategies.clear();
    _roundRobinCounters.clear();
  }
}