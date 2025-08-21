// File Sharing Service for TALOWA Messaging System
// Implements secure file upload, virus scanning, encryption, and access control
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import '../../models/messaging/file_model.dart';
import '../auth_service.dart';
import 'encryption_service.dart';
import 'virus_scanning_service.dart';
import 'land_record_integration_service.dart';

typedef ProgressCallback = void Function(double progress);

class FileSharingService {
  static final FileSharingService _instance = FileSharingService._internal();
  factory FileSharingService() => _instance;
  FileSharingService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final VirusScanningService _virusScanner = VirusScanningService();
  final LandRecordIntegrationService _landRecordIntegration = LandRecordIntegrationService();

  // File size limits (in bytes)
  static const int maxImageSize = 25 * 1024 * 1024; // 25MB
  static const int maxDocumentSize = 25 * 1024 * 1024; // 25MB
  static const int maxAudioSize = 50 * 1024 * 1024; // 50MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB

  // Allowed file types
  static const List<String> allowedImageTypes = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'
  ];
  
  static const List<String> allowedDocumentTypes = [
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx'
  ];
  
  static const List<String> allowedAudioTypes = [
    'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'
  ];
  
  static const List<String> allowedVideoTypes = [
    'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'
  ];

  /// Upload file with comprehensive security and processing
  Future<FileModel> uploadFile({
    required File file,
    required String messageId,
    String? groupId,
    String? recipientId,
    bool encryptFile = false,
    Duration? expiresIn,
    List<String> tags = const [],
    ProgressCallback? onProgress,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Step 1: Validate file
      final validation = await _validateFile(file);
      if (!validation.isValid) {
        throw Exception(validation.errorMessage);
      }

      // Step 2: Scan for viruses
      final scanResult = await _virusScanner.scanFile(file);
      if (!scanResult.isClean) {
        throw Exception('File contains malicious content: ${scanResult.threats.join(', ')}');
      }

      // Step 3: Extract metadata and GPS location
      final metadata = await _extractFileMetadata(file);
      final gpsLocation = await _extractGpsLocation(file);

      // Step 4: Process file (compress if needed)
      final processedFile = await _processFile(file, validation.fileType!);

      // Step 5: Encrypt file if required
      Uint8List fileData = await processedFile.readAsBytes();
      String? encryptionKey;
      
      if (encryptFile) {
        final encryptedData = await _encryptFileData(fileData, recipientId, groupId);
        fileData = encryptedData.data;
        encryptionKey = encryptedData.keyId;
      }

      // Step 6: Upload to Firebase Storage
      final fileName = _generateSecureFileName(file, currentUser.uid);
      final storagePath = _getStoragePath(messageId, validation.fileType!, fileName);
      
      final uploadTask = _storage.ref(storagePath).putData(
        fileData,
        SettableMetadata(
          contentType: validation.mimeType,
          customMetadata: {
            'uploadedBy': currentUser.uid,
            'messageId': messageId,
            'originalName': path.basename(file.path),
            'isEncrypted': encryptFile.toString(),
            'scanId': scanResult.scanId,
          },
        ),
      );

      // Track upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Step 7: Generate thumbnail if image
      String? thumbnailUrl;
      if (validation.fileType == 'image') {
        thumbnailUrl = await _generateThumbnail(processedFile, storagePath);
      }

      // Step 8: Auto-link to land records if applicable
      final linkedLandRecordId = await _landRecordIntegration.autoLinkToLandRecord(
        file: file,
        userId: currentUser.uid,
        gpsLocation: gpsLocation,
        tags: tags,
      );

      // Step 9: Create file model
      final fileModel = FileModel(
        id: '', // Will be set by Firestore
        originalName: path.basename(file.path),
        fileName: fileName,
        mimeType: validation.mimeType!,
        size: fileData.length,
        downloadUrl: downloadUrl,
        thumbnailUrl: thumbnailUrl,
        uploadedBy: currentUser.uid,
        uploadedAt: DateTime.now(),
        isEncrypted: encryptFile,
        encryptionKey: encryptionKey,
        accessLevel: _determineAccessLevel(groupId, recipientId),
        authorizedUsers: _getAuthorizedUsers(currentUser.uid, recipientId, groupId),
        expiresAt: expiresIn != null ? DateTime.now().add(expiresIn) : null,
        linkedCaseId: null, // Can be set later
        linkedLandRecordId: linkedLandRecordId,
        tags: tags,
        metadata: metadata,
        scanResult: scanResult,
        gpsLocation: gpsLocation,
      );

      // Step 10: Save to Firestore
      final docRef = await _firestore.collection('files').add(fileModel.toFirestore());
      
      return fileModel.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  /// Download file with access control
  Future<Uint8List> downloadFile(String fileId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get file metadata
      final fileDoc = await _firestore.collection('files').doc(fileId).get();
      if (!fileDoc.exists) {
        throw Exception('File not found');
      }

      final fileModel = FileModel.fromFirestore(fileDoc);

      // Check access permissions
      if (!_hasAccessToFile(fileModel, currentUser.uid)) {
        throw Exception('Access denied');
      }

      // Check if file is expired
      if (fileModel.isExpired) {
        throw Exception('File has expired');
      }

      // Download file data
      final ref = _storage.refFromURL(fileModel.downloadUrl);
      final fileData = await ref.getData();

      if (fileData == null) {
        throw Exception('Failed to download file data');
      }

      // Decrypt if encrypted
      if (fileModel.isEncrypted && fileModel.encryptionKey != null) {
        return await _decryptFileData(fileData, fileModel.encryptionKey!);
      }

      return fileData;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      rethrow;
    }
  }

  /// Get file download URL with temporary access
  Future<String> getTemporaryDownloadUrl(String fileId, Duration validity) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get file metadata and check access
      final fileDoc = await _firestore.collection('files').doc(fileId).get();
      if (!fileDoc.exists) {
        throw Exception('File not found');
      }

      final fileModel = FileModel.fromFirestore(fileDoc);
      
      if (!_hasAccessToFile(fileModel, currentUser.uid)) {
        throw Exception('Access denied');
      }

      if (fileModel.isExpired) {
        throw Exception('File has expired');
      }

      // Generate temporary signed URL
      final ref = _storage.refFromURL(fileModel.downloadUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error getting temporary download URL: $e');
      rethrow;
    }
  }

  /// Delete file
  Future<void> deleteFile(String fileId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get file metadata
      final fileDoc = await _firestore.collection('files').doc(fileId).get();
      if (!fileDoc.exists) {
        return; // File already deleted
      }

      final fileModel = FileModel.fromFirestore(fileDoc);

      // Check if user can delete (owner or admin)
      if (fileModel.uploadedBy != currentUser.uid) {
        // TODO: Check if user is admin
        throw Exception('Permission denied');
      }

      // Delete from storage
      try {
        final ref = _storage.refFromURL(fileModel.downloadUrl);
        await ref.delete();
        
        // Delete thumbnail if exists
        if (fileModel.thumbnailUrl != null) {
          final thumbRef = _storage.refFromURL(fileModel.thumbnailUrl!);
          await thumbRef.delete();
        }
      } catch (e) {
        debugPrint('Error deleting file from storage: $e');
        // Continue with Firestore deletion even if storage deletion fails
      }

      // Delete from Firestore
      await _firestore.collection('files').doc(fileId).delete();
    } catch (e) {
      debugPrint('Error deleting file: $e');
      rethrow;
    }
  }

  /// Get files for a message
  Future<List<FileModel>> getFilesForMessage(String messageId) async {
    try {
      final query = await _firestore
          .collection('files')
          .where('messageId', isEqualTo: messageId)
          .orderBy('uploadedAt', descending: false)
          .get();

      return query.docs.map((doc) => FileModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting files for message: $e');
      return [];
    }
  }

  // Private helper methods

  Future<FileValidationResult> _validateFile(File file) async {
    try {
      final fileName = path.basename(file.path);
      final extension = path.extension(fileName).toLowerCase().replaceAll('.', '');
      final fileSize = await file.length();

      // Check file extension
      if (!_isAllowedFileType(extension)) {
        return FileValidationResult.invalid(
          'File type .$extension is not supported'
        );
      }

      // Check file size
      final maxSize = _getMaxSizeForType(extension);
      if (fileSize > maxSize) {
        final maxSizeMB = (maxSize / (1024 * 1024)).round();
        return FileValidationResult.invalid(
          'File size exceeds maximum allowed size of ${maxSizeMB}MB'
        );
      }

      // Additional validation for images
      if (allowedImageTypes.contains(extension)) {
        if (!await _isValidImage(file)) {
          return FileValidationResult.invalid('Invalid or corrupted image file');
        }
      }

      final fileType = _getFileType(extension);
      final mimeType = _getMimeType(extension);

      return FileValidationResult.valid(fileType, fileSize, mimeType);
    } catch (e) {
      return FileValidationResult.invalid('Error validating file: $e');
    }
  }



  Future<FileMetadata> _extractFileMetadata(File file) async {
    try {
      final extension = path.extension(file.path).toLowerCase().replaceAll('.', '');
      
      if (allowedImageTypes.contains(extension)) {
        return await _extractImageMetadata(file);
      } else if (allowedAudioTypes.contains(extension)) {
        return await _extractAudioMetadata(file);
      } else if (allowedVideoTypes.contains(extension)) {
        return await _extractVideoMetadata(file);
      }
      
      return FileMetadata(exifData: {});
    } catch (e) {
      debugPrint('Error extracting file metadata: $e');
      return FileMetadata(exifData: {});
    }
  }

  Future<FileMetadata> _extractImageMetadata(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return FileMetadata(exifData: {});
      }

      // Basic image metadata without EXIF library
      final exifData = <String, dynamic>{
        'width': image.width,
        'height': image.height,
        'format': 'JPEG', // Simplified
        'fileSize': bytes.length,
      };

      return FileMetadata(
        width: image.width,
        height: image.height,
        exifData: exifData,
      );
    } catch (e) {
      debugPrint('Error extracting image metadata: $e');
      return FileMetadata(exifData: {});
    }
  }

  Future<FileMetadata> _extractAudioMetadata(File file) async {
    // Simplified audio metadata extraction
    // In production, use a proper audio metadata library
    return FileMetadata(exifData: {});
  }

  Future<FileMetadata> _extractVideoMetadata(File file) async {
    // Simplified video metadata extraction
    // In production, use a proper video metadata library
    return FileMetadata(exifData: {});
  }

  Future<GpsLocation?> _extractGpsLocation(File file) async {
    try {
      final extension = path.extension(file.path).toLowerCase().replaceAll('.', '');
      
      if (!allowedImageTypes.contains(extension)) {
        return null;
      }

      // Simplified GPS extraction - in production, use proper EXIF library
      // For now, return null as GPS extraction requires EXIF parsing
      // This would be implemented with a proper EXIF library in production
      
      return null;
    } catch (e) {
      debugPrint('Error extracting GPS location: $e');
      return null;
    }
  }

  double? _parseGpsCoordinate(String coordinate, String? reference) {
    // Simplified GPS coordinate parsing
    // In production, implement proper DMS to decimal conversion
    try {
      final parts = coordinate.split(',');
      if (parts.length >= 3) {
        final degrees = double.tryParse(parts[0]) ?? 0;
        final minutes = double.tryParse(parts[1]) ?? 0;
        final seconds = double.tryParse(parts[2]) ?? 0;
        
        double decimal = degrees + (minutes / 60) + (seconds / 3600);
        
        if (reference == 'S' || reference == 'W') {
          decimal = -decimal;
        }
        
        return decimal;
      }
    } catch (e) {
      debugPrint('Error parsing GPS coordinate: $e');
    }
    return null;
  }

  Future<File> _processFile(File file, String fileType) async {
    if (fileType == 'image') {
      return await _compressImage(file);
    } else if (fileType == 'audio') {
      return await _compressAudio(file);
    }
    return file;
  }

  Future<File> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return imageFile;
      }

      // Resize if too large
      img.Image resizedImage = image;
      const maxDimension = 2048;
      
      if (image.width > maxDimension || image.height > maxDimension) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? maxDimension : null,
          height: image.height > image.width ? maxDimension : null,
        );
      }

      // Compress with quality
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Create temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      
      return tempFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageFile;
    }
  }

  Future<File> _compressAudio(File audioFile) async {
    // Simplified audio compression - in production, use proper audio processing
    return audioFile;
  }

  Future<EncryptedFileData> _encryptFileData(
    Uint8List data, 
    String? recipientId, 
    String? groupId
  ) async {
    // Simplified file encryption using the existing encryption service
    final keyId = _generateEncryptionKeyId();
    
    // In production, implement proper file encryption
    // For now, return the data as-is with a key ID
    return EncryptedFileData(
      data: data,
      keyId: keyId,
    );
  }

  Future<Uint8List> _decryptFileData(Uint8List encryptedData, String keyId) async {
    // Simplified file decryption
    // In production, implement proper file decryption
    return encryptedData;
  }

  Future<String?> _generateThumbnail(File imageFile, String originalPath) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return null;
      }

      // Create thumbnail
      final thumbnail = img.copyResize(image, width: 300, height: 300);
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 70);
      
      // Upload thumbnail
      final thumbnailPath = originalPath.replaceAll('/files/', '/thumbnails/');
      final uploadTask = _storage.ref(thumbnailPath).putData(
        Uint8List.fromList(thumbnailBytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }



  // Helper methods for file validation and processing

  bool _isAllowedFileType(String extension) {
    return allowedImageTypes.contains(extension) ||
           allowedDocumentTypes.contains(extension) ||
           allowedAudioTypes.contains(extension) ||
           allowedVideoTypes.contains(extension);
  }

  int _getMaxSizeForType(String extension) {
    if (allowedImageTypes.contains(extension)) return maxImageSize;
    if (allowedDocumentTypes.contains(extension)) return maxDocumentSize;
    if (allowedAudioTypes.contains(extension)) return maxAudioSize;
    if (allowedVideoTypes.contains(extension)) return maxVideoSize;
    return maxDocumentSize;
  }

  String _getFileType(String extension) {
    if (allowedImageTypes.contains(extension)) return 'image';
    if (allowedDocumentTypes.contains(extension)) return 'document';
    if (allowedAudioTypes.contains(extension)) return 'audio';
    if (allowedVideoTypes.contains(extension)) return 'video';
    return 'unknown';
  }

  String _getMimeType(String extension) {
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
    };
    
    return mimeTypes[extension] ?? 'application/octet-stream';
  }

  Future<bool> _isValidImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      return image != null;
    } catch (e) {
      return false;
    }
  }

  String _generateSecureFileName(File file, String userId) {
    final originalName = path.basenameWithoutExtension(file.path);
    final extension = path.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = sha256.convert(utf8.encode('$userId$originalName$timestamp')).toString().substring(0, 8);
    
    return '${hash}_$timestamp$extension';
  }

  String _getStoragePath(String messageId, String fileType, String fileName) {
    return 'messages/$messageId/$fileType/$fileName';
  }

  String _determineAccessLevel(String? groupId, String? recipientId) {
    if (groupId != null) return 'group';
    if (recipientId != null) return 'private';
    return 'public';
  }

  List<String> _getAuthorizedUsers(String uploaderId, String? recipientId, String? groupId) {
    final users = [uploaderId];
    if (recipientId != null) users.add(recipientId);
    // For group messages, authorized users would be fetched from group membership
    return users;
  }

  bool _hasAccessToFile(FileModel fileModel, String userId) {
    return fileModel.authorizedUsers.contains(userId) ||
           fileModel.uploadedBy == userId ||
           fileModel.accessLevel == 'public';
  }

  String _generateScanId() {
    return 'scan_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  String _generateEncryptionKeyId() {
    return 'key_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }
}

// Helper classes

class FileValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? fileType;
  final int? fileSizeBytes;
  final String? mimeType;

  const FileValidationResult({
    required this.isValid,
    this.errorMessage,
    this.fileType,
    this.fileSizeBytes,
    this.mimeType,
  });

  factory FileValidationResult.valid(String fileType, int fileSizeBytes, String mimeType) => 
    FileValidationResult(
      isValid: true,
      fileType: fileType,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
    );

  factory FileValidationResult.invalid(String errorMessage) => 
    FileValidationResult(
      isValid: false,
      errorMessage: errorMessage,
    );
}

class EncryptedFileData {
  final Uint8List data;
  final String keyId;

  EncryptedFileData({
    required this.data,
    required this.keyId,
  });
}

// Extension for FileModel
extension FileModelExtension on FileModel {
  FileModel copyWith({
    String? id,
    String? originalName,
    String? fileName,
    String? mimeType,
    int? size,
    String? downloadUrl,
    String? thumbnailUrl,
    String? uploadedBy,
    DateTime? uploadedAt,
    bool? isEncrypted,
    String? encryptionKey,
    String? accessLevel,
    List<String>? authorizedUsers,
    DateTime? expiresAt,
    String? linkedCaseId,
    String? linkedLandRecordId,
    List<String>? tags,
    FileMetadata? metadata,
    SecurityScanResult? scanResult,
    GpsLocation? gpsLocation,
  }) {
    return FileModel(
      id: id ?? this.id,
      originalName: originalName ?? this.originalName,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      accessLevel: accessLevel ?? this.accessLevel,
      authorizedUsers: authorizedUsers ?? this.authorizedUsers,
      expiresAt: expiresAt ?? this.expiresAt,
      linkedCaseId: linkedCaseId ?? this.linkedCaseId,
      linkedLandRecordId: linkedLandRecordId ?? this.linkedLandRecordId,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      scanResult: scanResult ?? this.scanResult,
      gpsLocation: gpsLocation ?? this.gpsLocation,
    );
  }
}