import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Manages adaptive bitrate streaming based on network conditions
class AdaptiveBitrateManager {
  static final AdaptiveBitrateManager _instance = AdaptiveBitrateManager._internal();
  factory AdaptiveBitrateManager() => _instance;
  AdaptiveBitrateManager._internal();

  final Connectivity _connectivity = Connectivity();
  StreamQuality _currentQuality = StreamQuality.hd720p;
  NetworkCondition _currentCondition = NetworkCondition.good;
  
  final StreamController<StreamQuality> _qualityController = StreamController<StreamQuality>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Network quality thresholds (in Mbps)
  static const double _excellentThreshold = 5.0;
  static const double _goodThreshold = 2.5;
  static const double _fairThreshold = 1.0;
  static const double _poorThreshold = 0.5;

  /// Initialize adaptive bitrate monitoring
  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateNetworkCondition(results);
    });
  }

  /// Get current recommended quality
  StreamQuality get currentQuality => _currentQuality;

  /// Get quality change stream
  Stream<StreamQuality> get qualityStream => _qualityController.stream;

  /// Manually set quality
  void setQuality(StreamQuality quality) {
    if (_currentQuality != quality) {
      _currentQuality = quality;
      _qualityController.add(quality);
    }
  }

  /// Get recommended quality based on network conditions
  StreamQuality getRecommendedQuality() {
    switch (_currentCondition) {
      case NetworkCondition.excellent:
        return StreamQuality.hd1080p;
      case NetworkCondition.good:
        return StreamQuality.hd720p;
      case NetworkCondition.fair:
        return StreamQuality.sd480p;
      case NetworkCondition.poor:
        return StreamQuality.sd480p;
      case NetworkCondition.offline:
        return StreamQuality.sd480p;
    }
  }

  /// Update quality based on network speed test
  Future<void> updateQualityFromSpeedTest(double downloadSpeedMbps) async {
    final newCondition = _getConditionFromSpeed(downloadSpeedMbps);
    
    if (newCondition != _currentCondition) {
      _currentCondition = newCondition;
      final recommendedQuality = getRecommendedQuality();
      
      if (recommendedQuality != _currentQuality) {
        _currentQuality = recommendedQuality;
        _qualityController.add(_currentQuality);
      }
    }
  }

  /// Update quality based on buffer health
  void updateQualityFromBufferHealth(BufferHealth bufferHealth) {
    StreamQuality newQuality = _currentQuality;

    switch (bufferHealth) {
      case BufferHealth.critical:
        // Downgrade significantly
        newQuality = _downgradeQuality(_currentQuality, steps: 2);
        break;
      case BufferHealth.low:
        // Downgrade one step
        newQuality = _downgradeQuality(_currentQuality, steps: 1);
        break;
      case BufferHealth.good:
        // Maintain current quality
        break;
      case BufferHealth.excellent:
        // Try to upgrade if network allows
        final recommendedQuality = getRecommendedQuality();
        if (_getQualityLevel(recommendedQuality) > _getQualityLevel(_currentQuality)) {
          newQuality = _upgradeQuality(_currentQuality, steps: 1);
        }
        break;
    }

    if (newQuality != _currentQuality) {
      _currentQuality = newQuality;
      _qualityController.add(_currentQuality);
    }
  }

  /// Get bitrate for quality level
  int getBitrateForQuality(StreamQuality quality) {
    switch (quality) {
      case StreamQuality.sd480p:
        return 1000000; // 1 Mbps
      case StreamQuality.hd720p:
        return 2500000; // 2.5 Mbps
      case StreamQuality.hd1080p:
        return 5000000; // 5 Mbps
      case StreamQuality.uhd4k:
        return 15000000; // 15 Mbps
    }
  }

  /// Get resolution for quality level
  Map<String, int> getResolutionForQuality(StreamQuality quality) {
    switch (quality) {
      case StreamQuality.sd480p:
        return {'width': 854, 'height': 480};
      case StreamQuality.hd720p:
        return {'width': 1280, 'height': 720};
      case StreamQuality.hd1080p:
        return {'width': 1920, 'height': 1080};
      case StreamQuality.uhd4k:
        return {'width': 3840, 'height': 2160};
    }
  }

  /// Get frame rate for quality level
  int getFrameRateForQuality(StreamQuality quality) {
    switch (quality) {
      case StreamQuality.sd480p:
        return 24;
      case StreamQuality.hd720p:
        return 30;
      case StreamQuality.hd1080p:
        return 30;
      case StreamQuality.uhd4k:
        return 60;
    }
  }

  // Private helper methods

  void _updateNetworkCondition(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      _currentCondition = NetworkCondition.offline;
    } else if (results.contains(ConnectivityResult.wifi)) {
      _currentCondition = NetworkCondition.excellent;
    } else if (results.contains(ConnectivityResult.mobile)) {
      _currentCondition = NetworkCondition.good;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      _currentCondition = NetworkCondition.excellent;
    } else {
      _currentCondition = NetworkCondition.fair;
    }

    final recommendedQuality = getRecommendedQuality();
    if (recommendedQuality != _currentQuality) {
      _currentQuality = recommendedQuality;
      _qualityController.add(_currentQuality);
    }
  }

  NetworkCondition _getConditionFromSpeed(double speedMbps) {
    if (speedMbps >= _excellentThreshold) {
      return NetworkCondition.excellent;
    } else if (speedMbps >= _goodThreshold) {
      return NetworkCondition.good;
    } else if (speedMbps >= _fairThreshold) {
      return NetworkCondition.fair;
    } else if (speedMbps >= _poorThreshold) {
      return NetworkCondition.poor;
    } else {
      return NetworkCondition.poor;
    }
  }

  StreamQuality _downgradeQuality(StreamQuality current, {int steps = 1}) {
    final currentLevel = _getQualityLevel(current);
    final newLevel = (currentLevel - steps).clamp(0, 3);
    return _getQualityFromLevel(newLevel);
  }

  StreamQuality _upgradeQuality(StreamQuality current, {int steps = 1}) {
    final currentLevel = _getQualityLevel(current);
    final newLevel = (currentLevel + steps).clamp(0, 3);
    return _getQualityFromLevel(newLevel);
  }

  int _getQualityLevel(StreamQuality quality) {
    switch (quality) {
      case StreamQuality.sd480p:
        return 0;
      case StreamQuality.hd720p:
        return 1;
      case StreamQuality.hd1080p:
        return 2;
      case StreamQuality.uhd4k:
        return 3;
    }
  }

  StreamQuality _getQualityFromLevel(int level) {
    switch (level) {
      case 0:
        return StreamQuality.sd480p;
      case 1:
        return StreamQuality.hd720p;
      case 2:
        return StreamQuality.hd1080p;
      case 3:
        return StreamQuality.uhd4k;
      default:
        return StreamQuality.hd720p;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _qualityController.close();
  }
}

enum StreamQuality {
  sd480p,
  hd720p,
  hd1080p,
  uhd4k,
}

enum NetworkCondition {
  excellent,
  good,
  fair,
  poor,
  offline,
}

enum BufferHealth {
  critical,  // < 2 seconds
  low,       // 2-5 seconds
  good,      // 5-10 seconds
  excellent, // > 10 seconds
}
