import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Error boundary widget that catches and handles errors gracefully
/// Prevents the entire app from crashing due to widget errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? errorTitle;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showStackTrace;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
    this.showStackTrace = false,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorWidget();
    }

    // Wrap the child widget to catch errors
    return Builder(
      builder: (context) {
        try {
          return widget.child;
        } catch (error, stackTrace) {
          // Capture the error for display
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _error = error;
                _stackTrace = stackTrace;
              });
            }
          });

          // Return error widget immediately
          return _buildErrorWidget();
        }
      },
    );
  }

  Widget _buildErrorWidget() {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            
            const SizedBox(height: 16),
            
            // Error title
            Text(
              widget.errorTitle ?? 'Something went wrong',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Error message
            Text(
              widget.errorMessage ?? 'An unexpected error occurred. Please try again.',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Retry button
            if (widget.onRetry != null)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _stackTrace = null;
                  });
                  widget.onRetry?.call();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            
            // Stack trace (debug mode only)
            if (kDebugMode && widget.showStackTrace && _stackTrace != null) ...[
              const SizedBox(height: 24),
              ExpansionTile(
                title: const Text('Error Details'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _stackTrace.toString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Global error handler for uncaught exceptions
class GlobalErrorHandler {
  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log the error
      debugPrint('🚨 Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
      
      // In debug mode, show the red screen
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Handle errors outside of Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('🚨 Platform Error: $error');
      debugPrint('Stack trace: $stack');
      return true; // Handled
    };
  }
}

/// Specific error boundary for referral system components
class ReferralErrorBoundary extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRetry;

  const ReferralErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      errorTitle: 'Referral System Error',
      errorMessage: 'There was an issue with the referral system. This won\'t affect your registration.',
      onRetry: onRetry,
      showStackTrace: kDebugMode,
      child: child,
    );
  }
}

/// Error boundary specifically for registration forms
class RegistrationErrorBoundary extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRetry;

  const RegistrationErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      errorTitle: 'Registration Error',
      errorMessage: 'There was an issue with the registration form. Please refresh and try again.',
      onRetry: onRetry,
      showStackTrace: kDebugMode,
      child: child,
    );
  }
}
