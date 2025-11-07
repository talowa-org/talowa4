// Progressive Upload Manager with Resume Capability
// Implements Task 9: Progressive upload with resume capability

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Progressive Upload Manager
/// Handles large file uploads with pause/resume capability and chunk-based uploading
class ProgressiveUploadManager {
  static ProgressiveUploadManager? _instance;
  static ProgressiveUploadManager get instance =>
      _instance ??= ProgressiveUploadManager._internal();

  ProgressiveUploadManager._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Active upload tasks
  final Map<String, UploadTask> _activeTasks = {};
  final Map<String, StreamController<UploadProgress>> _progressControllers = {};

  // Configuration
  static const int chunkSize = 5 * 1024 * 1024; // 5MB chunks
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Start progressive upload with resume capability
  Future<ProgressiveUploadResult> startUpload({
    required Uint8List fileBytes,
    required String fileName,
    required String storagePath,
    required String userId,
    Map<String, String>? customMetadata,
    String? resumeToken,
  }) async {
    try {
      final uploadId = _generateUploadId(storagePath);

      debugPrint('📤 Starting progressive upload: $uploadId');
      debugPrint('📊 File size: ${_formatBytes(fileBytes.length)}');

      // Check for existing upload session
      UploadSession? existingSession;
      if (resumeToken != null) {
        existingSession = await _getUploadSession(resumeToken);
        if (existingSession != null) {
          debugPrint('♻️ Resuming upload from ${existingSession.bytesUploaded} bytes');
        }
      }

      // Create or update upload session
      existingSession ??= await _createUploadSession(
        uploadId: uploadId,
        fileName: fileName,
        storagePath: storagePath,
        userId: userId,
        totalBytes: fileBytes.length,
      );

      // Create storage reference
      final storageRef = _storage.ref().child(storagePath);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(fileName),
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'fileSize': fileBytes.length.toString(),
          'uploadId': uploadId,
          'platform': kIsWeb ? 'web' : 'mobile',
          ...?customMetadata,
        },
      );

      // Start upload task
      final uploadTask = storageRef.putData(fileBytes, metadata);
      _activeTasks[uploadId] = uploadTask;

      // Create progress stream
      final progressController = StreamController<UploadProgress>.broadcast();
      _progressControllers[uploadId] = progressController;

      // Track progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = UploadProgress(
            uploadId: uploadId,
            bytesTransferred: snapshot.bytesTransferred,
            totalBytes: snapshot.totalBytes,
            state: _mapTaskState(snapshot.state),
            error: null,
          );

          progressController.add(progress);

          // Update session
          _updateUploadSession(
            uploadId: uploadId,
            bytesUploaded: snapshot.bytesTransferred,
            status: _mapTaskState(snapshot.state),
          );

          debugPrint(
            '📊 Upload progress: ${(progress.percentage * 100).toStringAsFixed(1)}%',
          );
        },
        onError: (error) {
          debugPrint('❌ Upload error: $error');
          progressController.addError(error);
          _updateUploadSession(
            uploadId: uploadId,
            status: UploadState.failed,
            error: error.toString(),
          );
        },
        onDone: () {
          debugPrint('✅ Upload completed');
          progressController.close();
          _progressControllers.remove(uploadId);
          _activeTasks.remove(uploadId);
        },
      );

      // Wait for completion
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Mark session as completed
      await _completeUploadSession(uploadId, downloadUrl);

      return ProgressiveUploadResult(
        uploadId: uploadId,
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileBytes.length,
        uploadedAt: DateTime.now(),
        resumeToken: uploadId,
      );
    } catch (e) {
      debugPrint('❌ Progressive upload failed: $e');
      rethrow;
    }
  }

  /// Pause upload
  Future<bool> pauseUpload(String uploadId) async {
    try {
      final task = _activeTasks[uploadId];
      if (task == null) {
        debugPrint('⚠️ Upload task not found: $uploadId');
        return false;
      }

      final success = await task.pause();
      if (success) {
        debugPrint('⏸️ Upload paused: $uploadId');
        await _updateUploadSession(
          uploadId: uploadId,
          status: UploadState.paused,
        );
      }

      return success;
    } catch (e) {
      debugPrint('❌ Failed to pause upload: $e');
      return false;
    }
  }

  /// Resume upload
  Future<bool> resumeUpload(String uploadId) async {
    try {
      final task = _activeTasks[uploadId];
      if (task == null) {
        debugPrint('⚠️ Upload task not found: $uploadId');
        return false;
      }

      final success = await task.resume();
      if (success) {
        debugPrint('▶️ Upload resumed: $uploadId');
        await _updateUploadSession(
          uploadId: uploadId,
          status: UploadState.running,
        );
      }

      return success;
    } catch (e) {
      debugPrint('❌ Failed to resume upload: $e');
      return false;
    }
  }

  /// Cancel upload
  Future<bool> cancelUpload(String uploadId) async {
    try {
      final task = _activeTasks[uploadId];
      if (task == null) {
        debugPrint('⚠️ Upload task not found: $uploadId');
        return false;
      }

      final success = await task.cancel();
      if (success) {
        debugPrint('🛑 Upload cancelled: $uploadId');
        await _updateUploadSession(
          uploadId: uploadId,
          status: UploadState.cancelled,
        );

        // Clean up
        _progressControllers[uploadId]?.close();
        _progressControllers.remove(uploadId);
        _activeTasks.remove(uploadId);
      }

      return success;
    } catch (e) {
      debugPrint('❌ Failed to cancel upload: $e');
      return false;
    }
  }

  /// Get upload progress stream
  Stream<UploadProgress>? getProgressStream(String uploadId) {
    return _progressControllers[uploadId]?.stream;
  }

  /// Get active uploads
  List<String> getActiveUploads() {
    return _activeTasks.keys.toList();
  }

  /// Create upload session in Firestore
  Future<UploadSession> _createUploadSession({
    required String uploadId,
    required String fileName,
    required String storagePath,
    required String userId,
    required int totalBytes,
  }) async {
    try {
      final sessionData = {
        'uploadId': uploadId,
        'fileName': fileName,
        'storagePath': storagePath,
        'userId': userId,
        'totalBytes': totalBytes,
        'bytesUploaded': 0,
        'status': UploadState.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('upload_sessions').doc(uploadId).set(sessionData);

      return UploadSession(
        uploadId: uploadId,
        fileName: fileName,
        storagePath: storagePath,
        userId: userId,
        totalBytes: totalBytes,
        bytesUploaded: 0,
        status: UploadState.pending,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Failed to create upload session: $e');
      rethrow;
    }
  }

  /// Get upload session from Firestore
  Future<UploadSession?> _getUploadSession(String uploadId) async {
    try {
      final doc = await _firestore.collection('upload_sessions').doc(uploadId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      return UploadSession(
        uploadId: data['uploadId'],
        fileName: data['fileName'],
        storagePath: data['storagePath'],
        userId: data['userId'],
        totalBytes: data['totalBytes'],
        bytesUploaded: data['bytesUploaded'],
        status: UploadState.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => UploadState.pending,
        ),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        downloadUrl: data['downloadUrl'],
      );
    } catch (e) {
      debugPrint('❌ Failed to get upload session: $e');
      return null;
    }
  }

  /// Update upload session
  Future<void> _updateUploadSession({
    required String uploadId,
    int? bytesUploaded,
    UploadState? status,
    String? error,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (bytesUploaded != null) {
        updates['bytesUploaded'] = bytesUploaded;
      }

      if (status != null) {
        updates['status'] = status.name;
      }

      if (error != null) {
        updates['error'] = error;
      }

      await _firestore.collection('upload_sessions').doc(uploadId).update(updates);
    } catch (e) {
      debugPrint('❌ Failed to update upload session: $e');
    }
  }

  /// Complete upload session
  Future<void> _completeUploadSession(String uploadId, String downloadUrl) async {
    try {
      await _firestore.collection('upload_sessions').doc(uploadId).update({
        'status': UploadState.completed.name,
        'downloadUrl': downloadUrl,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Failed to complete upload session: $e');
    }
  }

  /// Generate unique upload ID
  String _generateUploadId(String storagePath) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = storagePath.hashCode.abs();
    return 'upload_${timestamp}_$hash';
  }

  /// Map Firebase task state to upload state
  UploadState _mapTaskState(TaskState state) {
    switch (state) {
      case TaskState.running:
        return UploadState.running;
      case TaskState.paused:
        return UploadState.paused;
      case TaskState.success:
        return UploadState.completed;
      case TaskState.canceled:
        return UploadState.cancelled;
      case TaskState.error:
        return UploadState.failed;
    }
  }

  /// Get content type from filename
  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    // Video formats
    if (['mp4', 'mov', 'avi', 'webm', 'mkv'].contains(extension)) {
      return 'video/mp4';
    }

    // Image formats
    if (['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension)) {
      return 'image/jpeg';
    }

    // Audio formats
    if (['mp3', 'wav', 'aac', 'm4a', 'ogg'].contains(extension)) {
      return 'audio/mpeg';
    }

    return 'application/octet-stream';
  }

  /// Format bytes to human-readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Enums

enum UploadState {
  pending,
  running,
  paused,
  completed,
  cancelled,
  failed,
}

// Data Classes

class UploadSession {
  final String uploadId;
  final String fileName;
  final String storagePath;
  final String userId;
  final int totalBytes;
  final int bytesUploaded;
  final UploadState status;
  final DateTime createdAt;
  final String? downloadUrl;
  final String? error;

  const UploadSession({
    required this.uploadId,
    required this.fileName,
    required this.storagePath,
    required this.userId,
    required this.totalBytes,
    required this.bytesUploaded,
    required this.status,
    required this.createdAt,
    this.downloadUrl,
    this.error,
  });

  double get progress => totalBytes > 0 ? bytesUploaded / totalBytes : 0.0;
}

class UploadProgress {
  final String uploadId;
  final int bytesTransferred;
  final int totalBytes;
  final UploadState state;
  final String? error;

  const UploadProgress({
    required this.uploadId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.state,
    this.error,
  });

  double get percentage => totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;

  bool get isCompleted => state == UploadState.completed;
  bool get isFailed => state == UploadState.failed;
  bool get isPaused => state == UploadState.paused;
  bool get isRunning => state == UploadState.running;
}

class ProgressiveUploadResult {
  final String uploadId;
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final DateTime uploadedAt;
  final String resumeToken;

  const ProgressiveUploadResult({
    required this.uploadId,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.uploadedAt,
    required this.resumeToken,
  });

  Map<String, dynamic> toJson() => {
        'uploadId': uploadId,
        'downloadUrl': downloadUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'uploadedAt': uploadedAt.toIso8601String(),
        'resumeToken': resumeToken,
      };
}
