// Story Ring Widget - Instagram-like story ring with gradient
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StoryRing extends StatelessWidget {
  final Widget child;
  final bool hasUnviewedStories;
  final double size;
  final double strokeWidth;

  const StoryRing({
    super.key,
    required this.child,
    this.hasUnviewedStories = false,
    this.size = 68,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUnviewedStories
            ? LinearGradient(
                colors: [
                  AppTheme.talowaGreen,
                  AppTheme.talowaGreen.withOpacity(0.7),
                  Colors.orange,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: Border.all(
          color: hasUnviewedStories 
              ? Colors.transparent 
              : Colors.grey.shade300,
          width: strokeWidth,
        ),
      ),
      padding: EdgeInsets.all(strokeWidth),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: strokeWidth,
          ),
        ),
        child: ClipOval(child: child),
      ),
    );
  }
}