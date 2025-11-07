// Adaptive Bitrate Streaming Service (HLS/DASH)
// Implements Task 9: Adaptive bitrate streaming for optimal playback

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Adaptive Streaming Service
/// Manages HLS/DASH adaptive bitrate streaming for optimal video playback
class AdaptiveStreamingService {
  static AdaptiveStreamingService? _instance;
  static AdaptiveStreamingService get instance =>
      _instance ??= AdaptiveStreamingService._internal();

  AdaptiveStreamingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Streaming configuration
  static const List<StreamQuality> availableQualities = [
    StreamQuality.sd480p,
    StreamQuality.hd720p,
    StreamQuality.hd1080p,
    StreamQuality.uhd4k,
  ];

  /// Generate HLS manifest for adaptive streaming
  Future<HLSManifest> generateHLSManifest({
    required String videoId,
    required String postId,
    required Map<String, String> qualityUrls,
  }) async {
    try {
      debugPrint('📺 Generating HLS manifest for video: $videoId');

      // Create master playlist
      final masterPlaylist = _createMasterPlaylist(qualityUrls);

      // Store manifest in Firestore
      final manifestData = {
        'videoId': videoId,
        'postId': postId,
        'type': 'hls',
        'masterPlaylist': masterPlaylist,
        'qualityUrls': qualityUrls,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('streaming_manifests').add(manifestData);

      debugPrint('✅ HLS manifest generated: ${docRef.id}');

      return HLSManifest(
        id: docRef.id,
        videoId: videoId,
        masterPlaylist: masterPlaylist,
        qualityUrls: qualityUrls,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Failed to generate HLS manifest: $e');
      rethrow;
    }
  }

  /// Generate DASH manifest for adaptive streaming
  Future<DASHManifest> generateDASHManifest({
    required String videoId,
    required String postId,
    required Map<String, String> qualityUrls,
  }) async {
    try {
      debugPrint('📺 Generating DASH manifest for video: $videoId');

      // Create MPD (Media Presentation Description)
      final mpd = _createMPD(qualityUrls);

      // Store manifest in Firestore
      final manifestData = {
        'videoId': videoId,
        'postId': postId,
        'type': 'dash',
        'mpd': mpd,
        'qualityUrls': qualityUrls,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('streaming_manifests').add(manifestData);

      debugPrint('✅ DASH manifest generated: ${docRef.id}');

      return DASHManifest(
        id: docRef.id,
        videoId: videoId,
        mpd: mpd,
        qualityUrls: qualityUrls,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Failed to generate DASH manifest: $e');
      rethrow;
    }
  }

  /// Get optimal quality based on network conditions
  StreamQuality getOptimalQuality({
    required NetworkSpeed networkSpeed,
    required DeviceCapability deviceCapability,
    bool dataSaverMode = false,
  }) {
    if (dataSaverMode) {
      return StreamQuality.sd480p;
    }

    // Determine optimal quality based on network speed and device capability
    switch (networkSpeed) {
      case NetworkSpeed.slow:
        return StreamQuality.sd480p;

      case NetworkSpeed.moderate:
        return deviceCapability == DeviceCapability.high
            ? StreamQuality.hd720p
            : StreamQuality.sd480p;

      case NetworkSpeed.fast:
        if (deviceCapability == DeviceCapability.high) {
          return StreamQuality.hd1080p;
        } else if (deviceCapability == DeviceCapability.medium) {
          return StreamQuality.hd720p;
        }
        return StreamQuality.sd480p;

      case NetworkSpeed.veryFast:
        if (deviceCapability == DeviceCapability.high) {
          return StreamQuality.uhd4k;
        } else if (deviceCapability == DeviceCapability.medium) {
          return StreamQuality.hd1080p;
        }
        return StreamQuality.hd720p;
    }
  }

  /// Detect network speed
  Future<NetworkSpeed> detectNetworkSpeed() async {
    try {
      // This is a simplified implementation
      // In production, you would measure actual download speed
      // using a test file or network monitoring

      // For now, return a default value
      // TODO: Implement actual network speed detection
      return NetworkSpeed.moderate;
    } catch (e) {
      debugPrint('❌ Failed to detect network speed: $e');
      return NetworkSpeed.moderate;
    }
  }

  /// Detect device capability
  DeviceCapability detectDeviceCapability() {
    // Simplified device capability detection
    // In production, you would check actual device specs

    if (kIsWeb) {
      return DeviceCapability.high;
    }

    // TODO: Implement actual device capability detection
    // Check screen resolution, CPU, GPU, memory, etc.
    return DeviceCapability.medium;
  }

  /// Create HLS master playlist
  String _createMasterPlaylist(Map<String, String> qualityUrls) {
    final buffer = StringBuffer();

    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:3');

    // Add quality variants
    qualityUrls.forEach((quality, url) {
      final qualityInfo = _getQualityInfo(quality);

      buffer.writeln(
        '#EXT-X-STREAM-INF:BANDWIDTH=${qualityInfo.bandwidth},'
        'RESOLUTION=${qualityInfo.resolution},'
        'CODECS="${qualityInfo.codecs}"',
      );
      buffer.writeln(url);
    });

    return buffer.toString();
  }

  /// Create DASH MPD (Media Presentation Description)
  String _createMPD(Map<String, String> qualityUrls) {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" '
      'type="static" '
      'mediaPresentationDuration="PT0H0M0S" '
      'minBufferTime="PT2S">',
    );

    buffer.writeln('  <Period>');
    buffer.writeln('    <AdaptationSet mimeType="video/mp4" codecs="avc1.4d401f">');

    // Add quality representations
    qualityUrls.forEach((quality, url) {
      final qualityInfo = _getQualityInfo(quality);

      buffer.writeln(
        '      <Representation '
        'id="$quality" '
        'bandwidth="${qualityInfo.bandwidth}" '
        'width="${qualityInfo.width}" '
        'height="${qualityInfo.height}">',
      );
      buffer.writeln('        <BaseURL>$url</BaseURL>');
      buffer.writeln('      </Representation>');
    });

    buffer.writeln('    </AdaptationSet>');
    buffer.writeln('  </Period>');
    buffer.writeln('</MPD>');

    return buffer.toString();
  }

  /// Get quality information
  QualityInfo _getQualityInfo(String quality) {
    switch (quality) {
      case '480p':
        return const QualityInfo(
          bandwidth: 800000,
          resolution: '854x480',
          width: 854,
          height: 480,
          codecs: 'avc1.4d401e',
        );

      case '720p':
        return const QualityInfo(
          bandwidth: 2000000,
          resolution: '1280x720',
          width: 1280,
          height: 720,
          codecs: 'avc1.4d401f',
        );

      case '1080p':
        return const QualityInfo(
          bandwidth: 4000000,
          resolution: '1920x1080',
          width: 1920,
          height: 1080,
          codecs: 'avc1.640028',
        );

      case '4k':
        return const QualityInfo(
          bandwidth: 8000000,
          resolution: '3840x2160',
          width: 3840,
          height: 2160,
          codecs: 'avc1.640033',
        );

      default:
        return const QualityInfo(
          bandwidth: 2000000,
          resolution: '1280x720',
          width: 1280,
          height: 720,
          codecs: 'avc1.4d401f',
        );
    }
  }

  /// Get streaming manifest
  Future<StreamingManifest?> getStreamingManifest(String videoId) async {
    try {
      final querySnapshot = await _firestore
          .collection('streaming_manifests')
          .where('videoId', isEqualTo: videoId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      return StreamingManifest(
        id: doc.id,
        videoId: data['videoId'],
        type: data['type'],
        manifest: data['type'] == 'hls' ? data['masterPlaylist'] : data['mpd'],
        qualityUrls: Map<String, String>.from(data['qualityUrls']),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Failed to get streaming manifest: $e');
      return null;
    }
  }
}

// Enums

enum StreamQuality {
  sd480p,
  hd720p,
  hd1080p,
  uhd4k,
}

enum NetworkSpeed {
  slow, // < 1 Mbps
  moderate, // 1-5 Mbps
  fast, // 5-10 Mbps
  veryFast, // > 10 Mbps
}

enum DeviceCapability {
  low,
  medium,
  high,
}

// Data Classes

class HLSManifest {
  final String id;
  final String videoId;
  final String masterPlaylist;
  final Map<String, String> qualityUrls;
  final DateTime createdAt;

  const HLSManifest({
    required this.id,
    required this.videoId,
    required this.masterPlaylist,
    required this.qualityUrls,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'masterPlaylist': masterPlaylist,
        'qualityUrls': qualityUrls,
        'createdAt': createdAt.toIso8601String(),
      };
}

class DASHManifest {
  final String id;
  final String videoId;
  final String mpd;
  final Map<String, String> qualityUrls;
  final DateTime createdAt;

  const DASHManifest({
    required this.id,
    required this.videoId,
    required this.mpd,
    required this.qualityUrls,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'mpd': mpd,
        'qualityUrls': qualityUrls,
        'createdAt': createdAt.toIso8601String(),
      };
}

class StreamingManifest {
  final String id;
  final String videoId;
  final String type; // 'hls' or 'dash'
  final String manifest;
  final Map<String, String> qualityUrls;
  final DateTime createdAt;

  const StreamingManifest({
    required this.id,
    required this.videoId,
    required this.type,
    required this.manifest,
    required this.qualityUrls,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'type': type,
        'manifest': manifest,
        'qualityUrls': qualityUrls,
        'createdAt': createdAt.toIso8601String(),
      };
}

class QualityInfo {
  final int bandwidth;
  final String resolution;
  final int width;
  final int height;
  final String codecs;

  const QualityInfo({
    required this.bandwidth,
    required this.resolution,
    required this.width,
    required this.height,
    required this.codecs,
  });
}
