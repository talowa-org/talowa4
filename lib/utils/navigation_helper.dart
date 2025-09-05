// Navigation Helper - Utility functions for app navigation
// Part of Task 9: Build PostCreationScreen for coordinators

import 'package:flutter/material.dart';
import '../screens/social_feed/post_creation_screen.dart';
import '../models/social_feed/post_model.dart';
import '../models/social_feed/geographic_targeting.dart';

/// Helper class for app navigation
class NavigationHelper {
  /// Navigate to post creation screen
  static Future<bool?> navigateToPostCreation(
    BuildContext context, {
    PostModel? editingPost,
    PostCategory? initialCategory,
    GeographicTargeting? initialTargeting,
  }) async {
    return await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PostCreationScreen(
          editingPost: editingPost,
          initialCategory: initialCategory,
          initialTargeting: initialTargeting,
        ),
        fullscreenDialog: true,
      ),
    );
  }
  
  /// Navigate to post creation with slide animation
  static Future<bool?> navigateToPostCreationWithSlide(
    BuildContext context, {
    PostModel? editingPost,
    PostCategory? initialCategory,
    GeographicTargeting? initialTargeting,
  }) async {
    return await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PostCreationScreen(
          editingPost: editingPost,
          initialCategory: initialCategory,
          initialTargeting: initialTargeting,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          
          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        fullscreenDialog: true,
      ),
    );
  }
  
  /// Show post creation bottom sheet (for quick posts)
  static Future<bool?> showPostCreationBottomSheet(
    BuildContext context, {
    PostCategory? initialCategory,
    GeographicTargeting? initialTargeting,
  }) async {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: PostCreationScreen(
            initialCategory: initialCategory,
            initialTargeting: initialTargeting,
          ),
        ),
      ),
    );
  }
  
  /// Navigate back with result
  static void navigateBackWithResult(BuildContext context, bool result) {
    Navigator.of(context).pop(result);
  }
  
  /// Show confirmation dialog before navigation
  static Future<bool> showNavigationConfirmation(
    BuildContext context, {
    String title = 'Discard Changes?',
    String content = 'You have unsaved changes. Are you sure you want to leave?',
    String confirmText = 'Discard',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
}

/// Extension for easy navigation from any widget
extension NavigationExtension on BuildContext {
  /// Navigate to post creation
  Future<bool?> navigateToPostCreation({
    PostModel? editingPost,
    PostCategory? initialCategory,
    GeographicTargeting? initialTargeting,
  }) {
    return NavigationHelper.navigateToPostCreation(
      this,
      editingPost: editingPost,
      initialCategory: initialCategory,
      initialTargeting: initialTargeting,
    );
  }
  
  /// Show post creation bottom sheet
  Future<bool?> showPostCreationBottomSheet({
    PostCategory? initialCategory,
    GeographicTargeting? initialTargeting,
  }) {
    return NavigationHelper.showPostCreationBottomSheet(
      this,
      initialCategory: initialCategory,
      initialTargeting: initialTargeting,
    );
  }
  
  /// Navigate back with result
  void navigateBackWithResult(bool result) {
    NavigationHelper.navigateBackWithResult(this, result);
  }
}
