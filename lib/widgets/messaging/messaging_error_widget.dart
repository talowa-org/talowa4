// Messaging Error Widget for TALOWA Messaging System
// Implements Task 8: Build comprehensive error handling and loading states
// Requirements: 7.1, 7.2, 7.3

import 'package:flutter/material.dart';
import '../../services/messaging/message_error_handler.dart';

/// Widget for displaying messaging errors with retry options
class MessagingErrorWidget extends StatelessWidget {
  final MessageError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showRetryButton;
  final bool showDismissButton;
  final EdgeInsets padding;

  const MessagingErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showRetryButton = true,
    this.showDismissButton = true,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _getErrorBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getErrorBorderColor(),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _getErrorIcon(),
                color: _getErrorIconColor(),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getErrorTitle(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _getErrorTextColor(),
                    fontSize: 14,
                  ),
                ),
              ),
              if (showDismissButton && onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error.userFriendlyMessage,
            style: TextStyle(
              color: _getErrorTextColor().withOpacity(0.8),
              fontSize: 13,
            ),
          ),
          if (error.isRetryable && error.retryAfter != null) ...[
            const SizedBox(height: 4),
            Text(
              'You can try again in ${error.retryAfter!.inSeconds} seconds',
              style: TextStyle(
                color: _getErrorTextColor().withOpacity(0.6),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (showRetryButton && error.isRetryable && onRetry != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: _getErrorIconColor(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (error.type) {
      case MessageErrorType.networkError:
        return Icons.wifi_off;
      case MessageErrorType.authenticationError:
        return Icons.lock_outline;
      case MessageErrorType.permissionError:
        return Icons.block;
      case MessageErrorType.rateLimitError:
        return Icons.speed;
      case MessageErrorType.serverError:
        return Icons.cloud_off;
      case MessageErrorType.validationError:
        return Icons.error_outline;
      case MessageErrorType.storageError:
        return Icons.storage;
      case MessageErrorType.unknownError:
        return Icons.help_outline;
    }
  }

  String _getErrorTitle() {
    switch (error.type) {
      case MessageErrorType.networkError:
        return 'Connection Error';
      case MessageErrorType.authenticationError:
        return 'Authentication Error';
      case MessageErrorType.permissionError:
        return 'Permission Denied';
      case MessageErrorType.rateLimitError:
        return 'Rate Limited';
      case MessageErrorType.serverError:
        return 'Server Error';
      case MessageErrorType.validationError:
        return 'Invalid Input';
      case MessageErrorType.storageError:
        return 'Storage Error';
      case MessageErrorType.unknownError:
        return 'Unexpected Error';
    }
  }

  Color _getErrorBackgroundColor() {
    switch (error.type) {
      case MessageErrorType.networkError:
        return Colors.orange.shade50;
      case MessageErrorType.authenticationError:
      case MessageErrorType.permissionError:
      case MessageErrorType.serverError:
        return Colors.red.shade50;
      case MessageErrorType.rateLimitError:
        return Colors.amber.shade50;
      case MessageErrorType.validationError:
        return Colors.orange.shade50;
      case MessageErrorType.storageError:
        return Colors.deepOrange.shade50;
      case MessageErrorType.unknownError:
        return Colors.grey.shade50;
    }
  }

  Color _getErrorBorderColor() {
    switch (error.type) {
      case MessageErrorType.networkError:
        return Colors.orange.shade200;
      case MessageErrorType.authenticationError:
      case MessageErrorType.permissionError:
      case MessageErrorType.serverError:
        return Colors.red.shade200;
      case MessageErrorType.rateLimitError:
        return Colors.amber.shade200;
      case MessageErrorType.validationError:
        return Colors.orange.shade200;
      case MessageErrorType.storageError:
        return Colors.deepOrange.shade200;
      case MessageErrorType.unknownError:
        return Colors.grey.shade200;
    }
  }

  Color _getErrorIconColor() {
    switch (error.type) {
      case MessageErrorType.networkError:
        return Colors.orange.shade600;
      case MessageErrorType.authenticationError:
      case MessageErrorType.permissionError:
      case MessageErrorType.serverError:
        return Colors.red.shade600;
      case MessageErrorType.rateLimitError:
        return Colors.amber.shade600;
      case MessageErrorType.validationError:
        return Colors.orange.shade600;
      case MessageErrorType.storageError:
        return Colors.deepOrange.shade600;
      case MessageErrorType.unknownError:
        return Colors.grey.shade600;
    }
  }

  Color _getErrorTextColor() {
    switch (error.type) {
      case MessageErrorType.networkError:
        return Colors.orange.shade800;
      case MessageErrorType.authenticationError:
      case MessageErrorType.permissionError:
      case MessageErrorType.serverError:
        return Colors.red.shade800;
      case MessageErrorType.rateLimitError:
        return Colors.amber.shade800;
      case MessageErrorType.validationError:
        return Colors.orange.shade800;
      case MessageErrorType.storageError:
        return Colors.deepOrange.shade800;
      case MessageErrorType.unknownError:
        return Colors.grey.shade800;
    }
  }
}

/// Inline error widget for forms and inputs
class InlineErrorWidget extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Color? color;

  const InlineErrorWidget({
    super.key,
    required this.message,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.red.shade600;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.error_outline,
            size: 16,
            color: effectiveColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error banner for global errors
class ErrorBannerWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Color? backgroundColor;
  final bool isVisible;

  const ErrorBannerWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
    this.backgroundColor,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.red.shade600,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (onRetry != null) ...[
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: const Text('Retry'),
              ),
            ],
            if (onDismiss != null) ...[
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for when operations fail
class ErrorEmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryButtonText;

  const ErrorEmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.onRetry,
    this.retryButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryButtonText ?? 'Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Utility class for showing error dialogs
class MessagingErrorDialogs {
  
  /// Show error dialog with retry option
  static Future<bool?> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool showRetryButton = true,
    String retryButtonText = 'Retry',
    String cancelButtonText = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelButtonText),
          ),
          if (showRetryButton)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(retryButtonText),
            ),
        ],
      ),
    );
  }

  /// Show network error dialog
  static Future<bool?> showNetworkErrorDialog(BuildContext context) {
    return showErrorDialog(
      context,
      title: 'Connection Error',
      message: 'Unable to connect to the server. Please check your internet connection and try again.',
    );
  }

  /// Show authentication error dialog
  static Future<bool?> showAuthErrorDialog(BuildContext context) {
    return showErrorDialog(
      context,
      title: 'Authentication Error',
      message: 'Your session has expired. Please log in again to continue.',
      showRetryButton: false,
    );
  }

  /// Show rate limit error dialog
  static Future<bool?> showRateLimitDialog(BuildContext context) {
    return showErrorDialog(
      context,
      title: 'Too Many Requests',
      message: 'You are sending messages too quickly. Please wait a moment before trying again.',
      retryButtonText: 'Wait and Retry',
    );
  }
}