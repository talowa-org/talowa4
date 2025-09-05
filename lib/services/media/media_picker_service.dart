// Media Picker Service - Handle file selection for social feed
// Part of Task 10: Implement media handling system

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Media selection result
class MediaSelectionResult {
  final List<File> files;
  final String? errorMessage;
  
  const MediaSelectionResult({
    required this.files,
    this.errorMessage,
  });
  
  bool get hasFiles => files.isNotEmpty;
  bool get hasError => errorMessage != null;
  
  factory MediaSelectionResult.success(List<File> files) => 
    MediaSelectionResult(files: files);
  
  factory MediaSelectionResult.error(String message) => 
    MediaSelectionResult(files: [], errorMessage: message);
}

/// Media picker service for selecting images and documents
class MediaPickerService {
  static final ImagePicker _imagePicker = ImagePicker();
  
  /// Pick single image from gallery
  static Future<MediaSelectionResult> pickImageFromGallery() async {
    try {
      // Check permission
      final hasPermission = await _checkGalleryPermission();
      if (!hasPermission) {
        return MediaSelectionResult.error('Gallery permission denied');
      }
      
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        return MediaSelectionResult.success([]);
      }
      
      return MediaSelectionResult.success([File(pickedFile.path)]);
    } catch (e) {
      return MediaSelectionResult.error('Failed to pick image: $e');
    }
  }
  
  /// Pick single image from camera
  static Future<MediaSelectionResult> pickImageFromCamera() async {
    try {
      // Check permission
      final hasPermission = await _checkCameraPermission();
      if (!hasPermission) {
        return MediaSelectionResult.error('Camera permission denied');
      }
      
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        return MediaSelectionResult.success([]);
      }
      
      return MediaSelectionResult.success([File(pickedFile.path)]);
    } catch (e) {
      return MediaSelectionResult.error('Failed to capture image: $e');
    }
  }
  
  /// Pick multiple images from gallery
  static Future<MediaSelectionResult> pickMultipleImages({int maxImages = 5}) async {
    try {
      // Check permission
      final hasPermission = await _checkGalleryPermission();
      if (!hasPermission) {
        return MediaSelectionResult.error('Gallery permission denied');
      }
      
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFiles.isEmpty) {
        return MediaSelectionResult.success([]);
      }
      
      // Limit number of images
      final limitedFiles = pickedFiles.take(maxImages).toList();
      final files = limitedFiles.map((xFile) => File(xFile.path)).toList();
      
      String? warningMessage;
      if (pickedFiles.length > maxImages) {
        warningMessage = 'Only first $maxImages images were selected (limit: $maxImages)';
      }
      
      return MediaSelectionResult(files: files, errorMessage: warningMessage);
    } catch (e) {
      return MediaSelectionResult.error('Failed to pick images: $e');
    }
  }
  
  /// Pick document files
  static Future<MediaSelectionResult> pickDocuments({
    bool allowMultiple = false,
    int maxFiles = 3,
  }) async {
    try {
      // Check permission
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        return MediaSelectionResult.error('Storage permission denied');
      }
      
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'rtf'],
        allowMultiple: allowMultiple,
      );
      
      if (result == null || result.files.isEmpty) {
        return MediaSelectionResult.success([]);
      }
      
      // Convert to File objects and limit count
      final files = result.files
          .where((file) => file.path != null)
          .take(maxFiles)
          .map((file) => File(file.path!))
          .toList();
      
      String? warningMessage;
      if (result.files.length > maxFiles) {
        warningMessage = 'Only first $maxFiles documents were selected (limit: $maxFiles)';
      }
      
      return MediaSelectionResult(files: files, errorMessage: warningMessage);
    } catch (e) {
      return MediaSelectionResult.error('Failed to pick documents: $e');
    }
  }
  
  /// Pick any file type (images or documents)
  static Future<MediaSelectionResult> pickAnyFiles({
    bool allowMultiple = false,
    int maxFiles = 5,
  }) async {
    try {
      // Check permission
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        return MediaSelectionResult.error('Storage permission denied');
      }
      
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Images
          'jpg', 'jpeg', 'png', 'gif', 'webp',
          // Documents
          'pdf', 'doc', 'docx', 'txt', 'rtf'
        ],
        allowMultiple: allowMultiple,
      );
      
      if (result == null || result.files.isEmpty) {
        return MediaSelectionResult.success([]);
      }
      
      // Convert to File objects and limit count
      final files = result.files
          .where((file) => file.path != null)
          .take(maxFiles)
          .map((file) => File(file.path!))
          .toList();
      
      String? warningMessage;
      if (result.files.length > maxFiles) {
        warningMessage = 'Only first $maxFiles files were selected (limit: $maxFiles)';
      }
      
      return MediaSelectionResult(files: files, errorMessage: warningMessage);
    } catch (e) {
      return MediaSelectionResult.error('Failed to pick files: $e');
    }
  }
  
  /// Show image source selection dialog
  static Future<MediaSelectionResult> showImageSourceDialog() async {
    // This would typically show a dialog to choose between camera and gallery
    // For now, we'll default to gallery
    return await pickImageFromGallery();
  }
  
  /// Get file info without selecting
  static Future<Map<String, dynamic>?> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final stat = await file.stat();
      final fileName = filePath.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      
      return {
        'name': fileName,
        'path': filePath,
        'size': stat.size,
        'extension': extension,
        'modified': stat.modified,
        'type': _getFileType(extension),
      };
    } catch (e) {
      print('Error getting file info: $e');
      return null;
    }
  }
  
  /// Check if file is an image
  static bool isImageFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }
  
  /// Check if file is a document
  static bool isDocumentFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(extension);
  }

  /// Check if file is a video
  static bool isVideoFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'webm', '3gp', 'mkv', 'flv'].contains(extension);
  }

  /// Pick video from gallery
  static Future<MediaSelectionResult> pickVideoFromGallery() async {
    try {
      // Check permission
      final hasPermission = await _checkGalleryPermission();
      if (!hasPermission) {
        return MediaSelectionResult.error('Gallery permission denied');
      }

      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // 10 minute limit
      );

      if (pickedFile == null) {
        return MediaSelectionResult.success([]);
      }

      return MediaSelectionResult.success([File(pickedFile.path)]);
    } catch (e) {
      return MediaSelectionResult.error('Failed to pick video: $e');
    }
  }

  /// Pick video from camera
  static Future<MediaSelectionResult> pickVideoFromCamera() async {
    try {
      // Check permission
      final hasPermission = await _checkCameraPermission();
      if (!hasPermission) {
        return MediaSelectionResult.error('Camera permission denied');
      }

      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5), // 5 minute limit for camera
      );

      if (pickedFile == null) {
        return MediaSelectionResult.success([]);
      }

      return MediaSelectionResult.success([File(pickedFile.path)]);
    } catch (e) {
      return MediaSelectionResult.error('Failed to capture video: $e');
    }
  }

  /// Show video source selection dialog
  static Future<MediaSelectionResult> showVideoSourceDialog(BuildContext context) async {
    final String? source = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Video Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop('camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop('gallery');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (source == null) {
      return MediaSelectionResult.success([]);
    }

    switch (source) {
      case 'camera':
        return await pickVideoFromCamera();
      case 'gallery':
        return await pickVideoFromGallery();
      default:
        return MediaSelectionResult.success([]);
    }
  }
  
  /// Get human-readable file size
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  // Private helper methods
  
  static Future<bool> _checkGalleryPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isDenied) {
        final result = await Permission.photos.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true;
  }
  
  static Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }
    return status.isGranted;
  }
  
  static Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true; // iOS doesn't need explicit storage permission for file picker
  }
  
  static String _getFileType(String extension) {
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return 'image';
    } else if (['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(extension)) {
      return 'document';
    }
    return 'unknown';
  }
}
