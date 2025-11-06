// Loading State Service for TALOWA Messaging System
// Implements Task 8: Build comprehensive error handling and loading states
// Requirements: 7.2, 7.4, 7.5

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service for managing loading states across the messaging system
class LoadingStateService {
  static final LoadingStateService _instance = LoadingStateService._internal();
  factory LoadingStateService() => _instance;
  LoadingStateService._internal();

  final Map<String, LoadingState> _loadingStates = {};
  final StreamController<LoadingStateEvent> _loadingStateController = 
      StreamController<LoadingStateEvent>.broadcast();

  Stream<LoadingStateEvent> get loadingStateStream => _loadingStateController.stream;

  /// Start loading for an operation
  void startLoading(
    String operationId, {
    String? message,
    LoadingType type = LoadingType.indeterminate,
    double? progress,
    Map<String, dynamic>? metadata,
  }) {
    final loadingState = LoadingState(
      operationId: operationId,
      isLoading: true,
      message: message,
      type: type,
      progress: progress,
      startTime: DateTime.now(),
      metadata: metadata ?? {},
    );

    _loadingStates[operationId] = loadingState;
    
    _loadingStateController.add(LoadingStateEvent(
      operationId: operationId,
      eventType: LoadingEventType.started,
      loadingState: loadingState,
    ));

    debugPrint('🔄 Loading started: $operationId - ${message ?? 'Loading...'}');
  }

  /// Update loading progress
  void updateProgress(
    String operationId, {
    double? progress,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    final currentState = _loadingStates[operationId];
    if (currentState == null || !currentState.isLoading) return;

    final updatedState = currentState.copyWith(
      progress: progress,
      message: message,
      metadata: metadata != null ? {...currentState.metadata, ...metadata} : null,
    );

    _loadingStates[operationId] = updatedState;
    
    _loadingStateController.add(LoadingStateEvent(
      operationId: operationId,
      eventType: LoadingEventType.updated,
      loadingState: updatedState,
    ));

    if (progress != null) {
      debugPrint('📊 Loading progress: $operationId - ${(progress * 100).round()}%');
    }
  }

  /// Update loading message
  void updateMessage(String operationId, String message) {
    updateProgress(operationId, message: message);
  }

  /// Stop loading for an operation
  void stopLoading(
    String operationId, {
    String? finalMessage,
    bool success = true,
    dynamic error,
  }) {
    final currentState = _loadingStates[operationId];
    if (currentState == null) return;

    final completedState = currentState.copyWith(
      isLoading: false,
      message: finalMessage,
      endTime: DateTime.now(),
      success: success,
      error: error,
    );

    _loadingStates[operationId] = completedState;
    
    _loadingStateController.add(LoadingStateEvent(
      operationId: operationId,
      eventType: success ? LoadingEventType.completed : LoadingEventType.failed,
      loadingState: completedState,
    ));

    debugPrint('${success ? '✅' : '❌'} Loading ${success ? 'completed' : 'failed'}: $operationId');

    // Clean up completed states after a delay
    Timer(const Duration(seconds: 5), () {
      _loadingStates.remove(operationId);
    });
  }

  /// Get current loading state for an operation
  LoadingState? getLoadingState(String operationId) {
    return _loadingStates[operationId];
  }

  /// Check if operation is loading
  bool isLoading(String operationId) {
    return _loadingStates[operationId]?.isLoading ?? false;
  }

  /// Get all active loading operations
  List<LoadingState> getActiveLoadingStates() {
    return _loadingStates.values.where((state) => state.isLoading).toList();
  }

  /// Get loading state stream for specific operation
  Stream<LoadingState?> getLoadingStateStream(String operationId) {
    return _loadingStateController.stream
        .where((event) => event.operationId == operationId)
        .map((event) => event.loadingState);
  }

  /// Execute operation with automatic loading state management
  Future<T> executeWithLoading<T>(
    String operationId,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
    LoadingType type = LoadingType.indeterminate,
    void Function(double progress)? onProgress,
  }) async {
    startLoading(
      operationId,
      message: loadingMessage ?? 'Loading...',
      type: type,
    );

    try {
      final result = await operation();
      
      stopLoading(
        operationId,
        finalMessage: successMessage,
        success: true,
      );
      
      return result;
    } catch (error) {
      stopLoading(
        operationId,
        finalMessage: errorMessage ?? 'Operation failed',
        success: false,
        error: error,
      );
      
      rethrow;
    }
  }

  /// Batch loading operations
  void startBatchLoading(List<BatchLoadingOperation> operations) {
    for (final operation in operations) {
      startLoading(
        operation.operationId,
        message: operation.message,
        type: operation.type,
        progress: operation.progress,
        metadata: operation.metadata,
      );
    }
  }

  /// Stop batch loading operations
  void stopBatchLoading(
    List<String> operationIds, {
    bool success = true,
    String? finalMessage,
  }) {
    for (final operationId in operationIds) {
      stopLoading(
        operationId,
        finalMessage: finalMessage,
        success: success,
      );
    }
  }

  /// Get loading statistics
  Map<String, dynamic> getLoadingStatistics() {
    final activeStates = getActiveLoadingStates();
    final allStates = _loadingStates.values.toList();
    
    return {
      'activeOperations': activeStates.length,
      'totalOperations': allStates.length,
      'operationsByType': _groupByType(allStates),
      'averageLoadingTime': _calculateAverageLoadingTime(allStates),
      'longestRunningOperation': _getLongestRunningOperation(activeStates),
    };
  }

  Map<String, int> _groupByType(List<LoadingState> states) {
    final grouped = <String, int>{};
    for (final state in states) {
      final typeKey = state.type.toString();
      grouped[typeKey] = (grouped[typeKey] ?? 0) + 1;
    }
    return grouped;
  }

  double _calculateAverageLoadingTime(List<LoadingState> states) {
    final completedStates = states.where((s) => s.endTime != null).toList();
    if (completedStates.isEmpty) return 0.0;
    
    final totalTime = completedStates
        .map((s) => s.endTime!.difference(s.startTime).inMilliseconds)
        .reduce((a, b) => a + b);
    
    return totalTime / completedStates.length;
  }

  String? _getLongestRunningOperation(List<LoadingState> activeStates) {
    if (activeStates.isEmpty) return null;
    
    final longest = activeStates.reduce((a, b) => 
        a.startTime.isBefore(b.startTime) ? a : b);
    
    return longest.operationId;
  }

  /// Clear all loading states
  void clearAllLoadingStates() {
    final activeOperations = getActiveLoadingStates();
    
    for (final state in activeOperations) {
      stopLoading(state.operationId, success: false, finalMessage: 'Cancelled');
    }
    
    _loadingStates.clear();
  }

  /// Dispose resources
  Future<void> dispose() async {
    clearAllLoadingStates();
    await _loadingStateController.close();
  }
}

/// Loading state model
class LoadingState {
  final String operationId;
  final bool isLoading;
  final String? message;
  final LoadingType type;
  final double? progress;
  final DateTime startTime;
  final DateTime? endTime;
  final bool? success;
  final dynamic error;
  final Map<String, dynamic> metadata;

  LoadingState({
    required this.operationId,
    required this.isLoading,
    this.message,
    required this.type,
    this.progress,
    required this.startTime,
    this.endTime,
    this.success,
    this.error,
    required this.metadata,
  });

  LoadingState copyWith({
    bool? isLoading,
    String? message,
    LoadingType? type,
    double? progress,
    DateTime? endTime,
    bool? success,
    dynamic error,
    Map<String, dynamic>? metadata,
  }) {
    return LoadingState(
      operationId: operationId,
      isLoading: isLoading ?? this.isLoading,
      message: message ?? this.message,
      type: type ?? this.type,
      progress: progress ?? this.progress,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      success: success ?? this.success,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'isLoading': isLoading,
      'message': message,
      'type': type.toString(),
      'progress': progress,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'success': success,
      'error': error?.toString(),
      'duration': duration.inMilliseconds,
      'metadata': metadata,
    };
  }
}

/// Loading state event model
class LoadingStateEvent {
  final String operationId;
  final LoadingEventType eventType;
  final LoadingState loadingState;

  LoadingStateEvent({
    required this.operationId,
    required this.eventType,
    required this.loadingState,
  });
}

/// Loading event types
enum LoadingEventType {
  started,
  updated,
  completed,
  failed,
}

/// Loading types
enum LoadingType {
  indeterminate,  // Spinner without progress
  determinate,    // Progress bar with percentage
  skeleton,       // Skeleton loading animation
  shimmer,        // Shimmer loading effect
  dots,           // Animated dots
  pulse,          // Pulsing animation
}

/// Batch loading operation model
class BatchLoadingOperation {
  final String operationId;
  final String? message;
  final LoadingType type;
  final double? progress;
  final Map<String, dynamic>? metadata;

  BatchLoadingOperation({
    required this.operationId,
    this.message,
    this.type = LoadingType.indeterminate,
    this.progress,
    this.metadata,
  });
}

/// Predefined loading operations for messaging
class MessagingLoadingOperations {
  
  // Message operations
  static const String sendMessage = 'send_message';
  static const String loadMessages = 'load_messages';
  static const String loadMoreMessages = 'load_more_messages';
  static const String deleteMessage = 'delete_message';
  static const String editMessage = 'edit_message';
  
  // Conversation operations
  static const String loadConversations = 'load_conversations';
  static const String createConversation = 'create_conversation';
  static const String joinConversation = 'join_conversation';
  static const String leaveConversation = 'leave_conversation';
  
  // User operations
  static const String loadUsers = 'load_users';
  static const String searchUsers = 'search_users';
  static const String loadUserProfile = 'load_user_profile';
  
  // Voice call operations
  static const String initiateCall = 'initiate_call';
  static const String connectCall = 'connect_call';
  static const String endCall = 'end_call';
  
  // File operations
  static const String uploadFile = 'upload_file';
  static const String downloadFile = 'download_file';
  static const String compressFile = 'compress_file';
  
  // Search operations
  static const String searchMessages = 'search_messages';
  static const String searchConversations = 'search_conversations';
  
  // Sync operations
  static const String syncMessages = 'sync_messages';
  static const String syncConversations = 'sync_conversations';
  static const String syncOfflineData = 'sync_offline_data';
}