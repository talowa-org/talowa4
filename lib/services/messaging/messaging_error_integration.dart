// Messaging Error Integration Service
// Integrates all error handling and loading state components
// Implements Task 8: Build comprehensive error handling and loading states

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'comprehensive_error_handler.dart';
import 'loading_state_service.dart';
import 'retry_mechanism_service.dart';
import 'message_error_handler.dart';

/// Integration service that coordinates all error handling and loading states
class MessagingErrorIntegration {
  static final MessagingErrorIntegration _instance = MessagingErrorIntegration._internal();
  factory MessagingErrorIntegration() => _instance;
  MessagingErrorIntegration._internal();

  final ComprehensiveErrorHandler _errorHandler = ComprehensiveErrorHandler();
  final LoadingStateService _loadingService = LoadingStateService();
  final RetryMechanismService _retryService = RetryMechanismService();
  final MessageErrorHandler _messageErrorHandler = MessageErrorHandler();

  bool _isInitialized = false;

  /// Initialize all error handling services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Messaging Error Integration...');

      // Initialize all services
      await _errorHandler.initialize();
      // LoadingStateService doesn't need initialization
      // RetryMechanismService doesn't need initialization
      // MessageErrorHandler doesn't need initialization

      _isInitialized = true;
      debugPrint('Messaging Error Integration initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Messaging Error Integration: $e');
      rethrow;
    }
  }

  /// Execute operation with comprehensive error handling and loading states
  Future<T> executeOperation<T>(
    String operationId,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
    int maxRetries = 3,
    Duration initialRetryDelay = const Duration(seconds: 1),
    bool requiresNetwork = true,
    LoadingType loadingType = LoadingType.indeterminate,
    Map<String, dynamic>? context,
  }) async {
    // Start loading state
    _loadingService.startLoading(
      operationId,
      message: loadingMessage ?? 'Processing...',
      type: loadingType,
    );

    try {
      // Execute with comprehensive error handling and retry
      final result = await _errorHandler.handleOperation(
        () => _retryService.executeWithRetry(
          operation,
          operationId: operationId,
          maxRetries: maxRetries,
          initialDelay: initialRetryDelay,
          onRetry: (attempt, error) {
            _loadingService.updateMessage(
              operationId,
              'Retrying... (attempt $attempt)',
            );
          },
        ),
        operationName: operationId,
        maxRetries: maxRetries,
        initialDelay: initialRetryDelay,
        requiresNetwork: requiresNetwork,
        context: context,
      );

      // Success
      _loadingService.stopLoading(
        operationId,
        finalMessage: successMessage,
        success: true,
      );

      return result;
    } catch (error) {
      // Handle error
      final messageError = _messageErrorHandler.handleError(error, context: context);
      
      // Stop loading with error
      _loadingService.stopLoading(
        operationId,
        finalMessage: errorMessage ?? messageError.userFriendlyMessage,
        success: false,
        error: error,
      );

      rethrow;
    }
  }

  /// Execute operation with progress tracking
  Future<T> executeOperationWithProgress<T>(
    String operationId,
    Future<T> Function(void Function(double progress) onProgress) operation, {
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
    int maxRetries = 3,
    bool requiresNetwork = true,
    Map<String, dynamic>? context,
  }) async {
    // Start loading with progress
    _loadingService.startLoading(
      operationId,
      message: loadingMessage ?? 'Processing...',
      type: LoadingType.determinate,
      progress: 0.0,
    );

    try {
      final result = await _errorHandler.handleOperation(
        () => operation((progress) {
          _loadingService.updateProgress(operationId, progress: progress);
        }),
        operationName: operationId,
        maxRetries: maxRetries,
        requiresNetwork: requiresNetwork,
        context: context,
      );

      // Success
      _loadingService.stopLoading(
        operationId,
        finalMessage: successMessage,
        success: true,
      );

      return result;
    } catch (error) {
      // Handle error
      final messageError = _messageErrorHandler.handleError(error, context: context);
      
      // Stop loading with error
      _loadingService.stopLoading(
        operationId,
        finalMessage: errorMessage ?? messageError.userFriendlyMessage,
        success: false,
        error: error,
      );

      rethrow;
    }
  }

  /// Get loading state for operation
  LoadingState? getLoadingState(String operationId) {
    return _loadingService.getLoadingState(operationId);
  }

  /// Check if operation is loading
  bool isLoading(String operationId) {
    return _loadingService.isLoading(operationId);
  }

  /// Get loading state stream for operation
  Stream<LoadingState?> getLoadingStateStream(String operationId) {
    return _loadingService.getLoadingStateStream(operationId);
  }

  /// Get network status
  bool get isOnline => _errorHandler.isOnline;

  /// Get network quality
  NetworkQuality get networkQuality => _errorHandler.networkQuality;

  /// Get network status stream
  Stream<bool> get networkStatusStream => _errorHandler.networkStatusStream;

  /// Get network quality stream
  Stream<NetworkQuality> get networkQualityStream => _errorHandler.networkQualityStream;

  /// Get error statistics
  Map<String, dynamic> getErrorStatistics() {
    return _errorHandler.getErrorStatistics();
  }

  /// Get loading statistics
  Map<String, dynamic> getLoadingStatistics() {
    return _loadingService.getLoadingStatistics();
  }

  /// Get retry statistics
  Map<String, dynamic> getRetryStatistics() {
    return _retryService.getRetryStatistics();
  }

  /// Get comprehensive system status
  Map<String, dynamic> getSystemStatus() {
    return {
      'isInitialized': _isInitialized,
      'networkStatus': {
        'isOnline': isOnline,
        'quality': networkQuality.toString(),
      },
      'errorStatistics': getErrorStatistics(),
      'loadingStatistics': getLoadingStatistics(),
      'retryStatistics': getRetryStatistics(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose all services
  Future<void> dispose() async {
    await _errorHandler.dispose();
    await _loadingService.dispose();
    await _retryService.dispose();
    await _messageErrorHandler.dispose();
  }
}

/// Utility class for common messaging operations
class MessagingOperations {
  static final MessagingErrorIntegration _integration = MessagingErrorIntegration();

  /// Send message with error handling
  static Future<String> sendMessage({
    required String conversationId,
    required String content,
    String? recipientName,
  }) async {
    return await _integration.executeOperation(
      'send_message_$conversationId',
      () async {
        // Simulate message sending
        await Future.delayed(const Duration(seconds: 1));
        return 'message_id_${DateTime.now().millisecondsSinceEpoch}';
      },
      loadingMessage: recipientName != null 
          ? 'Sending to $recipientName...' 
          : 'Sending message...',
      successMessage: 'Message sent',
      errorMessage: 'Failed to send message',
      maxRetries: 3,
      requiresNetwork: true,
      context: {
        'conversationId': conversationId,
        'contentLength': content.length,
      },
    );
  }

  /// Load messages with error handling
  static Future<List<String>> loadMessages({
    required String conversationId,
    int limit = 50,
  }) async {
    return await _integration.executeOperation(
      'load_messages_$conversationId',
      () async {
        // Simulate loading messages
        await Future.delayed(const Duration(seconds: 2));
        return List.generate(limit, (i) => 'message_$i');
      },
      loadingMessage: 'Loading messages...',
      successMessage: 'Messages loaded',
      errorMessage: 'Failed to load messages',
      maxRetries: 2,
      requiresNetwork: true,
      loadingType: LoadingType.skeleton,
      context: {
        'conversationId': conversationId,
        'limit': limit,
      },
    );
  }

  /// Upload file with progress
  static Future<String> uploadFile({
    required String fileName,
    required int fileSize,
  }) async {
    return await _integration.executeOperationWithProgress(
      'upload_file_$fileName',
      (onProgress) async {
        // Simulate file upload with progress
        for (int i = 0; i <= 100; i += 10) {
          await Future.delayed(const Duration(milliseconds: 200));
          onProgress(i / 100.0);
        }
        return 'file_url_${DateTime.now().millisecondsSinceEpoch}';
      },
      loadingMessage: 'Uploading $fileName...',
      successMessage: 'File uploaded successfully',
      errorMessage: 'Failed to upload file',
      maxRetries: 3,
      requiresNetwork: true,
      context: {
        'fileName': fileName,
        'fileSize': fileSize,
      },
    );
  }

  /// Search users with error handling
  static Future<List<String>> searchUsers({
    required String query,
  }) async {
    return await _integration.executeOperation(
      'search_users_$query',
      () async {
        // Simulate user search
        await Future.delayed(const Duration(milliseconds: 800));
        return List.generate(5, (i) => 'user_${query}_$i');
      },
      loadingMessage: 'Searching for "$query"...',
      successMessage: 'Search completed',
      errorMessage: 'Search failed',
      maxRetries: 2,
      requiresNetwork: true,
      loadingType: LoadingType.dots,
      context: {
        'query': query,
      },
    );
  }

  /// Initiate voice call with error handling
  static Future<String> initiateVoiceCall({
    required String recipientId,
    required String recipientName,
  }) async {
    return await _integration.executeOperation(
      'voice_call_$recipientId',
      () async {
        // Simulate call initiation
        await Future.delayed(const Duration(seconds: 3));
        return 'call_id_${DateTime.now().millisecondsSinceEpoch}';
      },
      loadingMessage: 'Calling $recipientName...',
      successMessage: 'Call connected',
      errorMessage: 'Failed to connect call',
      maxRetries: 2,
      requiresNetwork: true,
      loadingType: LoadingType.pulse,
      context: {
        'recipientId': recipientId,
        'recipientName': recipientName,
      },
    );
  }
}