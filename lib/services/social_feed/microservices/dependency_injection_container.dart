// Dependency Injection Container - Microservices DI System
// Manages service dependencies and lifecycle
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service lifecycle management
enum ServiceLifecycle {
  singleton,
  transient,
  scoped,
}

/// Service factory function
typedef ServiceFactory<T> = T Function();
typedef AsyncServiceFactory<T> = Future<T> Function();

/// Service registration information
class ServiceRegistration<T> {
  final Type serviceType;
  final ServiceLifecycle lifecycle;
  final ServiceFactory<T>? factory;
  final AsyncServiceFactory<T>? asyncFactory;
  final T? instance;
  final List<Type> dependencies;

  ServiceRegistration({
    required this.serviceType,
    required this.lifecycle,
    this.factory,
    this.asyncFactory,
    this.instance,
    this.dependencies = const [],
  });
}

/// Dependency Injection Container for microservices
class DependencyInjectionContainer {
  static DependencyInjectionContainer? _instance;
  static DependencyInjectionContainer get instance => 
      _instance ??= DependencyInjectionContainer._internal();
  
  DependencyInjectionContainer._internal();

  // Service registrations
  final Map<Type, ServiceRegistration> _registrations = {};
  final Map<Type, dynamic> _singletonInstances = {};
  final Map<String, dynamic> _scopedInstances = {};
  final List<Future<void> Function()> _shutdownHandlers = [];

  // Current scope (for scoped services)
  String? _currentScope;

  /// Register a singleton service
  void registerSingleton<T>(T instance) {
    _registrations[T] = ServiceRegistration<T>(
      serviceType: T,
      lifecycle: ServiceLifecycle.singleton,
      instance: instance,
    );
    _singletonInstances[T] = instance;
    debugPrint('📦 Registered singleton: ${T.toString()}');
  }

  /// Register a singleton service with factory
  void registerSingletonFactory<T>(ServiceFactory<T> factory, {
    List<Type> dependencies = const [],
  }) {
    _registrations[T] = ServiceRegistration<T>(
      serviceType: T,
      lifecycle: ServiceLifecycle.singleton,
      factory: factory,
      dependencies: dependencies,
    );
    debugPrint('🏭 Registered singleton factory: ${T.toString()}');
  }

  /// Register an async singleton service with factory
  void registerSingletonAsyncFactory<T>(AsyncServiceFactory<T> factory, {
    List<Type> dependencies = const [],
  }) {
    _registrations[T] = ServiceRegistration<T>(
      serviceType: T,
      lifecycle: ServiceLifecycle.singleton,
      asyncFactory: factory,
      dependencies: dependencies,
    );
    debugPrint('🏭 Registered async singleton factory: ${T.toString()}');
  }

  /// Register a transient service
  void registerTransient<T>(ServiceFactory<T> factory, {
    List<Type> dependencies = const [],
  }) {
    _registrations[T] = ServiceRegistration<T>(
      serviceType: T,
      lifecycle: ServiceLifecycle.transient,
      factory: factory,
      dependencies: dependencies,
    );
    debugPrint('🔄 Registered transient: ${T.toString()}');
  }

  /// Register a scoped service
  void registerScoped<T>(ServiceFactory<T> factory, {
    List<Type> dependencies = const [],
  }) {
    _registrations[T] = ServiceRegistration<T>(
      serviceType: T,
      lifecycle: ServiceLifecycle.scoped,
      factory: factory,
      dependencies: dependencies,
    );
    debugPrint('🎯 Registered scoped: ${T.toString()}');
  }

  /// Resolve a service instance
  T resolve<T>() {
    final registration = _registrations[T];
    if (registration == null) {
      throw Exception('Service ${T.toString()} is not registered');
    }

    switch (registration.lifecycle) {
      case ServiceLifecycle.singleton:
        return _resolveSingleton<T>(registration as ServiceRegistration<T>);
      case ServiceLifecycle.transient:
        return _resolveTransient<T>(registration as ServiceRegistration<T>);
      case ServiceLifecycle.scoped:
        return _resolveScoped<T>(registration as ServiceRegistration<T>);
    }
  }

  /// Resolve a service instance asynchronously
  Future<T> resolveAsync<T>() async {
    final registration = _registrations[T];
    if (registration == null) {
      throw Exception('Service ${T.toString()} is not registered');
    }

    switch (registration.lifecycle) {
      case ServiceLifecycle.singleton:
        return await _resolveSingletonAsync<T>(registration as ServiceRegistration<T>);
      case ServiceLifecycle.transient:
        return _resolveTransient<T>(registration as ServiceRegistration<T>);
      case ServiceLifecycle.scoped:
        return _resolveScoped<T>(registration as ServiceRegistration<T>);
    }
  }

  /// Try to resolve a service (returns null if not registered)
  T? tryResolve<T>() {
    try {
      return resolve<T>();
    } catch (e) {
      return null;
    }
  }

  /// Check if a service is registered
  bool isRegistered<T>() {
    return _registrations.containsKey(T);
  }

  /// Get all registered service types
  List<Type> getRegisteredTypes() {
    return _registrations.keys.toList();
  }

  /// Create a new scope
  void createScope(String scopeName) {
    _currentScope = scopeName;
    _scopedInstances.clear();
    debugPrint('🎯 Created scope: $scopeName');
  }

  /// Dispose current scope
  void disposeScope() {
    if (_currentScope != null) {
      _scopedInstances.clear();
      debugPrint('🗑️ Disposed scope: $_currentScope');
      _currentScope = null;
    }
  }

  /// Register shutdown handler
  void registerShutdownHandler(String name, Future<void> Function() handler) {
    _shutdownHandlers.add(handler);
    debugPrint('🔚 Registered shutdown handler: $name');
  }

  /// Shutdown all services
  Future<void> shutdown() async {
    debugPrint('🔄 Shutting down DI container...');
    
    // Execute shutdown handlers
    for (final handler in _shutdownHandlers) {
      try {
        await handler();
      } catch (error) {
        debugPrint('❌ Shutdown handler error: $error');
      }
    }

    // Dispose scoped instances
    disposeScope();

    // Clear singleton instances
    _singletonInstances.clear();

    debugPrint('✅ DI container shutdown complete');
  }

  // Private resolution methods

  T _resolveSingleton<T>(ServiceRegistration<T> registration) {
    // Check if instance already exists
    if (_singletonInstances.containsKey(T)) {
      return _singletonInstances[T] as T;
    }

    // Create new instance
    T instance;
    if (registration.instance != null) {
      instance = registration.instance!;
    } else if (registration.factory != null) {
      // Resolve dependencies first
      _resolveDependencies(registration.dependencies);
      instance = registration.factory!();
    } else {
      throw Exception('No factory or instance provided for singleton ${T.toString()}');
    }

    _singletonInstances[T] = instance;
    return instance;
  }

  Future<T> _resolveSingletonAsync<T>(ServiceRegistration<T> registration) async {
    // Check if instance already exists
    if (_singletonInstances.containsKey(T)) {
      return _singletonInstances[T] as T;
    }

    // Create new instance
    T instance;
    if (registration.instance != null) {
      instance = registration.instance!;
    } else if (registration.asyncFactory != null) {
      // Resolve dependencies first
      await _resolveDependenciesAsync(registration.dependencies);
      instance = await registration.asyncFactory!();
    } else if (registration.factory != null) {
      // Resolve dependencies first
      _resolveDependencies(registration.dependencies);
      instance = registration.factory!();
    } else {
      throw Exception('No factory or instance provided for singleton ${T.toString()}');
    }

    _singletonInstances[T] = instance;
    return instance;
  }

  T _resolveTransient<T>(ServiceRegistration<T> registration) {
    if (registration.factory == null) {
      throw Exception('No factory provided for transient ${T.toString()}');
    }

    // Resolve dependencies
    _resolveDependencies(registration.dependencies);
    
    return registration.factory!();
  }

  T _resolveScoped<T>(ServiceRegistration<T> registration) {
    if (_currentScope == null) {
      throw Exception('No active scope for scoped service ${T.toString()}');
    }

    final scopeKey = '${_currentScope}_${T.toString()}';
    
    // Check if instance exists in current scope
    if (_scopedInstances.containsKey(scopeKey)) {
      return _scopedInstances[scopeKey] as T;
    }

    if (registration.factory == null) {
      throw Exception('No factory provided for scoped ${T.toString()}');
    }

    // Resolve dependencies
    _resolveDependencies(registration.dependencies);
    
    final instance = registration.factory!();
    _scopedInstances[scopeKey] = instance;
    
    return instance;
  }

  void _resolveDependencies(List<Type> dependencies) {
    for (final dependency in dependencies) {
      if (!_registrations.containsKey(dependency)) {
        throw Exception('Dependency ${dependency.toString()} is not registered');
      }
      // Dependencies are resolved lazily when needed
    }
  }

  Future<void> _resolveDependenciesAsync(List<Type> dependencies) async {
    for (final dependency in dependencies) {
      if (!_registrations.containsKey(dependency)) {
        throw Exception('Dependency ${dependency.toString()} is not registered');
      }
      // Dependencies are resolved lazily when needed
    }
  }

  /// Get container statistics
  Map<String, dynamic> getStatistics() {
    final lifecycleCounts = <String, int>{};
    for (final lifecycle in ServiceLifecycle.values) {
      lifecycleCounts[lifecycle.name] = 0;
    }

    for (final registration in _registrations.values) {
      lifecycleCounts[registration.lifecycle.name] = 
          (lifecycleCounts[registration.lifecycle.name] ?? 0) + 1;
    }

    return {
      'totalRegistrations': _registrations.length,
      'singletonInstances': _singletonInstances.length,
      'scopedInstances': _scopedInstances.length,
      'currentScope': _currentScope,
      'lifecycleCounts': lifecycleCounts,
      'shutdownHandlers': _shutdownHandlers.length,
    };
  }
}