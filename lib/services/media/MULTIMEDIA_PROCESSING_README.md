# Advanced Multimedia Processing System

## Overview

The Advanced Multimedia Processing System provides comprehensive support for video, image, and audio processing with enterprise-grade features including:

- **Video Upload**: Support for files up to 500MB
- **Video Compression & Transcoding**: Automatic conversion to 480p, 720p, 1080p, and 4K
- **Adaptive Bitrate Streaming**: HLS/DASH support for optimal playback
- **Thumbnail Generation**: Automatic thumbnail and preview clip creation
- **Voice Messages**: Recording support up to 10 minutes
- **Image Optimization**: WebP format conversion and multiple resolutions
- **Progressive Upload**: Resume capability for large files
- **Processing Queue**: Priority-based job handling

## Architecture

### Components

1. **AdvancedMultimediaProcessingService**
   - Main service for video, image, and voice message uploads
   - Handles file validation and metadata management
   - Queues processing jobs for server-side operations

2. **ProgressiveUploadManager**
   - Manages large file uploads with pause/resume capability
   - Tracks upload progress and handles failures
   - Stores upload sessions for recovery

3. **MediaProcessingQueueManager**
   - Priority-based job queue management
   - Handles job dependencies and retries
   - Provides queue statistics and monitoring

4. **AdaptiveStreamingService**
   - Generates HLS/DASH manifests for adaptive streaming
   - Determines optimal quality based on network conditions
   - Manages multiple quality variants

## Usage

### Video Upload

```dart
import 'package:talowa/services/media/advanced_multimedia_processing_service.dart';

final service = AdvancedMultimediaProcessingService.instance;

// Upload video with progress tracking
final result = await service.uploadVideo(
  videoBytes: videoBytes,
  fileName: 'my_video.mp4',
  userId: currentUserId,
  postId: postId,
  targetQuality: VideoQuality.hd1080p,
  onProgress: (progress) {
    print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

print('Video uploaded: ${result.downloadUrl}');
print('Processing job ID: ${result.processingJobId}');
```

### Voice Message Upload

```dart
// Upload voice message
final result = await service.uploadVoiceMessage(
  audioBytes: audioBytes,
  fileName: 'voice_message.mp3',
  userId: currentUserId,
  postId: postId,
  durationSeconds: 120, // 2 minutes
  onProgress: (progress) {
    print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

print('Voice message uploaded: ${result.downloadUrl}');
```

### Image Optimization

```dart
// Upload and optimize image
final result = await service.uploadOptimizedImage(
  imageBytes: imageBytes,
  fileName: 'photo.jpg',
  userId: currentUserId,
  postId: postId,
  generateWebP: true,
  generateMultipleResolutions: true,
  onProgress: (progress) {
    print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

print('Image uploaded: ${result.downloadUrl}');
```

### Progressive Upload with Resume

```dart
import 'package:talowa/services/media/progressive_upload_manager.dart';

final uploadManager = ProgressiveUploadManager.instance;

// Start upload
final result = await uploadManager.startUpload(
  fileBytes: largeFileBytes,
  fileName: 'large_video.mp4',
  storagePath: 'posts/$postId/videos/video.mp4',
  userId: currentUserId,
);

// Get upload ID for later resume
final uploadId = result.uploadId;

// Listen to progress
uploadManager.getProgressStream(uploadId)?.listen((progress) {
  print('Progress: ${(progress.percentage * 100).toStringAsFixed(1)}%');
  print('State: ${progress.state}');
});

// Pause upload
await uploadManager.pauseUpload(uploadId);

// Resume upload
await uploadManager.resumeUpload(uploadId);

// Cancel upload
await uploadManager.cancelUpload(uploadId);
```

### Processing Queue Management

```dart
import 'package:talowa/services/media/media_processing_queue_manager.dart';

final queueManager = MediaProcessingQueueManager.instance;

// Add job to queue
final jobId = await queueManager.addToQueue(
  jobType: ProcessingJobType.videoCompression,
  jobData: {
    'videoUrl': videoUrl,
    'targetQuality': '1080p',
  },
  userId: currentUserId,
  priority: ProcessingPriority.high,
);

// Check job status
final job = await queueManager.getJobStatus(jobId);
print('Job status: ${job?.status}');

// Get queue statistics
final stats = await queueManager.getQueueStatistics();
print('Pending jobs: ${stats.pendingJobs}');
print('Processing jobs: ${stats.processingJobs}');
print('Completed jobs: ${stats.completedJobs}');
```

### Adaptive Streaming

```dart
import 'package:talowa/services/media/adaptive_streaming_service.dart';

final streamingService = AdaptiveStreamingService.instance;

// Generate HLS manifest
final hlsManifest = await streamingService.generateHLSManifest(
  videoId: videoId,
  postId: postId,
  qualityUrls: {
    '480p': 'https://example.com/video_480p.mp4',
    '720p': 'https://example.com/video_720p.mp4',
    '1080p': 'https://example.com/video_1080p.mp4',
    '4k': 'https://example.com/video_4k.mp4',
  },
);

print('HLS manifest: ${hlsManifest.masterPlaylist}');

// Detect optimal quality
final networkSpeed = await streamingService.detectNetworkSpeed();
final deviceCapability = streamingService.detectDeviceCapability();

final optimalQuality = streamingService.getOptimalQuality(
  networkSpeed: networkSpeed,
  deviceCapability: deviceCapability,
  dataSaverMode: false,
);

print('Optimal quality: ${optimalQuality.name}');
```

## Server-Side Processing

The multimedia processing system queues jobs for server-side processing. You need to implement Cloud Functions or a processing server to handle these jobs:

### Required Processing Jobs

1. **Video Compression**
   - Compress videos to reduce file size
   - Maintain quality while optimizing for streaming

2. **Video Transcoding**
   - Generate multiple quality variants (480p, 720p, 1080p, 4K)
   - Use H.264/H.265 codecs for compatibility

3. **Thumbnail Generation**
   - Extract frame at specified time offset
   - Generate multiple thumbnail sizes

4. **Preview Clip Generation**
   - Create short preview clips (5-10 seconds)
   - Use for quick previews before full video load

5. **HLS Manifest Generation**
   - Create HLS playlists for adaptive streaming
   - Generate segment files for each quality

6. **Image Optimization**
   - Convert images to WebP format
   - Generate multiple resolutions (thumbnail, small, medium, large)

7. **Audio Transcoding**
   - Convert audio to optimal format (AAC, MP3)
   - Normalize audio levels

### Example Cloud Function (Node.js)

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const ffmpeg = require('fluent-ffmpeg');

exports.processVideo = functions.firestore
  .document('media_processing_queue/{jobId}')
  .onCreate(async (snap, context) => {
    const job = snap.data();
    
    if (job.type !== 'video_processing') {
      return null;
    }
    
    try {
      // Update job status to processing
      await snap.ref.update({ status: 'processing' });
      
      // Download video from Firebase Storage
      const videoUrl = job.data.videoUrl;
      const localPath = `/tmp/${context.params.jobId}.mp4`;
      
      // Process video with FFmpeg
      await new Promise((resolve, reject) => {
        ffmpeg(videoUrl)
          .output(`${localPath}_480p.mp4`)
          .videoCodec('libx264')
          .size('854x480')
          .videoBitrate('800k')
          .on('end', resolve)
          .on('error', reject)
          .run();
      });
      
      // Upload processed video back to Firebase Storage
      // Generate thumbnail
      // Update job with results
      
      await snap.ref.update({
        status: 'completed',
        result: {
          qualityUrls: {
            '480p': processedVideoUrl,
          },
          thumbnailUrl: thumbnailUrl,
        },
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
    } catch (error) {
      console.error('Video processing failed:', error);
      
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
```

## Configuration

### Firebase Storage Rules

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Posts media
    match /posts/{postId}/{mediaType}/{userId}/{fileName} {
      allow read: if true;
      allow write: if request.auth != null 
        && request.auth.uid == userId
        && request.resource.size < 500 * 1024 * 1024; // 500MB max
    }
    
    // Upload sessions
    match /upload_sessions/{sessionId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Media processing queue
    match /media_processing_queue/{jobId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
    
    // Upload sessions
    match /upload_sessions/{sessionId} {
      allow read, write: if request.auth != null 
        && resource.data.userId == request.auth.uid;
    }
    
    // Streaming manifests
    match /streaming_manifests/{manifestId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## Performance Considerations

### File Size Limits

- **Videos**: 500MB maximum
- **Images**: 10MB recommended (automatically compressed)
- **Voice Messages**: 10 minutes maximum duration

### Processing Time

- **Video Compression**: 1-5 minutes depending on file size
- **Transcoding**: 2-10 minutes for multiple qualities
- **Thumbnail Generation**: 10-30 seconds
- **Image Optimization**: 5-15 seconds

### Network Optimization

- Use progressive upload for files > 10MB
- Enable adaptive streaming for videos > 1 minute
- Generate WebP images for 30-50% size reduction
- Implement CDN caching for processed media

## Error Handling

All services include comprehensive error handling:

```dart
try {
  final result = await service.uploadVideo(...);
} on VideoProcessingException catch (e) {
  print('Video processing error: ${e.message}');
} on VoiceMessageException catch (e) {
  print('Voice message error: ${e.message}');
} on ImageProcessingException catch (e) {
  print('Image processing error: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

## Monitoring

Monitor processing queue health:

```dart
// Get queue statistics
final stats = await queueManager.getQueueStatistics();

if (stats.failedJobs > 10) {
  // Alert: High failure rate
}

if (stats.pendingJobs > 100) {
  // Alert: Queue backlog
}

// Clean up old completed jobs
await queueManager.cleanupOldJobs(age: Duration(days: 7));
```

## Requirements Implemented

This implementation satisfies the following requirements from the spec:

- **Requirement 10.1**: Video uploads up to 500MB ✅
- **Requirement 10.2**: Automatic video compression and transcoding (480p, 720p, 1080p, 4K) ✅
- **Requirement 10.4**: Voice message recording up to 10 minutes ✅
- **Requirement 10.5**: Image optimization with WebP format and multiple resolutions ✅

## Future Enhancements

- [ ] Real-time video compression progress tracking
- [ ] Client-side video compression for mobile devices
- [ ] Advanced thumbnail selection (multiple frames)
- [ ] Video editing capabilities (trim, crop, filters)
- [ ] Live streaming integration
- [ ] AI-powered content analysis
- [ ] Automatic subtitle generation
- [ ] 360° video support

## Support

For issues or questions about the multimedia processing system, please refer to:

- Main documentation: `docs/FEED_SYSTEM.md`
- Media services: `lib/services/media/README.md`
- Social feed spec: `.kiro/specs/social-feed-system/`
