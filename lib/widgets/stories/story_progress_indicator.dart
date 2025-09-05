// Story Progress Indicator - Instagram-like progress bars for stories
import 'package:flutter/material.dart';

class StoryProgressIndicator extends StatelessWidget {
  final int storyCount;
  final int currentIndex;
  final AnimationController? animationController;

  const StoryProgressIndicator({
    super.key,
    required this.storyCount,
    required this.currentIndex,
    this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(storyCount, (index) {
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: _buildProgressBar(index),
          ),
        );
      }),
    );
  }

  Widget _buildProgressBar(int index) {
    if (index < currentIndex) {
      // Completed story
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
    } else if (index == currentIndex) {
      // Current story with animation
      return animationController != null
          ? AnimatedBuilder(
              animation: animationController!,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: animationController!.value,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
    } else {
      // Future story
      return const SizedBox();
    }
  }
}
