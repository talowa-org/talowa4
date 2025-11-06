// Enhanced Video Service for TALOWA Social Feed
// Comprehensive video upload, compression, thumbnail generation, and playback

import 'dart:io';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Video upload progress callback
typedef VideoProgressCallback = void Function(double progress);

/// Video upload result
class VideoUploadResult {
  final String downloadUrl;
  final String fileName;
  final int fileSizeBytes;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int width;
  final int height;
  final String format;
  
  const VideoUploadResult({
    required this.downloadUrl,
    required this.fileName,
    required this.fileSizeBytes,
    this.thumbnailUrl,
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.format,
  });
  
  Map<String, dynamic> toJson() => {
    'downloadUrl': downloadUrl,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'thumbnailUrl': thumbnailUrl,
    'durationSeconds': durationSeconds,
    'width': width,
    'height': height,
    'format': format,
  };
  
  factory VideoUploadResult.fromJson(Map<String, dynamic> json) => VideoUploadResult(
    downloadUrl: json['downloadUrl'],
    fileName: json['fileName'],
    fileSizeBytes: json['fileSizeBytes'],
    thumbnailUrl: json['thumbnailUrl'],
    durationSeconds: json['durationSeconds'],
    width: json['width'],
    height: json['height'],
    format: json['format'],
  );
}

/// Video compression settings
class VideoCompressionSettings {
  final int maxWidth;
  final int maxHeight;
  final int maxBitrate; // kbps
  final int maxDurationSeconds;
  final String outputFormat; // mp4, webm
  
  const VideoCompressionSettings({
    this.maxWidth = 1280,
    this.maxHeight = 720,
    this.maxBitrate = 2000,
    this.maxDurationSeconds = 300, // 5 minutes
    this.outputFormat = 'mp4',
  });
  
  static const VideoCompressionSettings lowQuality = VideoCompressionSettings(
    maxWidth: 640,
    maxHeight: 480,
    maxBitrate: 800,
  );
  
  static const VideoCompressionSettings mediumQuality = VideoCompressionSettings(
    maxWidth: 1280,
    maxHeight: 720,
    maxBitrate: 2000,
  );
  
  static const VideoCompressionSettings highQuality = VideoCompressionSettings(
    maxWidth: 1920,
    maxHeight: 1080,
    maxBitrate: 4000,
  );
}

/// Video validation result
class VideoValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int? durationSeconds;
  final int? fileSizeBytes;
  final String? format;
  
  const VideoValidationResult({
    required this.isValid,
    this.errorMessage,
    this.durationSeconds,
    this.fileSizeBytes,
    this.format,
  });
  
  factory VideoValidationResult.valid({
    required int durationSeconds,
    required int fileSizeBytes,
    required String format,
  }) => VideoValidationResult(
    isValid: true,
    durationSeconds: durationSeconds,
    fileSizeBytes: fileSizeBytes,
    format: format,
  );
  
  factory VideoValidationResult.invalid(String errorMessage) => VideoValidationResult(
    isValid: false,
    errorMessage: errorMessage,
  );
}

/// Main Video Service class
class VideoService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Configuration constants
  static const int _maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
  static const int _maxDurationSeconds = 600; // 10 minutes
  static const List<String> _allowedFormats = ['mp4', 'mov', 'avi', 'webm', '3gp'];
  
  /// Validate video file
  static VideoValidationResult validateVideoFile(File videoFile) {
    try {
      // Check file exists
      if (!videoFile.existsSync()) {
        return VideoValidationResult.invalid('Video file does not exist');
      }
      
      // Check file size
      final fileSizeBytes = videoFile.lengthSync();
      if (fileSizeBytes > _maxFileSizeBytes) {
        final sizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
        return VideoValidationResult.invalid('Video file too large: ${sizeMB}MB (max: ${_maxFileSizeBytes ~/ (1024 * 1024)}MB)');
      }
      
      // Check file extension
      final extension = path.extension(videoFile.path).toLowerCase().replaceFirst('.', '');
      if (!_allowedFormats.contains(extension)) {
        return VideoValidationResult.invalid('Unsupported video format: $extension. Allowed: ${_allowedFormats.join(', ')}');
      }
      
      // TODO: Add video metadata extraction (duration, resolution)
      // For now, return basic validation
      return VideoValidationResult.valid(
        durationSeconds: 0, // Will be extracted during processing
        fileSizeBytes: fileSizeBytes,
        format: extension,
      );
      
    } catch (e) {
      return VideoValidationResult.invalid('Error validating video: $e');
    }
  }
  
  /// Upload video with compression and thumbnail generation
  static Future<VideoUploadResult> uploadVideo({
    required File videoFile,
    required String userId,
    required String postId,
    VideoCompressionSettings compression = VideoCompressionSettings.mediumQuality,
    bool generateThumbnail = true,
    VideoProgressCallback? onProgress,
  }) async {
    try {
      // Validate file
      final validation = validateVideoFile(videoFile);
      if (!validation.isValid) {
        throw Exception(validation.errorMessage);
      }
      
      // Generate unique filename
      final fileName = _generateFileName(videoFile, userId, postId);
      final storagePath = 'posts/$postId/videos/$fileName';
      
      // TODO: Compress video (requires FFmpeg or similar)
      // For now, upload original file
      final videoBytes = await videoFile.readAsBytes();
      
      // Upload video
      final uploadTask = _storage.ref(storagePath).putData(videoBytes);
      
      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      String? thumbnailUrl;
      if (generateThumbnail) {
        thumbnailUrl = await _generateAndUploadThumbnail(
          videoFile, userId, postId, fileName
        );
      }
      
      return VideoUploadResult(
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSizeBytes: validation.fileSizeBytes!,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: validation.durationSeconds ?? 0,
        width: 1280, // TODO: Extract from video metadata
        height: 720, // TODO: Extract from video metadata
        format: validation.format!,
      );
      
    } catch (e) {
      debugPrint('Error uploading video: $e');
      rethrow;
    }
  }
  
  /// Generate unique filename for video
  static String _generateFileName(File videoFile, String userId, String postId) {
    final extension = path.extension(videoFile.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = sha256.convert(utf8.encode('$userId$postId$timestamp')).toString().substring(0, 8);
    return 'video_${timestamp}_$hash$extension';
  }
  
  /// Generate and upload video thumbnail
  static Future<String?> _generateAndUploadThumbnail(
    File videoFile, String userId, String postId, String videoFileName
  ) async {
    try {
      // TODO: Extract thumbnail from video at 1 second mark
      // This requires video processing libraries like FFmpeg
      // For now, return null - thumbnail generation will be implemented later
      
      debugPrint('Thumbnail generation not yet implemented for video: $videoFileName');
      return null;
      
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      return null;
    }
  }
  
  /// Delete video from storage
  static Future<void> deleteVideo(String videoUrl) async {
    try {
      final ref = _storage.refFromURL(videoUrl);
      await ref.delete();
      debugPrint('Video deleted successfully: $videoUrl');
    } catch (e) {
      debugPrint('Error deleting video: $e');
      rethrow;
    }
  }
  
  /// Get video metadata
  static Future<Map<String, dynamic>?> getVideoMetadata(String videoUrl) async {
    try {
      final ref = _storage.refFromURL(videoUrl);
      final metadata = await ref.getMetadata();
      
      return {
        'name': metadata.name,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated?.toIso8601String(),
        'updated': metadata.updated?.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting video metadata: $e');
      return null;
    }
  }
}

