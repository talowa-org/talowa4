import 'dart:async';
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'performance_monitor.dart';

/// HTTP Interceptor for automatic performance monitoring
/// Tracks all network requests and responses
class PerformanceInterceptor extends Interceptor {
  final PerformanceMonitor _monitor = PerformanceMonitor();
  final Map<RequestOptions, DateTime> _requestStartTimes = {};
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Record request start time
    _requestStartTimes[options] = DateTime.now();
    
    // Start monitoring the request
    _monitor.startOperation(
      'http_request_${options.method.toLowerCase()}',
      metadata: {
        'url': options.uri.toString(),
        'method': options.method,
        'headers': options.headers,
      },
    );
    
    super.onRequest(options, handler);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = _requestStartTimes.remove(response.requestOptions);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      
      // Record network performance metric
      _monitor.recordNetworkMetric(
        endpoint: response.requestOptions.uri.toString(),
        responseTime: duration,
        statusCode: response.statusCode ?? 0,
        bytesTransferred: _calculateResponseSize(response),
      );
      
      // End the operation monitoring
      _monitor.endOperation(
        'http_request_${response.requestOptions.method.toLowerCase()}',
        success: response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300,
        metadata: {
          'status_code': response.statusCode,
          'response_size_bytes': _calculateResponseSize(response),
          'duration_ms': duration.inMilliseconds,
        },
      );
    }
    
    super.onResponse(response, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = _requestStartTimes.remove(err.requestOptions);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      
      // Record failed network request
      _monitor.recordNetworkMetric(
        endpoint: err.requestOptions.uri.toString(),
        responseTime: duration,
        statusCode: err.response?.statusCode ?? 0,
        bytesTransferred: 0,
      );
      
      // End the operation with error
      _monitor.endOperation(
        'http_request_${err.requestOptions.method.toLowerCase()}',
        success: false,
        errorMessage: err.message,
        metadata: {
          'error_type': err.type.toString(),
          'status_code': err.response?.statusCode,
          'duration_ms': duration.inMilliseconds,
        },
      );
    }
    
    super.onError(err, handler);
  }
  
  /// Calculate approximate response size
  int _calculateResponseSize(Response response) {
    if (response.data == null) return 0;
    
    try {
      if (response.data is String) {
        return (response.data as String).length;
      } else if (response.data is List<int>) {
        return (response.data as List<int>).length;
      } else if (response.data is Map) {
        // Rough estimation for JSON data
        return response.data.toString().length;
      }
    } catch (e) {
      // Fallback estimation
      return response.headers.toString().length + 100;
    }
    
    return 0;
  }
}

/// Database operation interceptor for Firestore
class DatabasePerformanceInterceptor {
  final PerformanceMonitor _monitor = PerformanceMonitor();
  
  /// Wrap a database operation with performance monitoring
  Future<T> wrapOperation<T>({
    required String operation,
    required String collection,
    required Future<T> Function() operation_func,
  }) async {
    final startTime = DateTime.now();
    
    _monitor.startOperation(
      'database_$operation',
      metadata: {
        'collection': collection,
        'operation_type': operation,
      },
    );
    
    try {
      final result = await operation_func();
      final duration = DateTime.now().difference(startTime);
      
      // Determine documents affected based on result type
      int? documentsAffected;
      if (result is QuerySnapshot) {
        documentsAffected = result.docs.length;
      } else if (result is DocumentSnapshot) {
        documentsAffected = result.exists ? 1 : 0;
      } else if (result is List) {
        documentsAffected = result.length;
      }
      
      _monitor.recordDatabaseMetric(
        operation: operation,
        duration: duration,
        success: true,
        collection: collection,
        documentsAffected: documentsAffected,
      );
      
      _monitor.endOperation(
        'database_$operation',
        success: true,
        metadata: {
          'documents_affected': documentsAffected,
          'duration_ms': duration.inMilliseconds,
        },
      );
      
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      _monitor.recordDatabaseMetric(
        operation: operation,
        duration: duration,
        success: false,
        collection: collection,
        errorMessage: e.toString(),
      );
      
      _monitor.endOperation(
        'database_$operation',
        success: false,
        errorMessage: e.toString(),
        metadata: {
          'duration_ms': duration.inMilliseconds,
        },
      );
      
      rethrow;
    }
  }
}

/// UI Performance monitoring mixin
mixin UIPerformanceMonitor {
  final PerformanceMonitor _monitor = PerformanceMonitor();
  DateTime? _screenLoadStart;
  
  /// Start monitoring screen load performance
  void startScreenLoad(String screenName) {
    _screenLoadStart = DateTime.now();
    _monitor.startOperation(
      'screen_load',
      metadata: {
        'screen_name': screenName,
      },
    );
  }
  
  /// End screen load monitoring
  void endScreenLoad(String screenName, {int frameDrops = 0, double? fps}) {
    if (_screenLoadStart == null) return;
    
    final duration = DateTime.now().difference(_screenLoadStart!);
    _screenLoadStart = null;
    
    _monitor.recordUIMetric(
      screenName: screenName,
      renderTime: duration,
      frameDrops: frameDrops,
      fps: fps,
    );
    
    _monitor.endOperation(
      'screen_load',
      success: frameDrops < 5, // Consider success if less than 5 frame drops
      metadata: {
        'screen_name': screenName,
        'frame_drops': frameDrops,
        'fps': fps,
        'render_time_ms': duration.inMilliseconds,
      },
    );
  }
  
  /// Monitor widget build performance
  T monitorWidgetBuild<T>(String widgetName, T Function() buildFunction) {
    final startTime = DateTime.now();
    
    try {
      final result = buildFunction();
      final duration = DateTime.now().difference(startTime);
      
      if (duration.inMilliseconds > 16) { // More than one frame at 60fps
        _monitor.recordUIMetric(
          screenName: widgetName,
          renderTime: duration,
          frameDrops: (duration.inMilliseconds / 16).ceil() - 1,
        );
      }
      
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _monitor.endOperation(
        'widget_build',
        success: false,
        errorMessage: e.toString(),
        metadata: {
          'widget_name': widgetName,
          'duration_ms': duration.inMilliseconds,
        },
      );
      rethrow;
    }
  }
}

/// Memory monitoring utilities
class MemoryMonitor {
  static final PerformanceMonitor _monitor = PerformanceMonitor();
  static Timer? _memoryTimer;
  
  /// Start periodic memory monitoring
  static void startMonitoring({Duration interval = const Duration(minutes: 1)}) {
    _memoryTimer?.cancel();
    _memoryTimer = Timer.periodic(interval, (_) {
      _monitor.recordMemoryUsage();
    });
  }
  
  /// Stop memory monitoring
  static void stopMonitoring() {
    _memoryTimer?.cancel();
    _memoryTimer = null;
  }
  
  /// Monitor memory usage for a specific operation
  static Future<T> monitorOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    // Record memory before operation
    _monitor.recordMemoryUsage();
    
    final startTime = DateTime.now();
    try {
      final result = await operation();
      final duration = DateTime.now().difference(startTime);
      
      // Record memory after operation
      _monitor.recordMemoryUsage();
      
      _monitor.endOperation(
        'memory_$operationName',
        success: true,
        metadata: {
          'duration_ms': duration.inMilliseconds,
        },
      );
      
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      _monitor.endOperation(
        'memory_$operationName',
        success: false,
        errorMessage: e.toString(),
        metadata: {
          'duration_ms': duration.inMilliseconds,
        },
      );
      
      rethrow;
    }
  }
}