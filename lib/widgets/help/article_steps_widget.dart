// TALOWA Article Steps Widget
// Displays step-by-step instructions

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ArticleStepsWidget extends StatelessWidget {
  final List<String> steps;

  const ArticleStepsWidget({
    super.key,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.talowaGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.talowaGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step number
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.talowaGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: AppTheme.talowaGreen.withOpacity(0.3),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              // Step content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: isLast ? 0 : 16,
                    top: 4,
                  ),
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.primaryText,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}