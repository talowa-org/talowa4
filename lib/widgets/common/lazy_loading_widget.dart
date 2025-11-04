import 'package:flutter/material.dart';

/// A simple lazy loading widget that wraps its child
/// This is a basic implementation that can be enhanced with visibility detection
class LazyLoadingWidget extends StatelessWidget {
  final Widget child;
  final bool isVisible;
  final Widget? placeholder;
  
  const LazyLoadingWidget({
    Key? key,
    required this.child,
    this.isVisible = true,
    this.placeholder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isVisible) {
      return child;
    }
    
    return placeholder ?? const SizedBox.shrink();
  }
}