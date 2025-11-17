// Service Registry - Microservices Service Discovery
// Manages service registration, discovery, and health monitoring
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service information model
class ServiceInfo {
  final String name;
  final String version;
  final String endpoint;
  final String healthCheckUrl;
  final List<String> capabilities;
  final Map<String, dynamic> metadata;
  final DateTime registeredAt;

  ServiceInfo({
    required this.name,
    required this.version,
    required this.endpoint,
    required this.healthCheckUrl,
    required this.capabilities,
    this.metadata = const {},
    DateTime? registeredAt,
  }) : registeredAt = registeredAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'endpoint': endpoint,
    'healthCheckUrl': healthCheckUrl,
    'capabilities': capabilities,
    'metadata': metadata,
    'registeredAt': registeredAt.toIso8601String(),
  };

  factory ServiceInfo.fromJson(Map<String, dynamic> json) => ServiceInfo(
    name: json['name'],
    version: json['version'],
    endpoint: json['endpoint'],
    healthCheckUrl: json['healthCheckUrl'],
    capabilities: List<String>.from(json['capabilities']),
    metadata: json['metadata'] ?? {},
    registeredAt: DateTime.parse(json['registeredAt']),
  );
}

/// Service health status
enum ServiceHealth {
  healthy,
  degraded,
  unhealthy,
  unknown,
}

/// Service health report
class ServiceHealthReport {
  final String serviceName;
  final ServiceHealth status;
  final String? message;
  final Map<String, dynamic> metrics;
  final DateTime timestamp;

  ServiceHealthReport({
    required this.serviceName,
    required this.status,
    this.message,
    this.metrics = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'serviceName': serviceName,
    'status': status.name,
    'message': message,
    'metrics': metrics,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Service Registry for microservices architecture
class ServiceRegistry {
  static ServiceRegistry? _instance;
  static ServiceRegistry get instance => _instance ??= ServiceRegistry._internal();
  
  ServiceRegistry._internal();

  // Registered services
  final Map<String, ServiceInfo> _services = {};
  final Map<String, ServiceHealthReport> _healthReports = {};
  final Map<String, Timer> _healthCheckTimers = {};

  // Event streams
  final StreamController<ServiceInfo> _serviceRegisteredController = 
      StreamController<ServiceInfo>.broadcast();
  final StreamController<String> _serviceDeregisteredController = 
      StreamController<String>.broadcast();
  final StreamController<ServiceHealthReport> _healthReportController = 
      StreamController<ServiceHealthReport>.broadcast();

  // Configuration
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _serviceTimeout = Duration(minutes: 5);

  /// Stream of service registration events
  Stream<ServiceInfo> get serviceRegistered => _serviceRegisteredController.stream;

  /// Stream of service deregistration events
  Stream<String> get serviceDeregistered => _serviceDeregisteredController.stream;

  /// Stream of health report events
  Stream<ServiceHealthReport> get healthReports => _healthReportController.stream;

  /// Register a service with the registry
  Future<void> registerService(String serviceName, ServiceInfo serviceInfo) async {
    try {
      _services[serviceName] = serviceInfo;
      
      // Start health monitoring
      _startHealthMonitoring(serviceName);
      
      // Notify listeners
      _serviceRegisteredController.add(serviceInfo);
      
      debugPrint('✅ Service registered: $serviceName');
      
    } catch (error) {
      debugPrint('❌ Failed to register service $serviceName: $error');
      rethrow;
    }
  }

  /// Deregister a service from the registry
  Future<void> deregisterService(String serviceName) async {
    try {
      _services.remove(serviceName);
      _healthReports.remove(serviceName);
      
      // Stop health monitoring
      _healthCheckTimers[serviceName]?.cancel();
      _healthCheckTimers.remove(serviceName);
      
      // Notify listeners
      _serviceDeregisteredController.add(serviceName);
      
      debugPrint('✅ Service deregistered: $serviceName');
      
    } catch (error) {
      debugPrint('❌ Failed to deregister service $serviceName: $error');
      rethrow;
    }
  }

  /// Get service information by name
  ServiceInfo? getService(String serviceName) {
    return _services[serviceName];
  }

  /// Get all registered services
  List<ServiceInfo> getAllServices() {
    return _services.values.toList();
  }

  /// Get services by capability
  List<ServiceInfo> getServicesByCapability(String capability) {
    return _services.values
        .where((service) => service.capabilities.contains(capability))
        .toList();
  }

  /// Get healthy services
  List<ServiceInfo> getHealthyServices() {
    return _services.values
        .where((service) {
          final health = _healthReports[service.name];
          return health?.status == ServiceHealth.healthy;
        })
        .toList();
  }

  /// Report service health
  Future<void> reportHealth(String serviceName, ServiceHealth status, {
    String? message,
    Map<String, dynamic>? metrics,
  }) async {
    try {
      final report = ServiceHealthReport(
        serviceName: serviceName,
        status: status,
        message: message,
        metrics: metrics ?? {},
      );
      
      _healthReports[serviceName] = report;
      _healthReportController.add(report);
      
      debugPrint('📊 Health report for $serviceName: ${status.name}');
      
    } catch (error) {
      debugPrint('❌ Failed to report health for $serviceName: $error');
    }
  }

  /// Get service health status
  ServiceHealth getServiceHealth(String serviceName) {
    final report = _healthReports[serviceName];
    return report?.status ?? ServiceHealth.unknown;
  }

  /// Get service health report
  ServiceHealthReport? getHealthReport(String serviceName) {
    return _healthReports[serviceName];
  }

  /// Start health monitoring for a service
  void _startHealthMonitoring(String serviceName) {
    _healthCheckTimers[serviceName]?.cancel();
    
    _healthCheckTimers[serviceName] = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck(serviceName);
    });
  }

  /// Perform health check for a service
  Future<void> _performHealthCheck(String serviceName) async {
    try {
      final service = _services[serviceName];
      if (service == null) {
        // Service no longer exists, stop health check
        return;
      }

      // Check if service has been inactive for too long
      final lastReport = _healthReports[serviceName];
      if (lastReport != null) {
        final timeSinceLastReport = DateTime.now().difference(lastReport.timestamp);
        if (timeSinceLastReport > _serviceTimeout) {
          await reportHealth(serviceName, ServiceHealth.unhealthy, 
              message: 'Service timeout - no health reports received');
          return;
        }
      }

      // For internal services, assume healthy if recently registered
      final timeSinceRegistration = DateTime.now().difference(service.registeredAt);
      if (timeSinceRegistration < _serviceTimeout && lastReport == null) {
        await reportHealth(serviceName, ServiceHealth.healthy, 
            message: 'Service recently registered');
      }

    } catch (error) {
      debugPrint('❌ Health check failed for $serviceName: $error');
      await reportHealth(serviceName, ServiceHealth.unhealthy, 
          message: 'Health check failed: $error');
    }
  }

  /// Get service registry statistics
  Map<String, dynamic> getStatistics() {
    final healthCounts = <String, int>{};
    for (final status in ServiceHealth.values) {
      healthCounts[status.name] = 0;
    }

    for (final report in _healthReports.values) {
      healthCounts[report.status.name] = (healthCounts[report.status.name] ?? 0) + 1;
    }

    return {
      'totalServices': _services.length,
      'healthStatus': healthCounts,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _healthCheckTimers.values) {
      timer.cancel();
    }
    _healthCheckTimers.clear();
    
    _serviceRegisteredController.close();
    _serviceDeregisteredController.close();
    _healthReportController.close();
  }
}