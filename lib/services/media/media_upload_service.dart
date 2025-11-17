// Media Upload Service for TALOWA Feed System
// Handles image and video uploads to Firebase Storage
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class MediaUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Upload image to Firebase Storage for feed posts
  static Future<String?> uploadFeedImage(XFile file, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('feed_posts').child(fileName);
      
      UploadTask uploadTask;
      
      if (kIsWeb) {
        // Web upload using bytes
        final bytes = await file.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Mobile upload using file
        uploadTask = ref.putFile(
          File(file.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('❌ Image upload failed: $e');
      return null;
    }
  }
  
  /// Upload multiple images to Firebase Storage
  static Future<List<String>> uploadMultipleImages(
    List<XFile> files,
    String userId,
  ) async {
    final urls = <String>[];
    
    for (int i = 0; i < files.length; i++) {
      try {
        final url = await uploadFeedImage(files[i], userId);
        if (url != null) {
          urls.add(url);
          debugPrint('✅ Uploaded image ${i + 1}/${files.length}');
        }
      } catch (e) {
        debugPrint('❌ Failed to upload image ${i + 1}: $e');
      }
    }
    
    return urls;
  }
  
  /// Upload video to Firebase Storage for feed posts
  static Future<String?> uploadFeedVideo(XFile file, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = _storage.ref().child('feed_posts').child(fileName);
      
      UploadTask uploadTask;
      
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'video/mp4'),
        );
      } else {
        uploadTask = ref.putFile(
          File(file.path),
          SettableMetadata(contentType: 'video/mp4'),
        );
      }
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('✅ Video uploaded successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('❌ Video upload failed: $e');
      return null;
    }
  }
  
  /// Upload story media to Firebase Storage
  static Future<String?> uploadStoryMedia(XFile file, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final extension = file.path.split('.').last;
      final ref = _storage.ref().child('stories').child('$fileName.$extension');
      
      UploadTask uploadTask;
      
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final contentType = extension == 'mp4' ? 'video/mp4' : 'image/jpeg';
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
      } else {
        uploadTask = ref.putFile(File(file.path));
      }
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('✅ Story media uploaded successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('❌ Story media upload failed: $e');
      return null;
    }
  }
  
  /// Delete media from Firebase Storage
  static Future<bool> deleteMedia(String mediaUrl) async {
    try {
      final ref = _storage.refFromURL(mediaUrl);
      await ref.delete();
      debugPrint('✅ Media deleted successfully: $mediaUrl');
      return true;
    } catch (e) {
      debugPrint('❌ Media deletion failed: $e');
      return false;
    }
  }
  
  /// Get upload progress stream
  static Stream<double> getUploadProgress(UploadTask task) {
    return task.snapshotEvents.map((snapshot) {
      return snapshot.bytesTransferred / snapshot.totalBytes;
    });
  }
}
