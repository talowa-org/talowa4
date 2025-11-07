// Multimedia Integration Example
// Demonstrates how to use the advanced multimedia processing system

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'advanced_multimedia_processing_service.dart';
import 'progressive_upload_manager.dart';
import 'media_processing_queue_manager.dart';
import 'adaptive_streaming_service.dart';

/// Example: Upload video with full processing pipeline
Future<void> exampleVideoUpload({
  required Uint8List videoBytes,
  required String fileName,
  required String userId,
  required String postId,
}) async {
  final service = AdvancedMultimediaProcessingService.instance;

  try {
    print('📹 Starting video upload...');

    // Upload video with progress tracking
    final result = await service.uploadVideo(
      videoBytes: videoBytes,
      fileName: fileName,
      userId: userId,
      postId: postId,
      targetQuality: VideoQuality.hd1080p,
      onProgress: (progress) {
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      },
    );

    print('✅ Video uploaded successfully!');
    print('Download URL: ${result.downloadUrl}');
    print('Processing Job ID: ${result.processingJobId}');

    // Monitor processing job
    await _monitorProcessingJob(result.processingJobId);
  } catch (e) {
    print('❌ Video upload failed: $e');
  }
}

/// Example: Upload large video with progressive upload
Future<void> exampleProgressiveVideoUpload({
  required Uint8List videoBytes,
  required String fileName,
  required String userId,
  required String postId,
}) async {
  final uploadManager = ProgressiveUploadManager.instance;

  try {
    print('📹 Starting progressive video upload...');

    final storagePath = 'posts/$postId/videos/$userId/$fileName';

    // Start upload
    final uploadFuture = uploadManager.startUpload(
      fileBytes: videoBytes,
      fileName: fileName,
      storagePath: storagePath,
      userId: userId,
    );

    // Get upload ID immediately
    // In a real app, you would store this for later resume
    final uploadId = _generateUploadId(storagePath);

    // Listen to progress
    uploadManager.getProgressStream(uploadId)?.listen(
      (progress) {
        print('Progress: ${(progress.percentage * 100).toStringAsFixed(1)}%');
        print('State: ${progress.state.name}');

        // Handle different states
        if (progress.isCompleted) {
          print('✅ Upload completed!');
        } else if (progress.isFailed) {
          print('❌ Upload failed: ${progress.error}');
        }
      },
      onError: (error) {
        print('❌ Upload error: $error');
      },
    );

    // Wait for completion
    final result = await uploadFuture;

    print('✅ Progressive upload completed!');
    print('Download URL: ${result.downloadUrl}');
    print('Resume Token: ${result.resumeToken}');
  } catch (e) {
    print('❌ Progressive upload failed: $e');
  }
}

/// Example: Upload voice message
Future<void> exampleVoiceMessageUpload({
  required Uint8List audioBytes,
  required String fileName,
  required String userId,
  required String postId,
  required int durationSeconds,
}) async {
  final service = AdvancedMultimediaProcessingService.instance;

  try {
    print('🎤 Starting voice message upload...');

    final result = await service.uploadVoiceMessage(
      audioBytes: audioBytes,
      fileName: fileName,
      userId: userId,
      postId: postId,
      durationSeconds: durationSeconds,
      onProgress: (progress) {
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      },
    );

    print('✅ Voice message uploaded successfully!');
    print('Download URL: ${result.downloadUrl}');
    print('Duration: ${result.durationSeconds} seconds');
  } catch (e) {
    print('❌ Voice message upload failed: $e');
  }
}

/// Example: Upload and optimize image
Future<void> exampleImageUpload({
  required Uint8List imageBytes,
  required String fileName,
  required String userId,
  required String postId,
}) async {
  final service = AdvancedMultimediaProcessingService.instance;

  try {
    print('🖼️ Starting image upload...');

    final result = await service.uploadOptimizedImage(
      imageBytes: imageBytes,
      fileName: fileName,
      userId: userId,
      postId: postId,
      generateWebP: true,
      generateMultipleResolutions: true,
      onProgress: (progress) {
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      },
    );

    print('✅ Image uploaded successfully!');
    print('Download URL: ${result.downloadUrl}');
    print('Resolution URLs: ${result.resolutionUrls}');
  } catch (e) {
    print('❌ Image upload failed: $e');
  }
}

/// Example: Monitor processing job
Future<void> _monitorProcessingJob(String jobId) async {
  final queueManager = MediaProcessingQueueManager.instance;

  print('📊 Monitoring processing job: $jobId');

  // Poll job status every 5 seconds
  for (var i = 0; i < 60; i++) {
    // Max 5 minutes
    await Future.delayed(const Duration(seconds: 5));

    final job = await queueManager.getJobStatus(jobId);

    if (job == null) {
      print('⚠️ Job not found');
      break;
    }

    print('Job status: ${job.status.name}');

    if (job.status == JobStatus.completed) {
      print('✅ Processing completed!');
      print('Result: ${job.result}');
      break;
    } else if (job.status == JobStatus.failed) {
      print('❌ Processing failed: ${job.error}');
      break;
    }
  }
}

/// Example: Setup adaptive streaming
Future<void> exampleSetupAdaptiveStreaming({
  required String videoId,
  required String postId,
  required Map<String, String> qualityUrls,
}) async {
  final streamingService = AdaptiveStreamingService.instance;

  try {
    print('📺 Setting up adaptive streaming...');

    // Generate HLS manifest
    final hlsManifest = await streamingService.generateHLSManifest(
      videoId: videoId,
      postId: postId,
      qualityUrls: qualityUrls,
    );

    print('✅ HLS manifest generated!');
    print('Manifest ID: ${hlsManifest.id}');

    // Generate DASH manifest
    final dashManifest = await streamingService.generateDASHManifest(
      videoId: videoId,
      postId: postId,
      qualityUrls: qualityUrls,
    );

    print('✅ DASH manifest generated!');
    print('Manifest ID: ${dashManifest.id}');

    // Determine optimal quality
    final networkSpeed = await streamingService.detectNetworkSpeed();
    final deviceCapability = streamingService.detectDeviceCapability();

    final optimalQuality = streamingService.getOptimalQuality(
      networkSpeed: networkSpeed,
      deviceCapability: deviceCapability,
      dataSaverMode: false,
    );

    print('📊 Optimal quality: ${optimalQuality.name}');
  } catch (e) {
    print('❌ Adaptive streaming setup failed: $e');
  }
}

/// Example: Get queue statistics
Future<void> exampleGetQueueStatistics() async {
  final queueManager = MediaProcessingQueueManager.instance;

  try {
    print('📊 Getting queue statistics...');

    final stats = await queueManager.getQueueStatistics();

    print('Queue Statistics:');
    print('  Pending jobs: ${stats.pendingJobs}');
    print('  Processing jobs: ${stats.processingJobs}');
    print('  Completed jobs: ${stats.completedJobs}');
    print('  Failed jobs: ${stats.failedJobs}');
    print('  Total jobs: ${stats.totalJobs}');
  } catch (e) {
    print('❌ Failed to get queue statistics: $e');
  }
}

/// Example: Pause and resume upload
Future<void> examplePauseResumeUpload({
  required String uploadId,
}) async {
  final uploadManager = ProgressiveUploadManager.instance;

  try {
    print('⏸️ Pausing upload...');
    final paused = await uploadManager.pauseUpload(uploadId);

    if (paused) {
      print('✅ Upload paused successfully');

      // Wait a bit
      await Future.delayed(const Duration(seconds: 5));

      print('▶️ Resuming upload...');
      final resumed = await uploadManager.resumeUpload(uploadId);

      if (resumed) {
        print('✅ Upload resumed successfully');
      } else {
        print('❌ Failed to resume upload');
      }
    } else {
      print('❌ Failed to pause upload');
    }
  } catch (e) {
    print('❌ Pause/resume failed: $e');
  }
}

/// Example: Complete multimedia post creation
Future<Map<String, dynamic>> exampleCreateMultimediaPost({
  required String userId,
  required String postId,
  required String content,
  List<Uint8List>? images,
  Uint8List? video,
  Uint8List? voiceMessage,
  int? voiceDuration,
}) async {
  final service = AdvancedMultimediaProcessingService.instance;

  try {
    print('📝 Creating multimedia post...');

    final mediaUrls = <String, dynamic>{};

    // Upload images
    if (images != null && images.isNotEmpty) {
      print('🖼️ Uploading ${images.length} images...');
      final imageUrls = <String>[];

      for (var i = 0; i < images.length; i++) {
        final result = await service.uploadOptimizedImage(
          imageBytes: images[i],
          fileName: 'image_$i.jpg',
          userId: userId,
          postId: postId,
          generateWebP: true,
          generateMultipleResolutions: true,
        );

        imageUrls.add(result.downloadUrl);
      }

      mediaUrls['images'] = imageUrls;
      print('✅ ${imageUrls.length} images uploaded');
    }

    // Upload video
    if (video != null) {
      print('📹 Uploading video...');
      final result = await service.uploadVideo(
        videoBytes: video,
        fileName: 'video.mp4',
        userId: userId,
        postId: postId,
        targetQuality: VideoQuality.hd1080p,
      );

      mediaUrls['video'] = {
        'url': result.downloadUrl,
        'processingJobId': result.processingJobId,
      };
      print('✅ Video uploaded');
    }

    // Upload voice message
    if (voiceMessage != null && voiceDuration != null) {
      print('🎤 Uploading voice message...');
      final result = await service.uploadVoiceMessage(
        audioBytes: voiceMessage,
        fileName: 'voice.mp3',
        userId: userId,
        postId: postId,
        durationSeconds: voiceDuration,
      );

      mediaUrls['voiceMessage'] = {
        'url': result.downloadUrl,
        'duration': result.durationSeconds,
      };
      print('✅ Voice message uploaded');
    }

    print('✅ Multimedia post created successfully!');

    return {
      'postId': postId,
      'content': content,
      'media': mediaUrls,
      'createdAt': DateTime.now().toIso8601String(),
    };
  } catch (e) {
    print('❌ Failed to create multimedia post: $e');
    rethrow;
  }
}

/// Helper: Generate upload ID
String _generateUploadId(String storagePath) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final hash = storagePath.hashCode.abs();
  return 'upload_${timestamp}_$hash';
}

/// Example Widget: Video Upload with Progress
class VideoUploadWidget extends StatefulWidget {
  final Uint8List videoBytes;
  final String fileName;
  final String userId;
  final String postId;

  const VideoUploadWidget({
    super.key,
    required this.videoBytes,
    required this.fileName,
    required this.userId,
    required this.postId,
  });

  @override
  State<VideoUploadWidget> createState() => _VideoUploadWidgetState();
}

class _VideoUploadWidgetState extends State<VideoUploadWidget> {
  double _uploadProgress = 0.0;
  String _status = 'Ready to upload';
  bool _isUploading = false;

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _status = 'Uploading...';
    });

    try {
      final service = AdvancedMultimediaProcessingService.instance;

      final result = await service.uploadVideo(
        videoBytes: widget.videoBytes,
        fileName: widget.fileName,
        userId: widget.userId,
        postId: widget.postId,
        targetQuality: VideoQuality.hd1080p,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
            _status = 'Uploading: ${(progress * 100).toStringAsFixed(1)}%';
          });
        },
      );

      setState(() {
        _isUploading = false;
        _status = 'Upload complete! Processing video...';
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _status = 'Upload failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Upload',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('File: ${widget.fileName}'),
            Text('Size: ${_formatBytes(widget.videoBytes.length)}'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isUploading ? null : _startUpload,
              child: Text(_isUploading ? 'Uploading...' : 'Start Upload'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
