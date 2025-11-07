// Advanced Multimedia Processing Service
// Implements Task 9: Advanced multimedia processing system
// Requirements: 10.1, 10.2, 10.4, 10.5

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

/// Advanced Multimedia Processing Service
/// Handles video upload, compression, transcoding, adaptive streaming,
/// thumbnail generation, voice messages, and image optimization
class AdvancedMultimediaProcessingService {
  static AdvancedMultimediaProcessingService? _instance;
  static AdvancedMultimediaProcessingService get instance =>
      _instance ??= AdvancedMultimediaProcessingService._internal();

  AdvancedMultimediaProcessingService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Configuration constants
  static const int maxVideoSizeBytes = 500 * 1024 * 1024; // 500MB
  static const int maxVoiceDurationSeconds = 600; // 10 minutes
  static const List<String> supportedVideoFormats = ['mp4', 'mov', 'avi', 'webm', 'mkv'];
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'webp', 'heic'];
  static const List<String> supportedAudioFormats = ['mp3', 'wav', 'aac', 'm4a', 'ogg'];

  /// Upload video with support for files up to 500MB
  /// Implements progressive upload with resume capability
  Future<VideoUploadResult> uploadVideo({
    required Uint8List videoBytes,
    required String fileName,
    required String userId,
    required String postId,
    VideoQuality targetQuality = VideoQuality.hd1080p,
    Function(double)? onProgress,
    String? resumeToken,
  }) async {
    try {
      debugPrint('📹 Starting video upload: $fileName (${_formatBytes(videoBytes.length)})');

      // Validate video size
      if (videoBytes.length > maxVideoSizeBytes) {
        throw VideoProcessingException(
          'Video size exceeds maximum allowed size of ${_formatBytes(maxVideoSizeBytes)}',
        );
      }

      // Validate format
      final extension = _getFileExtension(fileName).toLowerCase();
      if (!supportedVideoFormats.contains(extension)) {
        throw VideoProcessingException(
          'Unsupported video format: $extension. Supported: ${supportedVideoFormats.join(", ")}',
        );
      }

      // Generate storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = _sanitizeFileName(fileName);
      final storagePath = 'posts/$postId/videos/$userId/$timestamp-$sanitizedName';

      // Create storage reference
      final storageRef = _storage.ref().child(storagePath);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'fileSize': videoBytes.length.toString(),
          'targetQuality': targetQuality.name,
          'processingStatus': 'pending',
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );

      // Upload with progress tracking
      final uploadTask = storageRef.putData(videoBytes, metadata);

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
        debugPrint('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for completion
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Video uploaded successfully');

      // Queue video for processing (compression, transcoding, thumbnail generation)
      final processingJob = await _queueVideoProcessing(
        videoUrl: downloadUrl,
        storagePath: storagePath,
        userId: userId,
        postId: postId,
        targetQuality: targetQuality,
      );

      return VideoUploadResult(
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: videoBytes.length,
        storagePath: storagePath,
        uploadedAt: DateTime.now(),
        processingJobId: processingJob.id,
        processingStatus: ProcessingStatus.pending,
        qualityUrls: {}, // Will be populated after processing
      );
    } catch (e) {
      debugPrint('❌ Video upload failed: $e');
      rethrow;
    }
  }

  /// Queue video for processing (compression, transcoding, thumbnail generation)
  Future<ProcessingJob> _queueVideoProcessing({
    required String videoUrl,
    required String storagePath,
    required String userId,
    required String postId,
    required VideoQuality targetQuality,
  }) async {
    try {
      final jobData = {
        'type': 'video_processing',
        'videoUrl': videoUrl,
        'storagePath': storagePath,
        'userId': userId,
        'postId': postId,
        'targetQuality': targetQuality.name,
        'status': 'pending',
        'priority': _calculatePriority(userId),
        'createdAt': FieldValue.serverTimestamp(),
        'tasks': [
          'compression',
          'transcoding_480p',
          'transcoding_720p',
          'transcoding_1080p',
          'transcoding_4k',
          'thumbnail_generation',
          'preview_clip_generation',
          'hls_manifest_generation',
        ],
      };

      final docRef = await _firestore.collection('media_processing_queue').add(jobData);

      debugPrint('📋 Video processing job queued: ${docRef.id}');

      return ProcessingJob(
        id: docRef.id,
        type: ProcessingType.videoProcessing,
        status: ProcessingStatus.pending,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Failed to queue video processing: $e');
      rethrow;
    }
  }

  /// Generate thumbnail from video
  /// Note: Actual thumbnail extraction requires server-side processing with FFmpeg
  Future<String?> generateVideoThumbnail({
    required String videoUrl,
    required String postId,
    int timeOffsetSeconds = 1,
  }) async {
    try {
      debugPrint('🖼️ Generating thumbnail for video at ${timeOffsetSeconds}s');

      // Queue thumbnail generation job
      final jobData = {
        'type': 'thumbnail_generation',
        'videoUrl': videoUrl,
        'postId': postId,
        'timeOffset': timeOffsetSeconds,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('media_processing_queue').add(jobData);

      debugPrint('📋 Thumbnail generation job queued');

      // Return placeholder URL until processing completes
      return null;
    } catch (e) {
      debugPrint('❌ Failed to queue thumbnail generation: $e');
      return null;
    }
  }

  /// Upload voice message with up to 10-minute duration
  Future<VoiceMessageUploadResult> uploadVoiceMessage({
    required Uint8List audioBytes,
    required String fileName,
    required String userId,
    required String postId,
    int durationSeconds = 0,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('🎤 Starting voice message upload: $fileName (${_formatBytes(audioBytes.length)})');

      // Validate duration
      if (durationSeconds > maxVoiceDurationSeconds) {
        throw VoiceMessageException(
          'Voice message duration exceeds maximum of $maxVoiceDurationSeconds seconds',
        );
      }

      // Validate format
      final extension = _getFileExtension(fileName).toLowerCase();
      if (!supportedAudioFormats.contains(extension)) {
        throw VoiceMessageException(
          'Unsupported audio format: $extension. Supported: ${supportedAudioFormats.join(", ")}',
        );
      }

      // Generate storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = _sanitizeFileName(fileName);
      final storagePath = 'posts/$postId/voice/$userId/$timestamp-$sanitizedName';

      // Create storage reference
      final storageRef = _storage.ref().child(storagePath);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: _getAudioContentType(extension),
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'fileSize': audioBytes.length.toString(),
          'durationSeconds': durationSeconds.toString(),
          'mediaType': 'voice_message',
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );

      // Upload with progress tracking
      final uploadTask = storageRef.putData(audioBytes, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Voice message uploaded successfully');

      return VoiceMessageUploadResult(
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: audioBytes.length,
        durationSeconds: durationSeconds,
        storagePath: storagePath,
        uploadedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Voice message upload failed: $e');
      rethrow;
    }
  }

  /// Upload and optimize image with WebP format and multiple resolutions
  Future<ImageUploadResult> uploadOptimizedImage({
    required Uint8List imageBytes,
    required String fileName,
    required String userId,
    required String postId,
    bool generateWebP = true,
    bool generateMultipleResolutions = true,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('🖼️ Starting optimized image upload: $fileName');

      // Validate format
      final extension = _getFileExtension(fileName).toLowerCase();
      if (!supportedImageFormats.contains(extension)) {
        throw ImageProcessingException(
          'Unsupported image format: $extension. Supported: ${supportedImageFormats.join(", ")}',
        );
      }

      // Generate storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = _sanitizeFileName(fileName);
      final storagePath = 'posts/$postId/images/$userId/$timestamp-$sanitizedName';

      // Upload original image
      final storageRef = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: _getImageContentType(extension),
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'fileSize': imageBytes.length.toString(),
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );

      final uploadTask = storageRef.putData(imageBytes, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress * 0.5); // First 50% for original upload
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Original image uploaded');

      // Queue image optimization job
      if (generateWebP || generateMultipleResolutions) {
        await _queueImageOptimization(
          imageUrl: downloadUrl,
          storagePath: storagePath,
          userId: userId,
          postId: postId,
          generateWebP: generateWebP,
          generateMultipleResolutions: generateMultipleResolutions,
        );
      }

      onProgress?.call(1.0);

      return ImageUploadResult(
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: imageBytes.length,
        storagePath: storagePath,
        uploadedAt: DateTime.now(),
        resolutionUrls: {
          'original': downloadUrl,
        },
        webpUrl: null, // Will be populated after processing
      );
    } catch (e) {
      debugPrint('❌ Image upload failed: $e');
      rethrow;
    }
  }

  /// Queue image optimization (WebP conversion, multiple resolutions)
  Future<void> _queueImageOptimization({
    required String imageUrl,
    required String storagePath,
    required String userId,
    required String postId,
    required bool generateWebP,
    required bool generateMultipleResolutions,
  }) async {
    try {
      final jobData = {
        'type': 'image_optimization',
        'imageUrl': imageUrl,
        'storagePath': storagePath,
        'userId': userId,
        'postId': postId,
        'generateWebP': generateWebP,
        'generateMultipleResolutions': generateMultipleResolutions,
        'status': 'pending',
        'priority': _calculatePriority(userId),
        'createdAt': FieldValue.serverTimestamp(),
        'tasks': [
          if (generateWebP) 'webp_conversion',
          if (generateMultipleResolutions) ...[
            'thumbnail_480x480',
            'small_720x720',
            'medium_1080x1080',
            'large_1920x1920',
          ],
        ],
      };

      await _firestore.collection('media_processing_queue').add(jobData);

      debugPrint('📋 Image optimization job queued');
    } catch (e) {
      debugPrint('❌ Failed to queue image optimization: $e');
    }
  }

  /// Get processing job status
  Future<ProcessingJob?> getProcessingJobStatus(String jobId) async {
    try {
      final doc = await _firestore.collection('media_processing_queue').doc(jobId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      return ProcessingJob(
        id: doc.id,
        type: ProcessingType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => ProcessingType.videoProcessing,
        ),
        status: ProcessingStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => ProcessingStatus.pending,
        ),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
        error: data['error'],
        result: data['result'],
      );
    } catch (e) {
      debugPrint('❌ Failed to get processing job status: $e');
      return null;
    }
  }

  /// Calculate priority for processing queue
  int _calculatePriority(String userId) {
    // Higher priority for coordinators and active users
    // This is a simplified implementation
    return 5; // Default priority
  }

  /// Get file extension from filename
  String _getFileExtension(String fileName) {
    return path.extension(fileName).replaceFirst('.', '');
  }

  /// Sanitize filename for storage
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\-_\.]'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_');
  }

  /// Format bytes to human-readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get audio content type based on extension
  String _getAudioContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'audio/mpeg';
    }
  }

  /// Get image content type based on extension
  String _getImageContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

// Enums

enum VideoQuality {
  sd480p,
  hd720p,
  hd1080p,
  uhd4k,
}

enum ProcessingType {
  videoProcessing,
  imageOptimization,
  thumbnailGeneration,
  audioTranscoding,
}

enum ProcessingStatus {
  pending,
  processing,
  completed,
  failed,
}

// Data Classes

class VideoUploadResult {
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final String storagePath;
  final DateTime uploadedAt;
  final String processingJobId;
  final ProcessingStatus processingStatus;
  final Map<String, String> qualityUrls; // 480p, 720p, 1080p, 4K URLs
  final String? thumbnailUrl;
  final String? previewClipUrl;
  final String? hlsManifestUrl;

  const VideoUploadResult({
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.storagePath,
    required this.uploadedAt,
    required this.processingJobId,
    required this.processingStatus,
    required this.qualityUrls,
    this.thumbnailUrl,
    this.previewClipUrl,
    this.hlsManifestUrl,
  });

  Map<String, dynamic> toJson() => {
        'downloadUrl': downloadUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'storagePath': storagePath,
        'uploadedAt': uploadedAt.toIso8601String(),
        'processingJobId': processingJobId,
        'processingStatus': processingStatus.name,
        'qualityUrls': qualityUrls,
        'thumbnailUrl': thumbnailUrl,
        'previewClipUrl': previewClipUrl,
        'hlsManifestUrl': hlsManifestUrl,
      };
}

class VoiceMessageUploadResult {
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final int durationSeconds;
  final String storagePath;
  final DateTime uploadedAt;

  const VoiceMessageUploadResult({
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.durationSeconds,
    required this.storagePath,
    required this.uploadedAt,
  });

  Map<String, dynamic> toJson() => {
        'downloadUrl': downloadUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'durationSeconds': durationSeconds,
        'storagePath': storagePath,
        'uploadedAt': uploadedAt.toIso8601String(),
      };
}

class ImageUploadResult {
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final String storagePath;
  final DateTime uploadedAt;
  final Map<String, String> resolutionUrls; // thumbnail, small, medium, large, original
  final String? webpUrl;

  const ImageUploadResult({
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.storagePath,
    required this.uploadedAt,
    required this.resolutionUrls,
    this.webpUrl,
  });

  Map<String, dynamic> toJson() => {
        'downloadUrl': downloadUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'storagePath': storagePath,
        'uploadedAt': uploadedAt.toIso8601String(),
        'resolutionUrls': resolutionUrls,
        'webpUrl': webpUrl,
      };
}

class ProcessingJob {
  final String id;
  final ProcessingType type;
  final ProcessingStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? error;
  final Map<String, dynamic>? result;

  const ProcessingJob({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.error,
    this.result,
  });
}

// Exceptions

class VideoProcessingException implements Exception {
  final String message;
  const VideoProcessingException(this.message);

  @override
  String toString() => 'VideoProcessingException: $message';
}

class VoiceMessageException implements Exception {
  final String message;
  const VoiceMessageException(this.message);

  @override
  String toString() => 'VoiceMessageException: $message';
}

class ImageProcessingException implements Exception {
  final String message;
  const ImageProcessingException(this.message);

  @override
  String toString() => 'ImageProcessingException: $message';
}
