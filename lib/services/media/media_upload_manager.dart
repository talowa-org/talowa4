// Media Upload Manager - Handle batch uploads with progress tracking
// Part of Task 10: Implement media handling system

import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'media_service.dart';

/// Upload status for individual files
enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
}

/// Individual file upload state
class FileUploadState {
  final File file;
  final String fileName;
  UploadStatus status;
  double progress;
  String? errorMessage;
  MediaUploadResult? result;
  
  FileUploadState({
    required this.file,
    required this.fileName,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.result,
  });
  
  FileUploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    MediaUploadResult? result,
  }) {
    return FileUploadState(
      file: file,
      fileName: fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      result: result ?? this.result,
    );
  }
}

/// Batch upload state
class BatchUploadState {
  final List<FileUploadState> files;
  final double overallProgress;
  final bool isCompleted;
  final bool hasErrors;
  final int completedCount;
  final int failedCount;
  
  BatchUploadState({
    required this.files,
    required this.overallProgress,
    required this.isCompleted,
    required this.hasErrors,
    required this.completedCount,
    required this.failedCount,
  });
  
  factory BatchUploadState.initial(List<File> files) {
    final fileStates = files.map((file) => FileUploadState(
      file: file,
      fileName: file.path.split('/').last,
    )).toList();
    
    return BatchUploadState(
      files: fileStates,
      overallProgress: 0.0,
      isCompleted: false,
      hasErrors: false,
      completedCount: 0,
      failedCount: 0,
    );
  }
  
  BatchUploadState copyWith({
    List<FileUploadState>? files,
    double? overallProgress,
    bool? isCompleted,
    bool? hasErrors,
    int? completedCount,
    int? failedCount,
  }) {
    return BatchUploadState(
      files: files ?? this.files,
      overallProgress: overallProgress ?? this.overallProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      hasErrors: hasErrors ?? this.hasErrors,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

/// Media upload manager for handling batch uploads
class MediaUploadManager extends ChangeNotifier {
  BatchUploadState? _currentUpload;
  final StreamController<BatchUploadState> _stateController = StreamController<BatchUploadState>.broadcast();
  
  BatchUploadState? get currentUpload => _currentUpload;
  Stream<BatchUploadState> get uploadStream => _stateController.stream;
  bool get isUploading => _currentUpload != null && !_currentUpload!.isCompleted;
  
  /// Start batch upload
  Future<List<MediaUploadResult>> uploadFiles({
    required List<File> files,
    required String userId,
    required String postId,
    CompressionSettings compression = CompressionSettings.fullSize,
    bool generateThumbnails = true,
    int maxConcurrentUploads = 3,
  }) async {
    if (files.isEmpty) return [];
    
    // Initialize upload state
    _currentUpload = BatchUploadState.initial(files);
    _notifyStateChange();
    
    final results = <MediaUploadResult>[];
    final semaphore = Semaphore(maxConcurrentUploads);
    
    try {
      // Upload files with concurrency control
      final futures = files.asMap().entries.map((entry) {
        final index = entry.key;
        final file = entry.value;
        
        return semaphore.acquire().then((_) async {
          try {
            final result = await _uploadSingleFile(
              file: file,
              index: index,
              userId: userId,
              postId: postId,
              compression: compression,
              generateThumbnails: generateThumbnails,
            );
            return result;
          } finally {
            semaphore.release();
          }
        });
      });
      
      // Wait for all uploads to complete
      final uploadResults = await Future.wait(futures);
      
      // Filter out null results (failed uploads)
      results.addAll(uploadResults.where((result) => result != null).cast<MediaUploadResult>());
      
      // Mark upload as completed
      _markUploadCompleted();
      
    } catch (e) {
      _markUploadFailed('Batch upload failed: $e');
    }
    
    return results;
  }
  
  /// Upload single file with progress tracking
  Future<MediaUploadResult?> _uploadSingleFile({
    required File file,
    required int index,
    required String userId,
    required String postId,
    required CompressionSettings compression,
    required bool generateThumbnails,
  }) async {
    try {
      // Mark file as uploading
      _updateFileState(index, status: UploadStatus.uploading);
      
      // Determine file type and upload accordingly
      final extension = file.path.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
      
      MediaUploadResult result;
      
      if (isImage) {
        result = await MediaService.uploadImage(
          imageFile: file,
          userId: userId,
          postId: postId,
          compression: compression,
          generateThumbnail: generateThumbnails,
          onProgress: (progress) {
            _updateFileState(index, progress: progress);
          },
        );
      } else {
        result = await MediaService.uploadDocument(
          documentFile: file,
          userId: userId,
          postId: postId,
          onProgress: (progress) {
            _updateFileState(index, progress: progress);
          },
        );
      }
      
      // Mark file as completed
      _updateFileState(
        index,
        status: UploadStatus.completed,
        progress: 1.0,
        result: result,
      );
      
      return result;
    } catch (e) {
      // Mark file as failed
      _updateFileState(
        index,
        status: UploadStatus.failed,
        errorMessage: e.toString(),
      );
      
      return null;
    }
  }
  
  /// Update individual file state
  void _updateFileState(
    int index, {
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    MediaUploadResult? result,
  }) {
    if (_currentUpload == null || index >= _currentUpload!.files.length) return;
    
    final updatedFiles = List<FileUploadState>.from(_currentUpload!.files);
    updatedFiles[index] = updatedFiles[index].copyWith(
      status: status,
      progress: progress,
      errorMessage: errorMessage,
      result: result,
    );
    
    _currentUpload = _currentUpload!.copyWith(files: updatedFiles);
    _calculateOverallProgress();
    _notifyStateChange();
  }
  
  /// Calculate overall upload progress
  void _calculateOverallProgress() {
    if (_currentUpload == null) return;
    
    final files = _currentUpload!.files;
    final totalProgress = files.fold<double>(0.0, (sum, file) => sum + file.progress);
    final overallProgress = totalProgress / files.length;
    
    final completedCount = files.where((f) => f.status == UploadStatus.completed).length;
    final failedCount = files.where((f) => f.status == UploadStatus.failed).length;
    final hasErrors = failedCount > 0;
    final isCompleted = completedCount + failedCount == files.length;
    
    _currentUpload = _currentUpload!.copyWith(
      overallProgress: overallProgress,
      completedCount: completedCount,
      failedCount: failedCount,
      hasErrors: hasErrors,
      isCompleted: isCompleted,
    );
  }
  
  /// Mark entire upload as completed
  void _markUploadCompleted() {
    if (_currentUpload == null) return;
    
    _currentUpload = _currentUpload!.copyWith(
      isCompleted: true,
      overallProgress: 1.0,
    );
    _notifyStateChange();
  }
  
  /// Mark entire upload as failed
  void _markUploadFailed(String errorMessage) {
    if (_currentUpload == null) return;
    
    // Mark all pending files as failed
    final updatedFiles = _currentUpload!.files.map((file) {
      if (file.status == UploadStatus.pending || file.status == UploadStatus.uploading) {
        return file.copyWith(
          status: UploadStatus.failed,
          errorMessage: errorMessage,
        );
      }
      return file;
    }).toList();
    
    _currentUpload = _currentUpload!.copyWith(
      files: updatedFiles,
      isCompleted: true,
      hasErrors: true,
    );
    
    _calculateOverallProgress();
    _notifyStateChange();
  }
  
  /// Notify state change
  void _notifyStateChange() {
    if (_currentUpload != null) {
      _stateController.add(_currentUpload!);
      notifyListeners();
    }
  }
  
  /// Cancel current upload
  void cancelUpload() {
    if (_currentUpload != null) {
      _markUploadFailed('Upload cancelled by user');
    }
  }
  
  /// Clear current upload state
  void clearUpload() {
    _currentUpload = null;
    notifyListeners();
  }
  
  /// Get successful upload results
  List<MediaUploadResult> getSuccessfulResults() {
    if (_currentUpload == null) return [];
    
    return _currentUpload!.files
        .where((file) => file.result != null)
        .map((file) => file.result!)
        .toList();
  }
  
  /// Get failed uploads
  List<FileUploadState> getFailedUploads() {
    if (_currentUpload == null) return [];
    
    return _currentUpload!.files
        .where((file) => file.status == UploadStatus.failed)
        .toList();
  }
  
  /// Retry failed uploads
  Future<List<MediaUploadResult>> retryFailedUploads({
    required String userId,
    required String postId,
    CompressionSettings compression = CompressionSettings.fullSize,
    bool generateThumbnails = true,
  }) async {
    final failedFiles = getFailedUploads().map((state) => state.file).toList();
    
    if (failedFiles.isEmpty) return [];
    
    return await uploadFiles(
      files: failedFiles,
      userId: userId,
      postId: postId,
      compression: compression,
      generateThumbnails: generateThumbnails,
    );
  }
  
  @override
  void dispose() {
    _stateController.close();
    super.dispose();
  }
}

/// Semaphore for controlling concurrent operations
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();
  
  Semaphore(this.maxCount) : _currentCount = maxCount;
  
  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }
  
  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirstElement();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// Extension for Queue
extension QueueExtension<T> on Queue<T> {
  T removeFirstElement() {
    if (isEmpty) throw StateError('No element');
    return removeFirst();
  }
}
