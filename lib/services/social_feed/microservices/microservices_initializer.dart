// Microservices Initializer - Bootstrap all microservices components
// Registers services with DI container and initializes the architecture
import 'package:flutter/foundation.dart';
import '../../../services/performance/cache_service.dart';
import '../../../services/performance/network_optimization_service.dart';
import '../../../services/performance/performance_monitoring_service.dart';
import '../../../services/performance/database_optimization_service.dart';
import 'dependency_injection_container.dart';
import 'service_registry.dart';
import 'api_gateway.dart';
import 'load_balancer.dart';
import 'distributed_tracing.dart';
import 'service_mesh.dart';

/// Microservices architecture initializer
class MicroservicesInitializer {
  static bool _initialized = false;
  static final DependencyInjectionContainer _container = DependencyInjectionContainer.instance;

  /// Initialize the complete microservices architecture
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🚀 Initializing Microservices Architecture...');

      // Phase 1: Register core services with DI container
      await _registerCoreServices();

      // Phase 2: Initialize infrastructure services
      await _initializeInfrastructure();

      // Phase 3: Configure service mesh
      await _configureServiceMesh();

      // Phase 4: Register application services
      await _registerApplicationServices();

      _initialized = true;
      debugPrint('✅ Microservices Architecture initialized successfully');

    } catch (error) {
      debugPrint('❌ Failed to initialize Microservices Architecture: $error');
      rethrow;
    }
  }

  /// Register core infrastructure services
  static Future<void> _registerCoreServices() async {
    debugPrint('📦 Registering core services...');

    // Register singleton services
    _container.registerSingleton<ServiceRegistry>(ServiceRegistry.instance);
    _container.registerSingleton<ApiGateway>(ApiGateway.instance);
    _container.registerSingleton<LoadBalancer>(LoadBalancer.instance);
    _container.registerSingleton<DistributedTracing>(DistributedTracing.instance);
    _container.registerSingleton<ServiceMesh>(ServiceMesh.instance);

    // Register performance services (if not already registered)
    if (!_container.isRegistered<CacheService>()) {
      _container.registerSingleton<CacheService>(CacheService.instance);
    }
    
    if (!_container.isRegistered<NetworkOptimizationService>()) {
      _container.registerSingleton<NetworkOptimizationService>(NetworkOptimizationService.instance);
    }
    
    if (!_container.isRegistered<PerformanceMonitoringService>()) {
      _container.registerSingleton<PerformanceMonitoringService>(PerformanceMonitoringService.instance);
    }
    
    if (!_container.isRegistered<DatabaseOptimizationService>()) {
      _container.registerSingleton<DatabaseOptimizationService>(DatabaseOptimizationService.instance);
    }

    debugPrint('✅ Core services registered');
  }

  /// Initialize infrastructure services
  static Future<void> _initializeInfrastructure() async {
    debugPrint('🏗️ Initializing infrastructure services...');

    // Initialize distributed tracing
    final tracing = _container.resolve<DistributedTracing>();
    await tracing.initialize(
      enabled: true,
      maxSpansInMemory: 1000,
      spanRetentionTime: const Duration(hours: 1),
    );

    // Initialize API gateway
    final apiGateway = _container.resolve<ApiGateway>();
    await apiGateway.initialize();

    // Initialize load balancer
    final loadBalancer = _container.resolve<LoadBalancer>();
    await loadBalancer.initialize();

    debugPrint('✅ Infrastructure services initialized');
  }

  /// Configure service mesh
  static Future<void> _configureServiceMesh() async {
    debugPrint('🔗 Configuring service mesh...');

    final serviceMesh = _container.resolve<ServiceMesh>();
    final serviceRegistry = _container.resolve<ServiceRegistry>();
    final tracing = _container.resolve<DistributedTracing>();

    await serviceMesh.initialize(
      serviceRegistry: serviceRegistry,
      tracing: tracing,
      config: const ServiceMeshConfig(
        enableMutualTLS: true,
        enableTracing: true,
        enableMetrics: true,
        requestTimeout: Duration(seconds: 30),
        maxRetries: 3,
      ),
    );

    debugPrint('✅ Service mesh configured');
  }

  /// Register application services
  static Future<void> _registerApplicationServices() async {
    debugPrint('📱 Registering application services...');

    // Note: AdvancedFeedService will be registered separately to avoid circular dependency

    debugPrint('✅ Application services registered');
  }

  /// Get microservices statistics
  static Map<String, dynamic> getStatistics() {
    if (!_initialized) {
      return {'status': 'not_initialized'};
    }

    try {
      final serviceRegistry = _container.resolve<ServiceRegistry>();
      final apiGateway = _container.resolve<ApiGateway>();
      final loadBalancer = _container.resolve<LoadBalancer>();
      final tracing = _container.resolve<DistributedTracing>();
      final serviceMesh = _container.resolve<ServiceMesh>();

      return {
        'status': 'initialized',
        'container': _container.getStatistics(),
        'serviceRegistry': serviceRegistry.getStatistics(),
        'apiGateway': apiGateway.getStatistics(),
        'loadBalancer': loadBalancer.getAllStatistics(),
        'tracing': tracing.getStatistics(),
        'serviceMesh': serviceMesh.getMetrics(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      return {
        'status': 'error',
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Shutdown microservices architecture
  static Future<void> shutdown() async {
    if (!_initialized) return;

    debugPrint('🔄 Shutting down Microservices Architecture...');

    try {
      // Shutdown in reverse order
      final serviceMesh = _container.tryResolve<ServiceMesh>();
      serviceMesh?.dispose();

      final tracing = _container.tryResolve<DistributedTracing>();
      tracing?.dispose();

      final loadBalancer = _container.tryResolve<LoadBalancer>();
      loadBalancer?.dispose();

      final apiGateway = _container.tryResolve<ApiGateway>();
      apiGateway?.dispose();

      final serviceRegistry = _container.tryResolve<ServiceRegistry>();
      serviceRegistry?.dispose();

      // Shutdown DI container
      await _container.shutdown();

      _initialized = false;
      debugPrint('✅ Microservices Architecture shutdown complete');

    } catch (error) {
      debugPrint('❌ Error during microservices shutdown: $error');
    }
  }

  /// Health check for microservices architecture
  static Future<Map<String, dynamic>> healthCheck() async {
    if (!_initialized) {
      return {
        'status': 'unhealthy',
        'reason': 'not_initialized',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }

    try {
      final serviceRegistry = _container.resolve<ServiceRegistry>();
      final services = serviceRegistry.getAllServices();
      
      final healthyServices = services.where((service) {
        final health = serviceRegistry.getServiceHealth(service.name);
        return health == ServiceHealth.healthy;
      }).length;

      final totalServices = services.length;
      final healthRatio = totalServices > 0 ? healthyServices / totalServices : 1.0;

      String status;
      if (healthRatio >= 0.8) {
        status = 'healthy';
      } else if (healthRatio >= 0.5) {
        status = 'degraded';
      } else {
        status = 'unhealthy';
      }

      return {
        'status': status,
        'healthyServices': healthyServices,
        'totalServices': totalServices,
        'healthRatio': healthRatio,
        'services': services.map((s) => {
          'name': s.name,
          'health': serviceRegistry.getServiceHealth(s.name).name,
        }).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

    } catch (error) {
      return {
        'status': 'unhealthy',
        'reason': 'health_check_failed',
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Check if microservices are initialized
  static bool get isInitialized => _initialized;
}

