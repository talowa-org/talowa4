// Web-Safe Image Picker Utility
// Implements fixes from talowa_social_feed_fix.md

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class WebSafeImagePicker {
  static final ImagePicker _picker = ImagePicker();
  
  /// Pick an image from gallery (web-safe)
  static Future<XFile?> pickImage() async {
    try {
      if (kIsWeb) {
        // Web requires explicit user click
        return await _picker.pickImage(source: ImageSource.gallery);
      } else {
        return await _picker.pickImage(source: ImageSource.gallery);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }
  
  /// Pick multiple images from gallery (web-safe)
  static Future<List<XFile>> pickMultipleImages() async {
    try {
      if (kIsWeb) {
        // Web requires explicit user click
        return await _picker.pickMultiImage();
      } else {
        return await _picker.pickMultiImage();
      }
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }
  
  /// Pick a video from gallery (web-safe)
  static Future<XFile?> pickVideo() async {
    try {
      if (kIsWeb) {
        // Web requires explicit user click
        return await _picker.pickVideo(source: ImageSource.gallery);
      } else {
        return await _picker.pickVideo(source: ImageSource.gallery);
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }
  
  /// Take a photo with camera (not supported on web)
  static Future<XFile?> takePhoto() async {
    if (kIsWeb) {
      debugPrint('Camera not supported on web');
      return null;
    }
    
    try {
      return await _picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }
  
  /// Record a video with camera (not supported on web)
  static Future<XFile?> recordVideo() async {
    if (kIsWeb) {
      debugPrint('Camera not supported on web');
      return null;
    }
    
    try {
      return await _picker.pickVideo(source: ImageSource.camera);
    } catch (e) {
      debugPrint('Error recording video: $e');
      return null;
    }
  }
}
