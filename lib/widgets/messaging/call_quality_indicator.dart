import 'package:flutter/material.dart';
import '../../models/call_quality.dart';

/// Call quality indicator widget
class CallQualityIndicator extends StatelessWidget {
  final CallQuality quality;
  final bool showDetails;

  const CallQualityIndicator({
    super.key,
    required this.quality,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quality indicator bars
          _buildQualityBars(),
          const SizedBox(width: 8),
          
          // Quality text
          Text(
            quality.qualityLevel.toUpperCase(),
            style: TextStyle(
              color: _getQualityColor(),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBars() {
    final score = quality.overallScore;
    const bars = 4;
    final activeBars = (score / 25).ceil().clamp(0, bars);

    return Row(
      children: List.generate(bars, (index) {
        final isActive = index < activeBars;
        return Container(
          width: 3,
          height: 8 + (index * 2), // Increasing height
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: isActive ? _getQualityColor() : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Color _getQualityColor() {
    switch (quality.qualityLevel) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

