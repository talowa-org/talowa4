// Loading States Widget for TALOWA Messaging
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LoadingStatesWidget extends StatelessWidget {
  final String message;
  final bool showProgress;
  final double? progress;

  const LoadingStatesWidget({
    super.key,
    this.message = 'Loading...',
    this.showProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showProgress && progress != null)
            CircularProgressIndicator(
              value: progress,
              color: AppTheme.talowaGreen,
            )
          else
            const CircularProgressIndicator(
              color: AppTheme.talowaGreen,
            ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}