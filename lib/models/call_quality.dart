/// Call quality metrics model
class CallQuality {
  double averageLatency; // in milliseconds
  double packetLoss; // percentage (0-100)
  double jitter; // in milliseconds
  String audioQuality; // 'excellent', 'good', 'poor', 'connecting'
  int? bandwidth; // in kbps
  double? signalStrength; // percentage (0-100)

  CallQuality({
    required this.averageLatency,
    required this.packetLoss,
    required this.jitter,
    required this.audioQuality,
    this.bandwidth,
    this.signalStrength,
  });

  /// Get overall quality score (0-100)
  int get overallScore {
    int latencyScore = 100;
    if (averageLatency > 300) {
      latencyScore = 0;
    } else if (averageLatency > 200) {
      latencyScore = 25;
    } else if (averageLatency > 150) {
      latencyScore = 50;
    } else if (averageLatency > 100) {
      latencyScore = 75;
    }

    int packetLossScore = 100;
    if (packetLoss > 5) {
      packetLossScore = 0;
    } else if (packetLoss > 3) {
      packetLossScore = 25;
    } else if (packetLoss > 1) {
      packetLossScore = 50;
    } else if (packetLoss > 0.5) {
      packetLossScore = 75;
    }

    int jitterScore = 100;
    if (jitter > 100) {
      jitterScore = 0;
    } else if (jitter > 50) {
      jitterScore = 25;
    } else if (jitter > 30) {
      jitterScore = 50;
    } else if (jitter > 20) {
      jitterScore = 75;
    }

    return ((latencyScore + packetLossScore + jitterScore) / 3).round();
  }

  /// Get quality level based on overall score
  String get qualityLevel {
    final score = overallScore;
    if (score >= 80) return 'excellent';
    if (score >= 60) return 'good';
    if (score >= 40) return 'fair';
    return 'poor';
  }

  /// Get quality color for UI
  String get qualityColor {
    switch (qualityLevel) {
      case 'excellent':
        return '#4CAF50'; // Green
      case 'good':
        return '#8BC34A'; // Light Green
      case 'fair':
        return '#FFC107'; // Amber
      case 'poor':
        return '#FF5722'; // Deep Orange
      default:
        return '#9E9E9E'; // Grey
    }
  }

  /// Check if quality is acceptable for voice calls
  bool get isAcceptable => overallScore >= 40;

  /// Get quality description for users
  String get description {
    switch (qualityLevel) {
      case 'excellent':
        return 'Crystal clear audio quality';
      case 'good':
        return 'Good audio quality';
      case 'fair':
        return 'Fair audio quality - some issues may occur';
      case 'poor':
        return 'Poor audio quality - connection issues detected';
      default:
        return 'Checking connection quality...';
    }
  }

  /// Get recommendations for improving quality
  List<String> get recommendations {
    final recommendations = <String>[];

    if (averageLatency > 150) {
      recommendations.add('Move closer to your WiFi router or switch to a better network');
    }

    if (packetLoss > 1) {
      recommendations.add('Check your internet connection stability');
    }

    if (jitter > 30) {
      recommendations.add('Close other apps using internet to improve call quality');
    }

    if (bandwidth != null && bandwidth! < 64) {
      recommendations.add('Your internet speed may be too slow for voice calls');
    }

    if (signalStrength != null && signalStrength! < 50) {
      recommendations.add('Improve your network signal strength');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Your call quality is good');
    }

    return recommendations;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'averageLatency': averageLatency,
      'packetLoss': packetLoss,
      'jitter': jitter,
      'audioQuality': audioQuality,
      'bandwidth': bandwidth,
      'signalStrength': signalStrength,
    };
  }

  /// Create from JSON
  factory CallQuality.fromJson(Map<String, dynamic> json) {
    return CallQuality(
      averageLatency: (json['averageLatency'] ?? 0).toDouble(),
      packetLoss: (json['packetLoss'] ?? 0).toDouble(),
      jitter: (json['jitter'] ?? 0).toDouble(),
      audioQuality: json['audioQuality'] ?? 'connecting',
      bandwidth: json['bandwidth'],
      signalStrength: json['signalStrength']?.toDouble(),
    );
  }

  /// Create a copy with updated fields
  CallQuality copyWith({
    double? averageLatency,
    double? packetLoss,
    double? jitter,
    String? audioQuality,
    int? bandwidth,
    double? signalStrength,
  }) {
    return CallQuality(
      averageLatency: averageLatency ?? this.averageLatency,
      packetLoss: packetLoss ?? this.packetLoss,
      jitter: jitter ?? this.jitter,
      audioQuality: audioQuality ?? this.audioQuality,
      bandwidth: bandwidth ?? this.bandwidth,
      signalStrength: signalStrength ?? this.signalStrength,
    );
  }

  @override
  String toString() {
    return 'CallQuality(latency: ${averageLatency}ms, packetLoss: $packetLoss%, '
           'jitter: ${jitter}ms, quality: $audioQuality, score: $overallScore)';
  }
}
