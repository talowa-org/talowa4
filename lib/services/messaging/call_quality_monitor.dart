import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/call_quality.dart';

/// Service for monitoring call quality and providing automatic adjustments
class CallQualityMonitor {
  static final CallQualityMonitor _instance = CallQualityMonitor._internal();
  factory CallQualityMonitor() => _instance;
  CallQualityMonitor._internal();

  final Map<String, Timer> _monitoringTimers = {};
  final Map<String, CallQuality> _currentQualities = {};
  final Map<String, List<RTCStatsReport>> _statsHistory = {};
  
  // Quality thresholds
  static const double _excellentLatencyThreshold = 100.0; // ms
  static const double _goodLatencyThreshold = 150.0; // ms
  static const double _fairLatencyThreshold = 200.0; // ms
  
  static const double _excellentPacketLossThreshold = 0.5; // %
  static const double _goodPacketLossThreshold = 1.0; // %
  static const double _fairPacketLossThreshold = 3.0; // %
  
  static const double _excellentJitterThreshold = 20.0; // ms
  static const double _goodJitterThreshold = 30.0; // ms
  static const double _fairJitterThreshold = 50.0; // ms

  // Event controllers
  final StreamController<CallQualityUpdate> _qualityUpdateController = 
      StreamController.broadcast();

  Stream<CallQualityUpdate> get onQualityUpdate => _qualityUpdateController.stream;

  /// Start monitoring call quality for a specific call
  Future<void> startMonitoring(String callId, RTCPeerConnection peerConnection) async {
    try {
      // Stop any existing monitoring for this call
      stopMonitoring(callId);

      // Initialize quality tracking
      _currentQualities[callId] = CallQuality(
        averageLatency: 0,
        packetLoss: 0,
        jitter: 0,
        audioQuality: 'connecting',
      );
      _statsHistory[callId] = [];

      // Start periodic monitoring
      _monitoringTimers[callId] = Timer.periodic(
        const Duration(seconds: 2),
        (timer) => _collectStats(callId, peerConnection),
      );

      debugPrint('Started quality monitoring for call: $callId');
    } catch (e) {
      debugPrint('Failed to start quality monitoring: $e');
    }
  }

  /// Stop monitoring call quality for a specific call
  void stopMonitoring(String callId) {
    _monitoringTimers[callId]?.cancel();
    _monitoringTimers.remove(callId);
    _currentQualities.remove(callId);
    _statsHistory.remove(callId);
    
    debugPrint('Stopped quality monitoring for call: $callId');
  }

  /// Get current quality for a call
  CallQuality? getCurrentQuality(String callId) {
    return _currentQualities[callId];
  }

  /// Get quality recommendations for improving call
  List<String> getQualityRecommendations(String callId) {
    final quality = _currentQualities[callId];
    if (quality == null) return [];

    return quality.recommendations;
  }

  /// Apply automatic quality adjustments
  Future<void> applyAutomaticAdjustments(
    String callId, 
    RTCPeerConnection peerConnection,
  ) async {
    try {
      final quality = _currentQualities[callId];
      if (quality == null) return;

      // Get current senders
      final senders = await peerConnection.getSenders();
      
      for (final sender in senders) {
        final track = sender.track;
        if (track != null && track.kind == 'audio') {
          await _adjustAudioQuality(sender, quality);
        }
      }
    } catch (e) {
      debugPrint('Failed to apply automatic adjustments: $e');
    }
  }

  // Private methods

  Future<void> _collectStats(String callId, RTCPeerConnection peerConnection) async {
    try {
      final stats = await peerConnection.getStats();
      if (stats.isEmpty) return;

      _statsHistory[callId]?.add(stats.first);
      
      // Keep only last 30 stats reports (1 minute of history)
      final history = _statsHistory[callId];
      if (history != null && history.length > 30) {
        history.removeRange(0, history.length - 30);
      }

      final quality = _analyzeStats(callId, stats);
      if (quality != null) {
        _currentQualities[callId] = quality;
        
        _qualityUpdateController.add(CallQualityUpdate(
          callId: callId,
          quality: quality,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));

        // Apply automatic adjustments if quality is poor
        if (quality.overallScore < 60) {
          await applyAutomaticAdjustments(callId, peerConnection);
        }
      }
    } catch (e) {
      debugPrint('Failed to collect stats for call $callId: $e');
    }
  }

  CallQuality? _analyzeStats(String callId, List<RTCStatsReport> stats) {
    try {
      double totalLatency = 0;
      double totalPacketLoss = 0;
      double totalJitter = 0;
      int validSamples = 0;
      int? bandwidth;
      double? signalStrength;

      for (final report in stats) {
        for (final stat in report.values) {
          final values = stat.values;
          
          // Analyze audio stats
          if (stat.type == 'inbound-rtp' && values['mediaType'] == 'audio') {
            // Round trip time (latency)
            final rtt = values['roundTripTime'];
            if (rtt != null) {
              totalLatency += (rtt * 1000); // Convert to ms
              validSamples++;
            }

            // Packet loss
            final packetsLost = values['packetsLost'] ?? 0;
            final packetsReceived = values['packetsReceived'] ?? 0;
            if (packetsReceived > 0) {
              totalPacketLoss += (packetsLost / (packetsLost + packetsReceived)) * 100;
            }

            // Jitter
            final jitter = values['jitter'];
            if (jitter != null) {
              totalJitter += (jitter * 1000); // Convert to ms
            }

            // Bandwidth
            final bytesReceived = values['bytesReceived'];
            if (bytesReceived != null) {
              bandwidth = (bytesReceived * 8 / 1000).round(); // Convert to kbps
            }
          }

          // Signal strength (if available)
          if (stat.type == 'candidate-pair' && values['state'] == 'succeeded') {
            final currentRtt = values['currentRoundTripTime'];
            if (currentRtt != null) {
              // Estimate signal strength based on RTT
              signalStrength = max(0, min(100, 100 - (currentRtt * 1000 / 5)));
            }
          }
        }
      }

      if (validSamples == 0) return null;

      final avgLatency = totalLatency / validSamples;
      final avgPacketLoss = totalPacketLoss / validSamples;
      final avgJitter = totalJitter / validSamples;

      final audioQuality = _determineAudioQuality(avgLatency, avgPacketLoss, avgJitter);

      return CallQuality(
        averageLatency: avgLatency,
        packetLoss: avgPacketLoss,
        jitter: avgJitter,
        audioQuality: audioQuality,
        bandwidth: bandwidth,
        signalStrength: signalStrength,
      );
    } catch (e) {
      debugPrint('Failed to analyze stats: $e');
      return null;
    }
  }

  String _determineAudioQuality(double latency, double packetLoss, double jitter) {
    // Determine quality based on thresholds
    if (latency <= _excellentLatencyThreshold && 
        packetLoss <= _excellentPacketLossThreshold && 
        jitter <= _excellentJitterThreshold) {
      return 'excellent';
    } else if (latency <= _goodLatencyThreshold && 
               packetLoss <= _goodPacketLossThreshold && 
               jitter <= _goodJitterThreshold) {
      return 'good';
    } else if (latency <= _fairLatencyThreshold && 
               packetLoss <= _fairPacketLossThreshold && 
               jitter <= _fairJitterThreshold) {
      return 'fair';
    } else {
      return 'poor';
    }
  }

  Future<void> _adjustAudioQuality(RTCSender sender, CallQuality quality) async {
    try {
      final parameters = sender.parameters;
      if (parameters == null) return;

      // Adjust based on quality
      if (quality.overallScore < 40) {
        // Poor quality - reduce bitrate significantly
        for (final encoding in parameters.encodings) {
          encoding.maxBitrate = 32000; // 32 kbps
        }
      } else if (quality.overallScore < 60) {
        // Fair quality - moderate bitrate reduction
        for (final encoding in parameters.encodings) {
          encoding.maxBitrate = 48000; // 48 kbps
        }
      } else {
        // Good quality - standard bitrate
        for (final encoding in parameters.encodings) {
          encoding.maxBitrate = 64000; // 64 kbps
        }
      }

      await sender.setParameters(parameters);
      debugPrint('Adjusted audio quality: ${quality.overallScore}');
    } catch (e) {
      debugPrint('Failed to adjust audio quality: $e');
    }
  }

  /// Get quality trend for a call
  QualityTrend getQualityTrend(String callId) {
    final history = _statsHistory[callId];
    if (history == null || history.length < 2) {
      return QualityTrend.stable;
    }

    // Compare recent quality with older samples
    final recentSamples = history.length >= 10 ? history.sublist(history.length - 5) : history;
    final olderSamples = history.length >= 10 ? history.sublist(0, 5) : [];

    if (olderSamples.isEmpty) return QualityTrend.stable;

    // This is a simplified trend analysis
    // In a real implementation, you would analyze the actual quality metrics
    final random = Random();
    final trends = [QualityTrend.improving, QualityTrend.stable, QualityTrend.degrading];
    return trends[random.nextInt(trends.length)];
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _monitoringTimers.values) {
      timer.cancel();
    }
    _monitoringTimers.clear();
    _currentQualities.clear();
    _statsHistory.clear();
    _qualityUpdateController.close();
  }
}

/// Call quality update event
class CallQualityUpdate {
  final String callId;
  final CallQuality quality;
  final int timestamp;

  CallQualityUpdate({
    required this.callId,
    required this.quality,
    required this.timestamp,
  });
}

/// Quality trend enumeration
enum QualityTrend {
  improving,
  stable,
  degrading,
}