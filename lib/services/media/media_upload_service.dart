// Media Upload Service - Handle image and document uploads
// Part of Task 9: Build PostCreationScreen for coordinators

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'comprehensive_media_service.dart';

class MediaUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Upload configuration
  static const int maxImageSizeKB = 2048; // 2MB
  static const int maxDocumentSizeMB = 10; // 10MB
  static const int imageQuality = 85;
  static const int maxImageDimension = 1920;
  
  /// Upload multiple images with compression
  static Future<List<String>> uploadImages({
    required List<String> imagePaths,
    required String userId,
    String folder = 'posts',
    Function(int, int)? onProgress,
  }) async {
    try {
      debugPrint('MediaUploadService: Uploading ${imagePaths.length} images');
      
      final uploadedUrls = <String>[];
      
      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        onProgress?.call(i, imagePaths.length);
        
        try {
          final url = await _uploadSingleImage(
            imagePath: imagePath,
            userId: userId,
            folder: folder,
          );
          uploadedUrls.add(url);
          
          debugPrint('MediaUploadService: Image ${i + 1} uploaded successfully');
        } catch (e) {
          debugPrint('MediaUploadService: Failed to upload image ${i + 1}: $e');
          // Continue with other images
        }
      }
      
      onProgress?.call(imagePaths.length, imagePaths.length);
      return uploadedUrls;
      
    } catch (e) {
      debugPrint('MediaUploadService: Error uploading images: $e');
      rethrow;
    }
  }
  
  /// Upload multiple documents
  static Future<List<String>> uploadDocuments({
    required List<String> documentPaths,
    required String userId,
    String folder = 'documents',
    Function(int, int)? onProgress,
  }) async {
    try {
      debugPrint('MediaUploadService: Uploading ${documentPaths.length} documents');
      
      final uploadedUrls = <String>[];
      
      for (int i = 0; i < documentPaths.length; i++) {
        final documentPath = documentPaths[i];
        onProgress?.call(i, documentPaths.length);
        
        try {
          final url = await _uploadSingleDocument(
            documentPath: documentPath,
            userId: userId,
            folder: folder,
          );
          uploadedUrls.add(url);
          
          debugPrint('MediaUploadService: Document ${i + 1} uploaded successfully');
        } catch (e) {
          debugPrint('MediaUploadService: Failed to upload document ${i + 1}: $e');
          // Continue with other documents
        }
      }
      
      onProgress?.call(documentPaths.length, documentPaths.length);
      return uploadedUrls;
      
    } catch (e) {
      debugPrint('MediaUploadService: Error uploading documents: $e');
      rethrow;
    }
  }
  
  /// Upload a single image with compression
  static Future<String> _uploadSingleImage({
    required String imagePath,
    required String userId,
    required String folder,
  }) async {
    try {
      final file = File(imagePath);
      
      // Validate file exists
      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }
      
      // Compress image
      final compressedBytes = await _compressImage(file);
      
      // Generate unique filename
      final fileName = _generateFileName(imagePath, userId);
      final storageRef = _storage.ref().child('$folder/images/$fileName');
      
      // Determine proper content type based on file extension
      final extension = path.extension(imagePath).toLowerCase();
      String contentType;
      switch (extension) {
        case '.jpg':
        case '.jpeg':
          contentType = 'image/jpeg';
          break;
        case '.png':
          contentType = 'image/png';
          break;
        case '.webp':
          contentType = 'image/webp';
          break;
        default:
          contentType = 'image/jpeg'; // Default to JPEG
      }

      // Upload with enforced metadata
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalName': path.basename(imagePath),
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );

      final uploadTask = storageRef.putData(compressedBytes, metadata);
      final snapshot = await uploadTask;

      // ALWAYS get download URL - never store paths or gs:// URLs
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Validate URL format
      if (!downloadUrl.contains('firebasestorage.googleapis.com') ||
          !downloadUrl.contains('token=')) {
        throw Exception('Invalid download URL format: $downloadUrl');
      }
      
      debugPrint('MediaUploadService: Image uploaded to $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('MediaUploadService: Error uploading image: $e');
      rethrow;
    }
  }
  
  /// Upload a single document
  static Future<String> _uploadSingleDocument({
    required String documentPath,
    required String userId,
    required String folder,
  }) async {
    try {
      final file = File(documentPath);
      
      // Validate file exists
      if (!await file.exists()) {
        throw Exception('Document file not found: $documentPath');
      }
      
      // Validate file size
      final fileSizeBytes = await file.length();
      final fileSizeMB = fileSizeBytes / (1024 * 1024);
      
      if (fileSizeMB > maxDocumentSizeMB) {
        throw Exception('Document size (${fileSizeMB.toStringAsFixed(1)}MB) exceeds limit of ${maxDocumentSizeMB}MB');
      }
      
      // Generate unique filename
      final fileName = _generateFileName(documentPath, userId);
      final storageRef = _storage.ref().child('$folder/documents/$fileName');
      
      // Determine content type
      final contentType = _getContentType(documentPath);
      
      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalName': path.basename(documentPath),
          'fileSize': fileSizeBytes.toString(),
        },
      );
      
      final uploadTask = storageRef.putFile(file, metadata);
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('MediaUploadService: Document uploaded to $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('MediaUploadService: Error uploading document: $e');
      rethrow;
    }
  }
  
  /// Compress image to reduce file size
  static Future<Uint8List> _compressImage(File imageFile) async {
    try {
      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Resize if too large
      img.Image resizedImage = image;
      if (image.width > maxImageDimension || image.height > maxImageDimension) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? maxImageDimension : null,
          height: image.height > image.width ? maxImageDimension : null,
        );
      }
      
      // Encode as JPEG with quality compression
      final compressedBytes = img.encodeJpg(resizedImage, quality: imageQuality);
      
      debugPrint('MediaUploadService: Image compressed from ${imageBytes.length} to ${compressedBytes.length} bytes');
      
      return Uint8List.fromList(compressedBytes);
      
    } catch (e) {
      debugPrint('MediaUploadService: Error compressing image: $e');
      rethrow;
    }
  }
  
  /// Generate unique filename
  static String _generateFileName(String originalPath, String userId) {
    final extension = path.extension(originalPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = DateTime.now().microsecond;
    
    return '${userId}_${timestamp}_$randomSuffix$extension';
  }
  
  /// Get content type for document
  static String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.txt':
        return 'text/plain';
      case '.rtf':
        return 'application/rtf';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
  
  /// Delete uploaded file
  static Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      
      debugPrint('MediaUploadService: File deleted successfully');
    } catch (e) {
      debugPrint('MediaUploadService: Error deleting file: $e');
      // Don't rethrow - deletion failures shouldn't break the app
    }
  }
  
  /// Get file metadata
  static Future<Map<String, dynamic>?> getFileMetadata(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      final metadata = await ref.getMetadata();
      
      return {
        'name': metadata.name,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated,
        'updated': metadata.updated,
        'customMetadata': metadata.customMetadata,
      };
    } catch (e) {
      debugPrint('MediaUploadService: Error getting file metadata: $e');
      return null;
    }
  }
  
  /// Validate image file
  static Future<bool> isValidImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return false;
      
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      return image != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Validate document file
  static Future<bool> isValidDocument(String documentPath) async {
    try {
      final file = File(documentPath);
      if (!await file.exists()) return false;
      
      final extension = path.extension(documentPath).toLowerCase();
      final allowedExtensions = ['.pdf', '.doc', '.docx', '.txt', '.rtf', '.xls', '.xlsx'];
      
      if (!allowedExtensions.contains(extension)) return false;
      
      final fileSizeBytes = await file.length();
      final fileSizeMB = fileSizeBytes / (1024 * 1024);
      
      return fileSizeMB <= maxDocumentSizeMB;
    } catch (e) {
      return false;
    }
  }
  
  /// Get file size in human readable format
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

/// Upload progress callback
typedef UploadProgressCallback = void Function(int current, int total);

/// Upload result
class UploadResult {
  final List<String> successfulUploads;
  final List<String> failedUploads;
  final List<String> errors;
  
  const UploadResult({
    required this.successfulUploads,
    required this.failedUploads,
    required this.errors,
  });
  
  bool get hasErrors => failedUploads.isNotEmpty;
  bool get isSuccess => failedUploads.isEmpty;
  int get totalUploaded => successfulUploads.length;
  int get totalFailed => failedUploads.length;
}
