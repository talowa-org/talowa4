// Safe Math Utilities - Prevent infinity and NaN errors
// Provides safe mathematical operations to prevent app crashes

import 'dart:math' as math;

class SafeMathUtils {
  /// Safely converts a double to int, handling infinity and NaN cases
  static int safeToInt(double value, {int fallback = 0}) {
    if (value.isNaN || value.isInfinite) {
      return fallback;
    }
    return value.toInt();
  }

  /// Safely clamps a value between min and max, handling infinity cases
  static double safeClamp(double value, double min, double max) {
    if (value.isNaN) return min;
    if (value.isInfinite) {
      return value.isNegative ? min : max;
    }
    return value.clamp(min, max);
  }

  /// Safely clamps and converts to int
  static int safeClampToInt(double value, double min, double max, {int fallback = 0}) {
    final clampedValue = safeClamp(value, min, max);
    return safeToInt(clampedValue, fallback: fallback);
  }

  /// Safe division that handles division by zero
  static double safeDivide(double numerator, double denominator, {double fallback = 0.0}) {
    if (denominator == 0 || denominator.isNaN || denominator.isInfinite) {
      return fallback;
    }
    final result = numerator / denominator;
    if (result.isNaN || result.isInfinite) {
      return fallback;
    }
    return result;
  }

  /// Safe percentage calculation
  static double safePercentage(double value, double total, {double fallback = 0.0}) {
    if (total == 0 || total.isNaN || total.isInfinite) {
      return fallback;
    }
    final percentage = (value / total) * 100;
    if (percentage.isNaN || percentage.isInfinite) {
      return fallback;
    }
    return percentage.clamp(0.0, 100.0);
  }

  /// Safe progress calculation (0.0 to 1.0)
  static double safeProgress(double current, double total, {double fallback = 0.0}) {
    if (total == 0 || total.isNaN || total.isInfinite) {
      return fallback;
    }
    final progress = current / total;
    if (progress.isNaN || progress.isInfinite) {
      return fallback;
    }
    return progress.clamp(0.0, 1.0);
  }

  /// Safe square root
  static double safeSqrt(double value, {double fallback = 0.0}) {
    if (value < 0 || value.isNaN || value.isInfinite) {
      return fallback;
    }
    return math.sqrt(value);
  }

  /// Safe power operation
  static double safePow(double base, double exponent, {double fallback = 0.0}) {
    if (base.isNaN || base.isInfinite || exponent.isNaN || exponent.isInfinite) {
      return fallback;
    }
    final result = math.pow(base, exponent).toDouble();
    if (result.isNaN || result.isInfinite) {
      return fallback;
    }
    return result;
  }

  /// Check if a value is safe for mathematical operations
  static bool isSafeValue(double value) {
    return !value.isNaN && !value.isInfinite;
  }

  /// Get a safe value, replacing NaN/infinity with fallback
  static double getSafeValue(double value, {double fallback = 0.0}) {
    return isSafeValue(value) ? value : fallback;
  }

  /// Safe minimum of two values
  static double safeMin(double a, double b, {double fallback = 0.0}) {
    if (!isSafeValue(a) && !isSafeValue(b)) return fallback;
    if (!isSafeValue(a)) return b;
    if (!isSafeValue(b)) return a;
    return math.min(a, b);
  }

  /// Safe maximum of two values
  static double safeMax(double a, double b, {double fallback = 0.0}) {
    if (!isSafeValue(a) && !isSafeValue(b)) return fallback;
    if (!isSafeValue(a)) return b;
    if (!isSafeValue(b)) return a;
    return math.max(a, b);
  }

  /// Safe average calculation
  static double safeAverage(List<double> values, {double fallback = 0.0}) {
    if (values.isEmpty) return fallback;
    
    final safeValues = values.where(isSafeValue).toList();
    if (safeValues.isEmpty) return fallback;
    
    final sum = safeValues.reduce((a, b) => a + b);
    return sum / safeValues.length;
  }

  /// Format a number safely for display
  static String safeFormat(double value, {int decimals = 2, String fallback = '0'}) {
    if (!isSafeValue(value)) return fallback;
    return value.toStringAsFixed(decimals);
  }

  /// Safe conversion to display string with K/M suffixes
  static String safeFormatCount(int count, {String fallback = '0'}) {
    if (count < 0) return fallback;
    
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      final k = count / 1000;
      return k == k.toInt() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    } else {
      final m = count / 1000000;
      return m == m.toInt() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
  }
}