// Connection Status Widget - Shows real-time connection status
// Part of Task 13: Implement real-time feed updates

import 'package:flutter/material.dart';
import '../../services/social_feed/real_time_feed_service.dart' as RealTimeFeed;

class ConnectionStatusWidget extends StatelessWidget {
  final RealTimeFeed.ConnectionState connectionState;
  final VoidCallback? onRetry;
  final bool showBanner;

  const ConnectionStatusWidget({
    super.key,
    required this.connectionState,
    this.onRetry,
    this.showBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBanner) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 40,
      color: _getBackgroundColor(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIcon(),
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _getMessage(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (connectionState == ConnectionState.disconnected && onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (connectionState) {
      case RealTimeFeed.ConnectionState.connected:
        return Colors.green;
      case RealTimeFeed.ConnectionState.reconnecting:
        return Colors.orange;
      case RealTimeFeed.ConnectionState.disconnected:
        return Colors.red;
    }
  }

  IconData _getIcon() {
    switch (connectionState) {
      case RealTimeFeed.ConnectionState.connected:
        return Icons.wifi;
      case RealTimeFeed.ConnectionState.reconnecting:
        return Icons.wifi_protected_setup;
      case RealTimeFeed.ConnectionState.disconnected:
        return Icons.wifi_off;
    }
  }

  String _getMessage() {
    switch (connectionState) {
      case RealTimeFeed.ConnectionState.connected:
        return 'Connected - Real-time updates active';
      case RealTimeFeed.ConnectionState.reconnecting:
        return 'Reconnecting...';
      case RealTimeFeed.ConnectionState.disconnected:
        return 'Disconnected - Tap to retry';
    }
  }
}

/// Stream builder widget for connection status
class ConnectionStatusStreamWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ConnectionStatusStreamWidget({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RealTimeFeed.ConnectionState>(
      stream: RealTimeFeedService.connectionStateStream,
      initialData: RealTimeFeedService.connectionState,
      builder: (context, snapshot) {
        final connectionState = snapshot.data ?? RealTimeFeed.ConnectionState.disconnected;
        final showBanner = connectionState != RealTimeFeed.ConnectionState.connected;

        return ConnectionStatusWidget(
          connectionState: connectionState,
          onRetry: onRetry,
          showBanner: showBanner,
        );
      },
    );
  }
}