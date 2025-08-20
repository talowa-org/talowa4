// TALOWA Progress Indicator Widget
// Shows progress through onboarding steps

import 'package:flutter/material.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Color color;
  final double height;

  const ProgressIndicatorWidget({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.color = Colors.blue,
    this.height = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSteps > 0 ? (currentStep + 1) / totalSteps : 0.0;

    return Column(
      children: [
        // Progress bar
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Step indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (index) {
            final isCompleted = index < currentStep;
            final isCurrent = index == currentStep;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isCurrent ? 12 : 8,
                height: isCurrent ? 12 : 8,
                decoration: BoxDecoration(
                  color: isCompleted || isCurrent
                      ? color
                      : color.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 8),

        // Progress text
        Text(
          'Step ${currentStep + 1} of $totalSteps',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}