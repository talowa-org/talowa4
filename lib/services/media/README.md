# Media Handling System

This directory contains the complete media handling system for the TALOWA social feed, implementing Task 10 of the social feed implementation plan.

## Overview

The media handling system provides comprehensive functionality for:
- Image compression and optimization
- Document upload with progress tracking
- File type validation and size limits
- Media preview and editing tools
- Batch upload functionality
- Secure file storage with CDN
- Offline media caching

## Components

### 1. MediaService (`media_service.dart`)
Core service for handling file uploads and processing.

**Key Features:**
- File validation (type, size, integrity)
- Image compression with configurable settings
- Thumbnail generation
- Batch upload support
- Firebase Storage integration
- Progress tracking

**Usage:**
```dart
// Upload single image
final result = await MediaService.uploadImage(
  imageFile: imageFile,
  userId: 'user123',
  postId: 'post456',
  compression: CompressionSettings.fullSize,
  generateThumbnail: true,
  onProgress: (progress) => print('Progress: ${(progress * 100).toInt()}%'),
);

// Upload document
final result = await MediaService.uploadDocument(
  documentFile: documentFile,
  userId: 'user123',
  postId: 'post456',
  onProgress: (progress) => print('Progress: ${(progress * 100).toInt()}%'),
);

// Batch upload
final results = await MediaService.uploadBatch(
  files: [file1, file2, file3],
  userId: 'user123',
  postId: 'post456',
  compression: CompressionSettings.preview,
);
```

### 2. MediaPickerService (`media_picker_service.dart`)
Service for selecting files from device storage, camera, and gallery.

**Key Features:**
- Gallery image selection (single/multiple)
- Camera image capture
- Document file selection
- Permission handling
- File information extraction

**Usage:**
```dart
// Pick from gallery
final result = await MediaPickerService.pickMultipleImages(maxImages: 5);

// Pick from camera
final result = await MediaPickerService.pickImageFromCamera();

// Pick documents
final result = await MediaPickerService.pickDocuments(
  allowMultiple: true,
  maxFiles: 3,
);

// Handle result
if (result.hasFiles) {
  // Process selected files
  for (final file in result.files) {
    print('Selected: ${file.path}');
  }
} else if (result.hasError) {
  print('Error: ${result.errorMessage}');
}
```

### 3. MediaUploadManager (`media_upload_manager.dart`)
Manager for handling batch uploads with progress tracking and state management.

**Key Features:**
- Concurrent upload control
- Progress tracking per file and overall
- Upload state management
- Retry failed uploads
- Upload cancellation

**Usage:**
```dart
final uploadManager = MediaUploadManager();

// Listen to upload progress
uploadManager.uploadStream.listen((state) {
  print('Overall progress: ${(state.overallProgress * 100).toInt()}%');
  print('Completed: ${state.completedCount}/${state.files.length}');
});

// Start batch upload
final results = await uploadManager.uploadFiles(
  files: selectedFiles,
  userId: 'user123',
  postId: 'post456',
  maxConcurrentUploads: 3,
);

// Retry failed uploads
if (uploadManager.currentUpload?.hasErrors == true) {
  await uploadManager.retryFailedUploads(
    userId: 'user123',
    postId: 'post456',
  );
}
```

### 4. MediaCacheService (`media_cache_service.dart`)
Service for caching media files for offline access.

**Key Features:**
- Automatic media caching
- Cache size management
- Expiry handling
- Offline media access
- Cache statistics

**Usage:**
```dart
// Initialize cache service
await MediaCacheService.initialize();

// Cache media from URL
final localPath = await MediaCacheService.cacheMedia(
  url: 'https://example.com/image.jpg',
  expiry: Duration(days: 7),
);

// Get cached media path
final cachedPath = await MediaCacheService.getCachedMediaPath(url);

// Preload media for offline use
final cachedPaths = await MediaCacheService.preloadMedia([
  'https://example.com/image1.jpg',
  'https://example.com/image2.jpg',
]);

// Get cache statistics
final stats = await MediaCacheService.getCacheStats();
print('Cache size: ${stats['totalSizeMB']} MB');
```

## Widgets

### 1. MediaPreviewWidget (`../widgets/media/media_preview_widget.dart`)
Widget for previewing selected media files before upload.

**Features:**
- Image and document previews
- File information display
- Remove and edit actions
- Upload progress display

### 2. ComprehensiveMediaWidget (`../widgets/media/comprehensive_media_widget.dart`)
Complete media handling interface combining all functionality.

**Features:**
- File selection interface
- Preview of selected files
- Upload progress tracking
- Results display
- Error handling

**Usage:**
```dart
ComprehensiveMediaWidget(
  onMediaUploaded: (results) {
    // Handle uploaded media results
    for (final result in results) {
      print('Uploaded: ${result.downloadUrl}');
    }
  },
  userId: 'user123',
  postId: 'post456',
  maxFiles: 5,
  allowImages: true,
  allowDocuments: true,
  compressionSettings: CompressionSettings.fullSize,
  generateThumbnails: true,
)
```

## Configuration

### File Size Limits
- Images: 10MB maximum
- Documents: 10MB maximum
- Videos: 50MB maximum

### Supported File Types
- **Images:** JPG, JPEG, PNG, GIF, WebP
- **Documents:** PDF, DOC, DOCX, TXT, RTF
- **Videos:** MP4, MOV, AVI, MKV

### Compression Settings
```dart
// Predefined settings
CompressionSettings.thumbnail  // 300x300, 70% quality
CompressionSettings.preview    // 800x600, 80% quality
CompressionSettings.fullSize   // 1920x1080, 85% quality

// Custom settings
CompressionSettings(
  maxWidth: 1200,
  maxHeight: 800,
  quality: 90,
  maintainAspectRatio: true,
)
```

### Cache Configuration
- Maximum cache size: 100MB
- Default expiry: 7 days
- Automatic cleanup of expired items
- LRU eviction when size limit exceeded

## Security Features

- File type validation
- File size limits
- Malware scanning (placeholder for future implementation)
- Secure Firebase Storage rules
- Signed URLs for temporary access

## Error Handling

The system provides comprehensive error handling for:
- Network connectivity issues
- File validation failures
- Upload failures
- Permission denials
- Storage quota exceeded
- Invalid file formats

## Testing

Run tests with:
```bash
flutter test test/services/media/
```

## Dependencies

Required packages in `pubspec.yaml`:
```yaml
dependencies:
  firebase_storage: ^12.3.8
  image_picker: ^1.0.7
  file_picker: ^6.1.1
  image: ^4.1.7
  http: ^1.2.0
  path_provider: ^2.1.1
  permission_handler: ^11.0.1
  crypto: ^3.0.3
  provider: ^6.1.1
```

## Integration

To integrate the media handling system:

1. Initialize services in `main.dart`:
```dart
await MediaCacheService.initialize();
```

2. Add to your post creation screen:
```dart
ComprehensiveMediaWidget(
  onMediaUploaded: (results) {
    // Add media URLs to your post model
    setState(() {
      postImageUrls.addAll(results.map((r) => r.downloadUrl));
    });
  },
  userId: currentUser.id,
  postId: newPostId,
)
```

3. Configure Firebase Storage security rules (see `firestore.rules`)

## Performance Considerations

- Images are automatically compressed before upload
- Concurrent uploads are limited to prevent overwhelming the device
- Cache size is managed automatically
- Thumbnails are generated for faster loading
- Progress tracking is optimized for smooth UI updates

## Future Enhancements

- Image editing capabilities
- Video compression
- Advanced malware scanning
- CDN integration
- Background upload queue
- Automatic retry with exponential backoff