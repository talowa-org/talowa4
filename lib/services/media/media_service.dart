// Media Service - Handle image and document uploads for social feed
// Part of Task 10: Implement media handling system

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Media upload progress callback
typedef ProgressCallback = void Function(double progress);

/// Media upload result
class MediaUploadResult {
  final String downloadUrl;
  final String fileName;
  final int fileSizeBytes;
  final String fileType;
  final String? thumbnailUrl;
  
  const MediaUploadResult({
    required this.downloadUrl,
    required this.fileName,
    required this.fileSizeBytes,
    required this.fileType,
    this.thumbnailUrl,
  });
  
  Map<String, dynamic> toJson() => {
    'downloadUrl': downloadUrl,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    'fileType': fileType,
    'thumbnailUrl': thumbnailUrl,
  };
  
  factory MediaUploadResult.fromJson(Map<String, dynamic> json) => MediaUploadResult(
    downloadUrl: json['downloadUrl'],
    fileName: json['fileName'],
    fileSizeBytes: json['fileSizeBytes'],
    fileType: json['fileType'],
    thumbnailUrl: json['thumbnailUrl'],
  );
}

/// Media compression settings
class CompressionSettings {
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final bool maintainAspectRatio;
  
  const CompressionSettings({
    this.maxWidth = 1920,
    this.maxHeight = 1080,
    this.quality = 85,
    this.maintainAspectRatio = true,
  });
  
  static const CompressionSettings thumbnail = CompressionSettings(
    maxWidth: 300,
    maxHeight: 300,
    quality = 70,
  );
  
  static const CompressionSettings preview = CompressionSettings(
    maxWidth = 800,
    maxHeight = 600,
    quality = 80,
  );
  
  static const CompressionSettings fullSize = CompressionSettings(
    maxWidth = 1920,
    maxHeight = 1080,
    quality = 85,
  );
}

/// File validation result
class FileValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? fileType;
  final int? fileSizeBytes;
  
  const FileValidationResult({
    required this.isValid,
    this.errorMessage,
    this.fileType,
    this.fileSizeBytes,
  });
  
  factory FileValidationResult.valid(String fileType, int fileSizeBytes) => 
    FileValidationResult(
      isValid: true,
      fileType: fileType,
      fileSizeBytes: fileSizeBytes,
    );
  
  factory FileValidationResult.invalid(String errorMessage) => 
    FileValidationResult(
      isValid: false,
      errorMessage: errorMessage,
    );
}

/// Media service for handling file uploads and processing
class MediaService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // File size limits (in bytes)
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxDocumentSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  
  // Allowed file types
  static const List<String> allowedImageTypes = [
    'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];
  
  static const List<String> allowedDocumentTypes = [
    'pdf', 'doc', 'docx', 'txt', 'rtf'
  ];
  
  static const List<String> allowedVideoTypes = [
    'mp4', 'mov', 'avi', 'mkv'
  ];
  
  /// Validate file before upload
  static FileValidationResult validateFile(File file) {
    try {
      final fileName = path.basename(file.path);
      final extension = path.extension(fileName).toLowerCase().replaceAll('.', '');
      final fileSize = file.lengthSync();
      
      // Check file extension
      if (!_isAllowedFileType(extension)) {
        return FileValidationResult.invalid(
          'File type .$extension is not supported. Allowed types: ${_getAllowedExtensions().join(', ')}'
        );
      }
      
      // Check file size
      final maxSize = _getMaxSizeForType(extension);
      if (fileSize > maxSize) {
        final maxSizeMB = (maxSize / (1024 * 1024)).round();
        return FileValidationResult.invalid(
          'File size ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB exceeds maximum allowed size of ${maxSizeMB}MB'
        );
      }
      
      // Additional validation for images
      if (allowedImageTypes.contains(extension)) {
        if (!_isValidImage(file)) {
          return FileValidationResult.invalid('Invalid or corrupted image file');
        }
      }
      
      return FileValidationResult.valid(_getFileType(extension), fileSize);
    } catch (e) {
      return FileValidationResult.invalid('Error validating file: $e');
    }
  }
  
  /// Upload image with compression and thumbnail generation
  static Future<MediaUploadResult> uploadImage({
    required File imageFile,
    required String userId,
    required String postId,
    CompressionSettings compression = CompressionSettings.fullSize,
    bool generateThumbnail = true,
    ProgressCallback? onProgress,
  }) async {
    try {
      // Validate file
      final validation = validateFile(imageFile);
      if (!validation.isValid) {
        throw Exception(validation.errorMessage);
      }
      
      // Compress image
      final compressedImage = await _compressImage(imageFile, compression);
      
      // Generate unique filename
      final fileName = _generateFileName(imageFile, userId, postId);
      final storagePath = 'posts/$postId/images/$fileName';
      
      // Upload compressed image
      final uploadTask = _storage.ref(storagePath).putData(compressedImage);
      
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
          imageFile, userId, postId, fileName
        );
      }
      
      return MediaUploadResult(
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSizeBytes: compressedImage.length,
        fileType: 'image',
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
  
  /// Upload document file
  static Future<MediaUploadResult> uploadDocument({
    required File documentFile,
    required String userId,
    required String postId,
    ProgressCallback? onProgress,
  }) async {
    try {
      // Validate file
      final validation = validateFile(documentFile);
      if (!validation.isValid) {
        throw Exception(validation.errorMessage);
      }
      
      // Generate unique filename
      final fileName = _generateFileName(documentFile, userId, postId);
      final storagePath = 'posts/$postId/documents/$fileName';
      
      // Upload document
      final uploadTask = _storage.ref(storagePath).putFile(documentFile);
      
      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return MediaUploadResult(
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSizeBytes: validation.fileSizeBytes!,
        fileType: 'document',
      );
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }
  
  /// Upload multiple files in batch
  static Future<List<MediaUploadResult>> uploadBatch({
    required List<File> files,
    required String userId,
    required String postId,
    CompressionSettings compression = CompressionSettings.fullSize,
    ProgressCallback? onProgress,
  }) async {
    final results = <MediaUploadResult>[];
    final totalFiles = files.length;
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final extension = path.extension(file.path).toLowerCase().replaceAll('.', '');
      
      try {
        MediaUploadResult result;
        
        if (allowedImageTypes.contains(extension)) {
          result = await uploadImage(
            imageFile: file,
            userId: userId,
            postId: postId,
            compression: compression,
            onProgress: onProgress != null ? (progress) {
              final overallProgress = (i + progress) / totalFiles;
              onProgress(overallProgress);
            } : null,
          );
        } else {
          result = await uploadDocument(
            documentFile: file,
            userId: userId,
            postId: postId,
            onProgress: onProgress != null ? (progress) {
              final overallProgress = (i + progress) / totalFiles;
              onProgress(overallProgress);
            } : null,
          );
        }
        
        results.add(result);
      } catch (e) {
        print('Failed to upload file ${file.path}: $e');
        // Continue with other files
      }
    }
    
    return results;
  }
  
  /// Delete uploaded file
  static Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      print('Failed to delete file: $e');
      // Don't throw error as file might already be deleted
    }
  }
  
  /// Get file metadata
  static Future<FullMetadata> getFileMetadata(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    return await ref.getMetadata();
  }
  
  /// Generate signed URL for temporary access
  static Future<String> generateSignedUrl(String downloadUrl, Duration expiry) async {
    final ref = _storage.refFromURL(downloadUrl);
    return await ref.getDownloadURL();
  }
  
  // Private helper methods
  
  static bool _isAllowedFileType(String extension) {
    return allowedImageTypes.contains(extension) ||
           allowedDocumentTypes.contains(extension) ||
           allowedVideoTypes.contains(extension);
  }
  
  static List<String> _getAllowedExtensions() {
    return [...allowedImageTypes, ...allowedDocumentTypes, ...allowedVideoTypes];
  }
  
  static int _getMaxSizeForType(String extension) {
    if (allowedImageTypes.contains(extension)) return maxImageSize;
    if (allowedDocumentTypes.contains(extension)) return maxDocumentSize;
    if (allowedVideoTypes.contains(extension)) return maxVideoSize;
    return maxDocumentSize; // Default
  }
  
  static String _getFileType(String extension) {
    if (allowedImageTypes.contains(extension)) return 'image';
    if (allowedDocumentTypes.contains(extension)) return 'document';
    if (allowedVideoTypes.contains(extension)) return 'video';
    return 'unknown';
  }
  
  static bool _isValidImage(File file) {
    try {
      final bytes = file.readAsBytesSync();
      final image = img.decodeImage(bytes);
      return image != null;
    } catch (e) {
      return false;
    }
  }
  
  static Future<Uint8List> _compressImage(File imageFile, CompressionSettings settings) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Invalid image format');
      }
      
      // Calculate new dimensions
      int newWidth = image.width;
      int newHeight = image.height;
      
      if (settings.maintainAspectRatio) {
        final aspectRatio = image.width / image.height;
        
        if (image.width > settings.maxWidth) {
          newWidth = settings.maxWidth;
          newHeight = (newWidth / aspectRatio).round();
        }
        
        if (newHeight > settings.maxHeight) {
          newHeight = settings.maxHeight;
          newWidth = (newHeight * aspectRatio).round();
        }
      } else {
        newWidth = settings.maxWidth.clamp(1, image.width);
        newHeight = settings.maxHeight.clamp(1, image.height);
      }
      
      // Resize image if needed
      img.Image resizedImage = image;
      if (newWidth != image.width || newHeight != image.height) {
        resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
      }
      
      // Encode with quality setting
      final compressedBytes = img.encodeJpg(resizedImage, quality: settings.quality);
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      throw Exception('Failed to compress image: $e');
    }
  }
  
  static Future<String> _generateAndUploadThumbnail(
    File imageFile, String userId, String postId, String originalFileName
  ) async {
    try {
      final thumbnailData = await _compressImage(imageFile, CompressionSettings.thumbnail);
      
      final thumbnailFileName = 'thumb_$originalFileName';
      final storagePath = 'posts/$postId/thumbnails/$thumbnailFileName';
      
      final uploadTask = _storage.ref(storagePath).putData(thumbnailData);
      final snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Failed to generate thumbnail: $e');
      return '';
    }
  }
  
  static String _generateFileName(File file, String userId, String postId) {
    final originalName = path.basenameWithoutExtension(file.path);
    final extension = path.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = sha256.convert(utf8.encode('$userId$postId$timestamp')).toString().substring(0, 8);
    
    return '${originalName}_${hash}_$timestamp$extension';
  }
}
