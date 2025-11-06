// Memory Management Service - Centralized resource cleanup and memory optimization
// Comprehensive memory management for TALOWA platform performance optimization

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for managing memory usage and resource cleanup
class MemoryManagementService {
  static MemoryManagementService? _instance;
  static MemoryManagementService get instance => _instance ??= MemoryManagementService._internal();
  
  MemoryManagementService._internal();
  
  // Resource tracking
  final Set<DisposableResource> _trackedResources = {};
  final Map<String, MemoryUsageSnapshot> _memorySnapshots = {};
  
  // Memory monitoring
  Timer? _memoryMonitoringTimer;
  int _currentMemoryUsageMB = 0;
  int _peakMemoryUsageMB = 0;
  
  // Configuration
  static const Duration monitoringInterval = Duration(seconds: 30);
  static const int memoryWarningThresholdMB = 150;
  static const int memoryCriticalThresholdMB = 200;
  static const int maxTrackedResources = 1000;
  
  /// Initialize memory management service
  static Future<void> initialize() async {
    try {
      debugPrint('🧠 Initializing Memory Management Service...');
      
      final service = instance;
      
      // Start memory monitoring
      service._startMemoryMonitoring();
      
      // Setup memory pressure listener
      service._setupMemoryPressureListener();
      
      // Take initial memory snapshot
      await service._takeMemorySnapshot('initialization');
      
      debugPrint('✅ Memory Management Service initialized');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize memory management: $e');
    }
  }
  
  /// Register a disposable resource for tracking
  void registerResource(DisposableResource resource) {
    if (_trackedResources.length >= maxTrackedResources) {
      debugPrint('⚠️ Maximum tracked resources reached, cleaning up old resources');
      _cleanupOldResources();
    }
    
    _trackedResources.add(resource);
    debugPrint('📝 Registered resource: ${resource.resourceId} (${resource.resourceType})');
  }
  
  /// Unregister a disposable resource
  void unregisterResource(DisposableResource resource) {
    if (_trackedResources.remove(resource)) {
      debugPrint('🗑️ Unregistered resource: ${resource.resourceId}');
    }
  }
  
  /// Dispose all tracked resources
  Future<void> disposeAllResources() async {
    debugPrint('🧹 Disposing all tracked resources: ${_trackedResources.length}');
    
    final resources = List<DisposableResource>.from(_trackedResources);
    _trackedResources.clear();
    
    for (final resource in resources) {
      try {
        await resource.dispose();
        debugPrint('✅ Disposed resource: ${resource.resourceId}');
      } catch (e) {
        debugPrint('❌ Failed to dispose resource ${resource.resourceId}: $e');
      }
    }
  }
  
  /// Dispose resources of a specific type
  Future<void> disposeResourcesByType(String resourceType) async {
    final resourcesOfType = _trackedResources
        .where((resource) => resource.resourceType == resourceType)
        .toList();
    
    debugPrint('🧹 Disposing ${resourcesOfType.length} resources of type: $resourceType');
    
    for (final resource in resourcesOfType) {
      try {
        await resource.dispose();
        _trackedResources.remove(resource);
        debugPrint('✅ Disposed $resourceType resource: ${resource.resourceId}');
      } catch (e) {
        debugPrint('❌ Failed to dispose $resourceType resource ${resource.resourceId}: $e');
      }
    }
  }
  
  /// Force garbage collection
  void forceGarbageCollection() {
    debugPrint('🗑️ Forcing garbage collection...');
    
    // Clear weak references and trigger GC
    if (!kIsWeb) {
      // Platform-specific GC hints
      SystemChannels.platform.invokeMethod('System.gc');
    }
    
    // Clear internal caches
    _cleanupInternalCaches();
    
    debugPrint('✅ Garbage collection completed');
  }
  
  /// Take memory usage snapshot
  Future<void> takeMemorySnapshot(String label) async {
    await _takeMemorySnapshot(label);
  }
  
  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStatistics() {
    return {
      'currentMemoryUsageMB': _currentMemoryUsageMB,
      'peakMemoryUsageMB': _peakMemoryUsageMB,
      'trackedResources': _trackedResources.length,
      'memorySnapshots': _memorySnapshots.length,
      'memoryWarningThresholdMB': memoryWarningThresholdMB,
      'memoryCriticalThresholdMB': memoryCriticalThresholdMB,
      'resourcesByType': _getResourcesByType(),
    };
  }
  
  /// Get resources grouped by type
  Map<String, int> _getResourcesByType() {
    final resourcesByType = <String, int>{};
    
    for (final resource in _trackedResources) {
      resourcesByType[resource.resourceType] = 
          (resourcesByType[resource.resourceType] ?? 0) + 1;
    }
    
    return resourcesByType;
  }
  
  /// Start memory monitoring
  void _startMemoryMonitoring() {
    _memoryMonitoringTimer = Timer.periodic(monitoringInterval, (timer) async {
      await _monitorMemoryUsage();
    });
    
    debugPrint('📊 Memory monitoring started');
  }
  
  /// Monitor memory usage
  Future<void> _monitorMemoryUsage() async {
    try {
      // Get current memory usage (platform-specific)
      final memoryInfo = await _getCurrentMemoryUsage();
      _currentMemoryUsageMB = memoryInfo['currentMB'] ?? 0;
      
      // Update peak usage
      if (_currentMemoryUsageMB > _peakMemoryUsageMB) {
        _peakMemoryUsageMB = _currentMemoryUsageMB;
      }
      
      // Check thresholds
      if (_currentMemoryUsageMB > memoryCriticalThresholdMB) {
        debugPrint('🚨 CRITICAL: Memory usage ${_currentMemoryUsageMB}MB exceeds critical threshold');
        await _handleCriticalMemoryPressure();
      } else if (_currentMemoryUsageMB > memoryWarningThresholdMB) {
        debugPrint('⚠️ WARNING: Memory usage ${_currentMemoryUsageMB}MB exceeds warning threshold');
        await _handleMemoryWarning();
      }
      
    } catch (e) {
      debugPrint('❌ Memory monitoring error: $e');
    }
  }
  
  /// Get current memory usage
  Future<Map<String, int>> _getCurrentMemoryUsage() async {
    try {
      // Only try platform-specific memory info on mobile platforms
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          final result = await SystemChannels.platform.invokeMethod('System.getMemoryInfo');
          return {
            'currentMB': (result['usedMemoryBytes'] ?? 0) ~/ (1024 * 1024),
            'availableMB': (result['availableMemoryBytes'] ?? 0) ~/ (1024 * 1024),
          };
        } catch (e) {
          debugPrint('Platform memory info not available: $e');
        }
      }
    } catch (e) {
      debugPrint('Error accessing platform memory info: $e');
    }
    
    // Fallback estimation for web and other platforms
    return {
      'currentMB': _trackedResources.length * 2, // Rough estimation
      'availableMB': kIsWeb ? 1024 : 512, // Higher estimate for web
    };
  }
  
  /// Handle memory warning
  Future<void> _handleMemoryWarning() async {
    debugPrint('⚠️ Handling memory warning...');
    
    // Clean up expired resources
    await _cleanupExpiredResources();
    
    // Clear non-essential caches
    _cleanupInternalCaches();
    
    // Take memory snapshot for analysis
    await _takeMemorySnapshot('memory_warning');
  }
  
  /// Handle critical memory pressure
  Future<void> _handleCriticalMemoryPressure() async {
    debugPrint('🚨 Handling critical memory pressure...');
    
    // Aggressive cleanup
    await _cleanupExpiredResources();
    await disposeResourcesByType('cache');
    await disposeResourcesByType('image');
    
    // Force garbage collection
    forceGarbageCollection();
    
    // Take memory snapshot
    await _takeMemorySnapshot('critical_memory_pressure');
  }
  
  /// Setup memory pressure listener
  void _setupMemoryPressureListener() {
    if (!kIsWeb) {
      // Listen for system memory pressure events
      SystemChannels.lifecycle.setMessageHandler((message) async {
        if (message == 'AppLifecycleState.paused') {
          await _handleMemoryWarning();
        }
        return null;
      });
    }
  }
  
  /// Cleanup expired resources
  Future<void> _cleanupExpiredResources() async {
    final expiredResources = _trackedResources
        .where((resource) => resource.isExpired)
        .toList();
    
    if (expiredResources.isNotEmpty) {
      debugPrint('🧹 Cleaning up ${expiredResources.length} expired resources');
      
      for (final resource in expiredResources) {
        try {
          await resource.dispose();
          _trackedResources.remove(resource);
        } catch (e) {
          debugPrint('❌ Failed to cleanup expired resource: $e');
        }
      }
    }
  }
  
  /// Cleanup old resources when limit is reached
  void _cleanupOldResources() {
    final sortedResources = _trackedResources.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    final resourcesToRemove = sortedResources.take(100).toList();
    
    for (final resource in resourcesToRemove) {
      resource.dispose();
      _trackedResources.remove(resource);
    }
    
    debugPrint('🧹 Cleaned up ${resourcesToRemove.length} old resources');
  }
  
  /// Cleanup internal caches
  void _cleanupInternalCaches() {
    // Keep only recent memory snapshots
    if (_memorySnapshots.length > 10) {
      final sortedSnapshots = _memorySnapshots.entries.toList()
        ..sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));
      
      _memorySnapshots.clear();
      for (int i = 0; i < 10 && i < sortedSnapshots.length; i++) {
        _memorySnapshots[sortedSnapshots[i].key] = sortedSnapshots[i].value;
      }
    }
  }
  
  /// Take memory snapshot
  Future<void> _takeMemorySnapshot(String label) async {
    final memoryInfo = await _getCurrentMemoryUsage();
    
    final snapshot = MemoryUsageSnapshot(
      label: label,
      timestamp: DateTime.now(),
      memoryUsageMB: memoryInfo['currentMB'] ?? 0,
      availableMemoryMB: memoryInfo['availableMB'] ?? 0,
      trackedResourcesCount: _trackedResources.length,
      resourcesByType: _getResourcesByType(),
    );
    
    _memorySnapshots[label] = snapshot;
    
    debugPrint('📸 Memory snapshot taken: $label (${snapshot.memoryUsageMB}MB)');
  }
  
  /// Dispose memory management service
  Future<void> dispose() async {
    debugPrint('🧹 Disposing Memory Management Service...');
    
    _memoryMonitoringTimer?.cancel();
    await disposeAllResources();
    _memorySnapshots.clear();
    
    debugPrint('✅ Memory Management Service disposed');
  }
}

/// Base class for disposable resources
abstract class DisposableResource {
  final String resourceId;
  final String resourceType;
  final DateTime createdAt;
  final Duration? expirationDuration;
  
  DisposableResource({
    required this.resourceId,
    required this.resourceType,
    this.expirationDuration,
  }) : createdAt = DateTime.now();
  
  /// Check if resource is expired
  bool get isExpired {
    if (expirationDuration == null) return false;
    return DateTime.now().difference(createdAt) > expirationDuration!;
  }
  
  /// Dispose the resource
  Future<void> dispose();
}

/// Memory usage snapshot
class MemoryUsageSnapshot {
  final String label;
  final DateTime timestamp;
  final int memoryUsageMB;
  final int availableMemoryMB;
  final int trackedResourcesCount;
  final Map<String, int> resourcesByType;
  
  MemoryUsageSnapshot({
    required this.label,
    required this.timestamp,
    required this.memoryUsageMB,
    required this.availableMemoryMB,
    required this.trackedResourcesCount,
    required this.resourcesByType,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'timestamp': timestamp.toIso8601String(),
      'memoryUsageMB': memoryUsageMB,
      'availableMemoryMB': availableMemoryMB,
      'trackedResourcesCount': trackedResourcesCount,
      'resourcesByType': resourcesByType,
    };
  }
}

/// Extension to add missing methods to MemoryManagementService
extension MemoryManagementServiceExtensions on MemoryManagementService {
  /// Clear cache for better memory management
  Future<void> clearCache() async {
    debugPrint('🧹 Clearing cache for memory management');
    await disposeAllResources();
    debugPrint('✅ Cache cleared successfully');
  }

  /// Clean up old posts to manage memory
  void cleanupOldPosts(List<dynamic> posts, {int maxPosts = 50}) {
    debugPrint('🧹 Cleaning up old posts - Current: ${posts.length}, Max: $maxPosts');
    
    if (posts.length > maxPosts) {
      final itemsToRemove = posts.length - maxPosts;
      posts.removeRange(0, itemsToRemove);
      debugPrint('✅ Removed $itemsToRemove old posts, remaining: ${posts.length}');
    } else {
      debugPrint('ℹ️ No cleanup needed, posts count within limit');
    }
  }
}