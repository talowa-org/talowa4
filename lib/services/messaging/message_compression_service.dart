// Message Compression Service for TALOWA
// Implements Task 8: Create offline messaging and synchronization - Data Compression
// Reference: in-app-communication/requirements.md - Requirements 8.4

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MessageCompressionService {
  static final MessageCompressionService _instance = MessageCompressionService._internal();
  factory MessageCompressionService() => _instance;
  MessageCompressionService._internal();

  // Compression configuration
  static const int _textCompressionThreshold = 512; // bytes
  static const int _imageCompressionThreshold = 1024 * 100; // 100KB
  static const double _imageQualityHigh = 0.9;
  static const double _imageQualityMedium = 0.7;
  static const double _imageQualityLow = 0.5;
  static const int _maxImageWidth = 1920;
  static const int _maxImageHeight = 1080;

  /// Compress text content using gzip
  Future<String> compressText(String text) async {
    try {
      if (text.length < _textCompressionThreshold) {
        return text; // Don't compress small texts
      }

      final bytes = utf8.encode(text);
      final compressed = gzip.encode(bytes);
      final base64Compressed = base64.encode(compressed);
      
      // Only return compressed version if it's actually smaller
      if (base64Compressed.length < text.length) {
        debugPrint('Text compressed: ${text.length} -> ${base64Compressed.length} bytes');
        return base64Compressed;
      }
      
      return text;
    } catch (e) {
      debugPrint('Error compressing text: $e');
      return text; // Return original on error
    }
  }

  /// Decompress text content
  Future<String> decompressText(String compressedText) async {
    try {
      // Try to decode as base64 first
      final compressed = base64.decode(compressedText);
      final decompressed = gzip.decode(compressed);
      final text = utf8.decode(decompressed);
      
      debugPrint('Text decompressed: ${compressedText.length} -> ${text.length} bytes');
      return text;
    } catch (e) {
      // If decompression fails, assume it's not compressed
      return compressedText;
    }
  }

  /// Compress image based on network conditions and size
  Future<CompressionResult> compressImage({
    required String imagePath,
    NetworkQuality? networkQuality,
    int? maxSizeBytes,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      final originalSize = await file.length();
      
      // Skip compression if image is already small
      if (originalSize < _imageCompressionThreshold) {
        return CompressionResult(
          success: true,
          originalPath: imagePath,
          compressedPath: imagePath,
          originalSize: originalSize,
          compressedSize: originalSize,
          compressionRatio: 0,
        );
      }

      // Determine compression quality based on network conditions
      final quality = _getImageQuality(networkQuality);
      
      // Load and process image
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if too large
      img.Image processedImage = image;
      if (image.width > _maxImageWidth || image.height > _maxImageHeight) {
        processedImage = img.copyResize(
          image,
          width: image.width > _maxImageWidth ? _maxImageWidth : null,
          height: image.height > _maxImageHeight ? _maxImageHeight : null,
          maintainAspect: true,
        );
      }

      // Compress image
      final compressedBytes = img.encodeJpg(processedImage, quality: (quality * 100).round());
      
      // Save compressed image
      final compressedPath = await _saveCompressedImage(imagePath, compressedBytes);
      
      final compressionRatio = ((originalSize - compressedBytes.length) / originalSize) * 100;
      
      debugPrint('Image compressed: $originalSize -> ${compressedBytes.length} bytes (${compressionRatio.toStringAsFixed(1)}%)');
      
      return CompressionResult(
        success: true,
        originalPath: imagePath,
        compressedPath: compressedPath,
        originalSize: originalSize,
        compressedSize: compressedBytes.length,
        compressionRatio: compressionRatio,
      );
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return CompressionResult(
        success: false,
        originalPath: imagePath,
        compressedPath: imagePath,
        originalSize: 0,
        compressedSize: 0,
        compressionRatio: 0,
        error: e.toString(),
      );
    }
  }

  /// Compress message data based on network conditions
  Future<MessageCompressionResult> compressMessageData({
    required String content,
    required List<String> mediaUrls,
    required Map<String, dynamic> metadata,
    NetworkQuality? networkQuality,
  }) async {
    try {
      final startTime = DateTime.now();
      
      // Detect network quality if not provided
      networkQuality ??= await _detectNetworkQuality();
      
      // Compress text content
      final compressedContent = await compressText(content);
      final contentCompressionRatio = content.isNotEmpty 
          ? ((content.length - compressedContent.length) / content.length) * 100
          : 0;

      // Compress media files
      final compressedMediaUrls = <String>[];
      final mediaCompressionResults = <CompressionResult>[];
      
      for (final mediaUrl in mediaUrls) {
        if (_isLocalFile(mediaUrl)) {
          final compressionResult = await compressImage(
            imagePath: mediaUrl,
            networkQuality: networkQuality,
          );
          
          mediaCompressionResults.add(compressionResult);
          compressedMediaUrls.add(compressionResult.compressedPath);
        } else {
          compressedMediaUrls.add(mediaUrl); // Keep remote URLs as-is
        }
      }

      // Compress metadata if it's large
      final metadataJson = jsonEncode(metadata);
      final compressedMetadata = metadataJson.length > 256 
          ? await compressText(metadataJson)
          : metadataJson;
      
      final metadataCompressionRatio = metadataJson.isNotEmpty
          ? ((metadataJson.length - compressedMetadata.length) / metadataJson.length) * 100
          : 0;

      final duration = DateTime.now().difference(startTime);
      
      return MessageCompressionResult(
        success: true,
        compressedContent: compressedContent,
        compressedMediaUrls: compressedMediaUrls,
        compressedMetadata: compressedMetadata != metadataJson 
            ? {'compressed': true, 'data': compressedMetadata}
            : metadata,
        contentCompressionRatio: contentCompressionRatio,
        metadataCompressionRatio: metadataCompressionRatio,
        mediaCompressionResults: mediaCompressionResults,
        networkQuality: networkQuality,
        compressionDuration: duration,
      );
    } catch (e) {
      debugPrint('Error compressing message data: $e');
      return MessageCompressionResult(
        success: false,
        compressedContent: content,
        compressedMediaUrls: mediaUrls,
        compressedMetadata: metadata,
        contentCompressionRatio: 0,
        metadataCompressionRatio: 0,
        mediaCompressionResults: [],
        networkQuality: networkQuality ?? NetworkQuality.unknown,
        error: e.toString(),
      );
    }
  }

  /// Decompress message data
  Future<MessageDecompressionResult> decompressMessageData({
    required String compressedContent,
    required List<String> compressedMediaUrls,
    required Map<String, dynamic> compressedMetadata,
  }) async {
    try {
      // Decompress text content
      final decompressedContent = await decompressText(compressedContent);
      
      // Media URLs are typically not compressed in transit, just locally
      final decompressedMediaUrls = compressedMediaUrls;
      
      // Decompress metadata if it was compressed
      Map<String, dynamic> decompressedMetadata = compressedMetadata;
      if (compressedMetadata.containsKey('compressed') && 
          compressedMetadata['compressed'] == true) {
        final compressedData = compressedMetadata['data'] as String;
        final decompressedJson = await decompressText(compressedData);
        decompressedMetadata = jsonDecode(decompressedJson);
      }

      return MessageDecompressionResult(
        success: true,
        decompressedContent: decompressedContent,
        decompressedMediaUrls: decompressedMediaUrls,
        decompressedMetadata: decompressedMetadata,
      );
    } catch (e) {
      debugPrint('Error decompressing message data: $e');
      return MessageDecompressionResult(
        success: false,
        decompressedContent: compressedContent,
        decompressedMediaUrls: compressedMediaUrls,
        decompressedMetadata: compressedMetadata,
        error: e.toString(),
      );
    }
  }

  /// Get optimal compression settings for current network conditions
  Future<CompressionSettings> getOptimalCompressionSettings() async {
    try {
      final networkQuality = await _detectNetworkQuality();
      
      switch (networkQuality) {
        case NetworkQuality.excellent:
          return CompressionSettings(
            enableTextCompression: false,
            enableImageCompression: false,
            imageQuality: _imageQualityHigh,
            maxImageSize: 1920 * 1080,
            aggressiveCompression: false,
          );
          
        case NetworkQuality.good:
          return CompressionSettings(
            enableTextCompression: true,
            enableImageCompression: true,
            imageQuality: _imageQualityMedium,
            maxImageSize: 1280 * 720,
            aggressiveCompression: false,
          );
          
        case NetworkQuality.poor:
          return CompressionSettings(
            enableTextCompression: true,
            enableImageCompression: true,
            imageQuality: _imageQualityLow,
            maxImageSize: 640 * 480,
            aggressiveCompression: true,
          );
          
        case NetworkQuality.veryPoor:
          return CompressionSettings(
            enableTextCompression: true,
            enableImageCompression: true,
            imageQuality: 0.3,
            maxImageSize: 320 * 240,
            aggressiveCompression: true,
          );
          
        default:
          return CompressionSettings(
            enableTextCompression: true,
            enableImageCompression: true,
            imageQuality: _imageQualityMedium,
            maxImageSize: 1280 * 720,
            aggressiveCompression: false,
          );
      }
    } catch (e) {
      debugPrint('Error getting optimal compression settings: $e');
      return CompressionSettings(
        enableTextCompression: true,
        enableImageCompression: true,
        imageQuality: _imageQualityMedium,
        maxImageSize: 1280 * 720,
        aggressiveCompression: false,
      );
    }
  }

  /// Calculate compression statistics
  Future<CompressionStatistics> getCompressionStatistics() async {
    try {
      // This would typically be stored in a database or shared preferences
      // For now, return mock statistics
      return CompressionStatistics(
        totalMessagesCompressed: 0,
        totalBytesOriginal: 0,
        totalBytesCompressed: 0,
        averageCompressionRatio: 0,
        totalCompressionTime: Duration.zero,
      );
    } catch (e) {
      debugPrint('Error getting compression statistics: $e');
      return CompressionStatistics(
        totalMessagesCompressed: 0,
        totalBytesOriginal: 0,
        totalBytesCompressed: 0,
        averageCompressionRatio: 0,
        totalCompressionTime: Duration.zero,
      );
    }
  }

  // Private helper methods

  /// Detect current network quality
  Future<NetworkQuality> _detectNetworkQuality() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      
      switch (connectivity) {
        case ConnectivityResult.wifi:
          return NetworkQuality.excellent;
        case ConnectivityResult.mobile:
          // Could implement more sophisticated detection here
          // For now, assume mobile is good quality
          return NetworkQuality.good;
        case ConnectivityResult.ethernet:
          return NetworkQuality.excellent;
        default:
          return NetworkQuality.unknown;
      }
    } catch (e) {
      debugPrint('Error detecting network quality: $e');
      return NetworkQuality.unknown;
    }
  }

  /// Get image compression quality based on network conditions
  double _getImageQuality(NetworkQuality? networkQuality) {
    switch (networkQuality) {
      case NetworkQuality.excellent:
        return _imageQualityHigh;
      case NetworkQuality.good:
        return _imageQualityMedium;
      case NetworkQuality.poor:
        return _imageQualityLow;
      case NetworkQuality.veryPoor:
        return 0.3;
      default:
        return _imageQualityMedium;
    }
  }

  /// Check if URL is a local file
  bool _isLocalFile(String url) {
    return !url.startsWith('http://') && !url.startsWith('https://');
  }

  /// Save compressed image to temporary directory
  Future<String> _saveCompressedImage(String originalPath, Uint8List compressedBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final originalFile = File(originalPath);
      final fileName = originalFile.uri.pathSegments.last;
      final nameWithoutExtension = fileName.split('.').first;
      
      final compressedPath = '${tempDir.path}/compressed_${nameWithoutExtension}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(compressedPath);
      
      await compressedFile.writeAsBytes(compressedBytes);
      return compressedPath;
    } catch (e) {
      debugPrint('Error saving compressed image: $e');
      rethrow;
    }
  }
}

// Data models for compression

enum NetworkQuality {
  excellent,
  good,
  poor,
  veryPoor,
  unknown,
}

class CompressionSettings {
  final bool enableTextCompression;
  final bool enableImageCompression;
  final double imageQuality;
  final int maxImageSize;
  final bool aggressiveCompression;

  CompressionSettings({
    required this.enableTextCompression,
    required this.enableImageCompression,
    required this.imageQuality,
    required this.maxImageSize,
    required this.aggressiveCompression,
  });
}

class CompressionResult {
  final bool success;
  final String originalPath;
  final String compressedPath;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final String? error;

  CompressionResult({
    required this.success,
    required this.originalPath,
    required this.compressedPath,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    this.error,
  });

  int get bytesSaved => originalSize - compressedSize;
  bool get wasCompressed => compressionRatio > 0;
}

class MessageCompressionResult {
  final bool success;
  final String compressedContent;
  final List<String> compressedMediaUrls;
  final Map<String, dynamic> compressedMetadata;
  final double contentCompressionRatio;
  final double metadataCompressionRatio;
  final List<CompressionResult> mediaCompressionResults;
  final NetworkQuality networkQuality;
  final Duration? compressionDuration;
  final String? error;

  MessageCompressionResult({
    required this.success,
    required this.compressedContent,
    required this.compressedMediaUrls,
    required this.compressedMetadata,
    required this.contentCompressionRatio,
    required this.metadataCompressionRatio,
    required this.mediaCompressionResults,
    required this.networkQuality,
    this.compressionDuration,
    this.error,
  });

  double get overallCompressionRatio {
    if (mediaCompressionResults.isEmpty) {
      return (contentCompressionRatio + metadataCompressionRatio) / 2;
    }
    
    final mediaRatio = mediaCompressionResults
        .map((r) => r.compressionRatio)
        .reduce((a, b) => a + b) / mediaCompressionResults.length;
    
    return (contentCompressionRatio + metadataCompressionRatio + mediaRatio) / 3;
  }

  int get totalBytesSaved {
    final mediaBytesSaved = mediaCompressionResults
        .map((r) => r.bytesSaved)
        .fold(0, (a, b) => a + b);
    
    return mediaBytesSaved; // Text compression savings are harder to calculate
  }
}

class MessageDecompressionResult {
  final bool success;
  final String decompressedContent;
  final List<String> decompressedMediaUrls;
  final Map<String, dynamic> decompressedMetadata;
  final String? error;

  MessageDecompressionResult({
    required this.success,
    required this.decompressedContent,
    required this.decompressedMediaUrls,
    required this.decompressedMetadata,
    this.error,
  });
}

class CompressionStatistics {
  final int totalMessagesCompressed;
  final int totalBytesOriginal;
  final int totalBytesCompressed;
  final double averageCompressionRatio;
  final Duration totalCompressionTime;

  CompressionStatistics({
    required this.totalMessagesCompressed,
    required this.totalBytesOriginal,
    required this.totalBytesCompressed,
    required this.averageCompressionRatio,
    required this.totalCompressionTime,
  });

  int get totalBytesSaved => totalBytesOriginal - totalBytesCompressed;
  double get totalSavingsMB => totalBytesSaved / (1024 * 1024);
  Duration get averageCompressionTime => totalMessagesCompressed > 0 
      ? Duration(microseconds: totalCompressionTime.inMicroseconds ~/ totalMessagesCompressed)
      : Duration.zero;
}
