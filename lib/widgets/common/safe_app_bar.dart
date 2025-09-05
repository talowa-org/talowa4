// Safe App Bar Widget
// Enhanced app bar with safety features and consistent styling

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/navigation/navigation_safety_service.dart';

class SafeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final String? screenName;
  final VoidCallback? onBackPressed;

  const SafeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = AppTheme.elevationLow,
    this.centerTitle = true,
    this.bottom,
    this.screenName,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'NotoSansTelugu',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? Colors.white,
        ),
      ),
      backgroundColor: backgroundColor ?? AppTheme.talowaGreen,
      foregroundColor: foregroundColor ?? Colors.white,
      elevation: elevation,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading ?? (automaticallyImplyLeading ? _buildSafeBackButton(context) : null),
      actions: actions,
      bottom: bottom,
    );
  }

  Widget? _buildSafeBackButton(BuildContext context) {
    // Only show back button if we can safely navigate back
    if (!NavigationSafetyService.isNavigationSafe(context)) {
      return null;
    }

    // Check if there's actually something to go back to
    if (!Navigator.of(context).canPop()) {
      return null;
    }

    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => _handleSafeBack(context),
      tooltip: 'Back',
    );
  }

  void _handleSafeBack(BuildContext context) {
    NavigationSafetyService.handleBackNavigation(
      context,
      screenName: screenName ?? 'Screen',
      onBackPressed: onBackPressed,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
  );
}

// Specialized Safe App Bars for common use cases

class TalowaAppBar extends SafeAppBar {
  const TalowaAppBar({
    super.key,
    required super.title,
    super.actions,
    super.screenName,
    super.onBackPressed,
  }) : super(
    backgroundColor: AppTheme.talowaGreen,
    foregroundColor: Colors.white,
    elevation: AppTheme.elevationLow,
  );
}

class LegalAppBar extends SafeAppBar {
  const LegalAppBar({
    super.key,
    required super.title,
    super.actions,
    super.screenName,
    super.onBackPressed,
  }) : super(
    backgroundColor: AppTheme.legalBlue,
    foregroundColor: Colors.white,
    elevation: AppTheme.elevationLow,
  );
}

class EmergencyAppBar extends SafeAppBar {
  const EmergencyAppBar({
    super.key,
    required super.title,
    super.actions,
    super.screenName,
    super.onBackPressed,
  }) : super(
    backgroundColor: AppTheme.emergencyRed,
    foregroundColor: Colors.white,
    elevation: AppTheme.elevationMedium,
  );
}

class TransparentAppBar extends SafeAppBar {
  const TransparentAppBar({
    super.key,
    required super.title,
    super.actions,
    super.screenName,
    super.onBackPressed,
  }) : super(
    backgroundColor: Colors.transparent,
    foregroundColor: AppTheme.primaryText,
    elevation: 0,
  );
}
