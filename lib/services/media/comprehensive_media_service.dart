// Comprehensive Media Service - Proper upload pipeline with metadata enforcement
// Implements all requirements for proper Firebase Storage URL handling

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class ComprehensiveMediaService {
  static ComprehensiveMediaService? _instance;
  static ComprehensiveMediaService get instance => _instance ??= ComprehensiveMediaService._internal();
  
  ComprehensiveMediaService._internal();
  
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Upload media with enforced metadata and proper URL storage
  Future<MediaUploadResult> uploadMedia({
    required Uint8List fileBytes,
    required String fileName,
    required MediaType mediaType,
    required String folder,
    String? userId,
    Function(double)? onProgress,
    Map<String, String>? customMetadata,
  }) async {
    try {
      debugPrint('ðŸ“¤ Uploading ${mediaType.name}: $fileName');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = userId ?? currentUser?.uid ?? 'anonymous';
      
      // Generate storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(fileName);
      final storagePath = '$folder/$uid/$timestamp-${_sanitizeFileName(fileName)}';
      
      // Determine content type based on media type and extension
      final contentType = _getContentType(mediaType, extension);
      
      // Create storage reference
      final storageRef = _storage.ref().child(storagePath);
      
      // Set enforced metadata
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'mediaType': mediaType.name,
          'fileSize': fileBytes.length.toString(),
          'platform': kIsWeb ? 'web' : 'mobile',
          ...?customMetadata,
        },
      );
      
      // Upload with metadata
      final uploadTask = storageRef.putData(fileBytes, metadata);
      
      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });
      
      // Wait for completion
      final snapshot = await uploadTask;
      
      // ALWAYS get download URL - never store paths or gs:// URLs
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Validate URL format
      if (!_isValidFirebaseStorageUrl(downloadUrl)) {
        throw Exception('Invalid download URL format: $downloadUrl');
      }
      
      debugPrint('âœ… Media uploaded successfully');
      debugPrint('ðŸ”— Download URL: ${downloadUrl.substring(0, 100)}...');
      
      return MediaUploadResult(
        downloadUrl: downloadUrl,
        contentType: contentType,
        fileName: fileName,
        fileSize: fileBytes.length,
        storagePath: storagePath,
        uploadedAt: DateTime.now(),
        mediaType: mediaType,
      );
      
    } catch (e) {
      debugPrint('âŒ Media upload failed: $e');
      rethrow;
    }
  }
  
  /// Upload image with proper JPEG/PNG content type
  Future<MediaUploadResult> uploadImage({
    required Uint8List imageBytes,
    required String fileName,
    required String folder,
    String? userId,
    Function(double)? onProgress,
  }) async {
    final extension = _getFileExtension(fileName).toLowerCase();
    MediaType mediaType;
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        mediaType = MediaType.imageJpeg;
        break;
      case 'png':
        mediaType = MediaType.imagePng;
        break;
      case 'webp':
        mediaType = MediaType.imageWebp;
        break;
      default:
        mediaType = MediaType.imageJpeg; // Default to JPEG
    }
    
    return uploadMedia(
      fileBytes: imageBytes,
      fileName: fileName,
      mediaType: mediaType,
      folder: folder,
      userId: userId,
      onProgress: onProgress,
    );
  }
  
  /// Upload video with proper MP4 content type
  Future<MediaUploadResult> uploadVideo({
    required Uint8List videoBytes,
    required String fileName,
    required String folder,
    String? userId,
    Function(double)? onProgress,
  }) async {
    return uploadMedia(
      fileBytes: videoBytes,
      fileName: fileName,
      mediaType: MediaType.videoMp4,
      folder: folder,
      userId: userId,
      onProgress: onProgress,
    );
  }
  
  /// Store media reference in Firestore with proper structure
  Future<void> storeMediaReference({
    required String collectionPath,
    required String documentId,
    required String fieldName,
    required MediaUploadResult uploadResult,
  }) async {
    try {
      final mediaData = {
        'url': uploadResult.downloadUrl,
        'contentType': uploadResult.contentType,
        'fileName': uploadResult.fileName,
        'fileSize': uploadResult.fileSize,
        'uploadedAt': uploadResult.uploadedAt,
        'mediaType': uploadResult.mediaType.name,
      };
      
      await _firestore
          .collection(collectionPath)
          .doc(documentId)
          .update({
        fieldName: FieldValue.arrayUnion([mediaData])
      });
      
      debugPrint('âœ… Media reference stored in Firestore');
      
    } catch (e) {
      debugPrint('âŒ Failed to store media reference: $e');
      rethrow;
    }
  }
  
  /// Validate Firebase Storage URL format
  bool _isValidFirebaseStorageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Must be HTTPS
      if (uri.scheme != 'https') return false;
      
      // Must be Firebase Storage domain
      if (!uri.host.contains('firebasestorage.googleapis.com')) return false;
      
      // Must have token parameter for authentication
      if (!uri.queryParameters.containsKey('token')) return false;
      
      // Must have alt=media parameter
      if (uri.queryParameters['alt'] != 'media') return false;
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Get proper content type based on media type and extension
  String _getContentType(MediaType mediaType, String extension) {
    switch (mediaType) {
      case MediaType.imageJpeg:
        return 'image/jpeg';
      case MediaType.imagePng:
        return 'image/png';
      case MediaType.imageWebp:
        return 'image/webp';
      case MediaType.videoMp4:
        return 'video/mp4';
      case MediaType.document:
        return _getDocumentContentType(extension);
    }
  }
  
  /// Get document content type based on extension
  String _getDocumentContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
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
  
  /// Log media error with structured data
  Future<void> logMediaError({
    required String postId,
    required int mediaIndex,
    required String url,
    required String errorType,
    required String errorMessage,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final uri = Uri.parse(url);
      
      final errorData = {
        'postId': postId,
        'mediaIndex': mediaIndex,
        'url': url,
        'urlHost': uri.host,
        'errorType': errorType,
        'errorMessage': errorMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
        'userAgent': kIsWeb ? 'web_browser' : 'mobile_app',
        ...?additionalData,
      };
      
      await _firestore.collection('media_errors').add(errorData);
      
      debugPrint('ðŸ“Š Media error logged: $errorType for $url');
      
    } catch (e) {
      debugPrint('âŒ Failed to log media error: $e');
    }
  }
}

// Enums and Data Classes

enum MediaType {
  imageJpeg,
  imagePng,
  imageWebp,
  videoMp4,
  document,
}

class MediaUploadResult {
  final String downloadUrl;
  final String contentType;
  final String fileName;
  final int fileSize;
  final String storagePath;
  final DateTime uploadedAt;
  final MediaType mediaType;

  const MediaUploadResult({
    required this.downloadUrl,
    required this.contentType,
    required this.fileName,
    required this.fileSize,
    required this.storagePath,
    required this.uploadedAt,
    required this.mediaType,
  });

  Map<String, dynamic> toJson() => {
    'downloadUrl': downloadUrl,
    'contentType': contentType,
    'fileName': fileName,
    'fileSize': fileSize,
    'storagePath': storagePath,
    'uploadedAt': uploadedAt.toIso8601String(),
    'mediaType': mediaType.name,
  };

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) => MediaUploadResult(
    downloadUrl: json['downloadUrl'],
    contentType: json['contentType'],
    fileName: json['fileName'],
    fileSize: json['fileSize'],
    storagePath: json['storagePath'],
    uploadedAt: DateTime.parse(json['uploadedAt']),
    mediaType: MediaType.values.firstWhere(
      (e) => e.name == json['mediaType'],
      orElse: () => MediaType.imageJpeg,
    ),
  );
}

