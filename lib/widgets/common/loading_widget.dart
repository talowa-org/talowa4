// Common Loading Widget
// Reference: Used across all screens for consistent loading states

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LoadingWidget extends StatelessWidget {
  final String message;
  final bool showProgress;

  const LoadingWidget({
    super.key,
    this.message = 'Loading...',
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showProgress)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.talowaGreen),
            ),
          if (showProgress) const SizedBox(height: AppTheme.spacingMedium),
          Text(
            message,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}