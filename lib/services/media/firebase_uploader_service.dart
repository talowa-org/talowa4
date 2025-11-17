// Firebase Storage Uploader Service for TALOWA
// Handles image and video uploads to Firebase Storage
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseUploaderService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image to Firebase Storage
  Future<String?> uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String userId,
    String folder = 'feed_posts/images',
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$folder/$userId/${timestamp}_$fileName';
      final ref = _storage.ref().child(path);

      final metadata = SettableMetadata(
        contentType: _getImageMimeType(fileName),
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📤 Uploading image: $path');
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      debugPrint('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Image upload error: $e');
      return null;
    }
  }

  /// Upload video to Firebase Storage
  Future<String?> uploadVideo({
    required Uint8List bytes,
    required String fileName,
    required String userId,
    String folder = 'feed_posts/videos',
    Function(double)? onProgress,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$folder/$userId/${timestamp}_$fileName';
      final ref = _storage.ref().child(path);

      final metadata = SettableMetadata(
        contentType: _getVideoMimeType(fileName),
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📤 Uploading video: $path (${bytes.length} bytes)');
      
      final uploadTask = ref.putData(bytes, metadata);

      // Track upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('✅ Video uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Video upload error: $e');
      return null;
    }
  }

  /// Upload multiple images
  Future<List<String>> uploadMultipleImages({
    required List<Uint8List> imageBytesList,
    required List<String> fileNames,
    required String userId,
    String folder = 'feed_posts/images',
    Function(int, int)? onProgress,
  }) async {
    final urls = <String>[];
    
    for (int i = 0; i < imageBytesList.length; i++) {
      final url = await uploadImage(
        bytes: imageBytesList[i],
        fileName: fileNames[i],
        userId: userId,
        folder: folder,
      );
      
      if (url != null) {
        urls.add(url);
      }
      
      if (onProgress != null) {
        onProgress(i + 1, imageBytesList.length);
      }
    }
    
    return urls;
  }

  /// Delete file from Firebase Storage
  Future<bool> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('✅ File deleted: $downloadUrl');
      return true;
    } catch (e) {
      debugPrint('❌ File deletion error: $e');
      return false;
    }
  }

  String _getImageMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _getVideoMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }
}
