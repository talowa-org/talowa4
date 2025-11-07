// Media Processing Queue Manager with Priority Handling
// Implements Task 9: Media processing queue with priority handling

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Media Processing Queue Manager
/// Manages media processing jobs with priority-based queue handling
class MediaProcessingQueueManager {
  static MediaProcessingQueueManager? _instance;
  static MediaProcessingQueueManager get instance =>
      _instance ??= MediaProcessingQueueManager._internal();

  MediaProcessingQueueManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Queue configuration
  static const int maxConcurrentJobs = 5;
  static const Duration jobTimeout = Duration(minutes: 30);
  static const int maxRetries = 3;

  /// Add job to processing queue
  Future<String> addToQueue({
    required ProcessingJobType jobType,
    required Map<String, dynamic> jobData,
    required String userId,
    ProcessingPriority priority = ProcessingPriority.normal,
    List<String>? dependencies,
  }) async {
    try {
      debugPrint('📋 Adding job to queue: ${jobType.name}');

      final job = {
        'type': jobType.name,
        'data': jobData,
        'userId': userId,
        'priority': priority.value,
        'status': JobStatus.pending.name,
        'retryCount': 0,
        'maxRetries': maxRetries,
        'dependencies': dependencies ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'timeoutAt': DateTime.now().add(jobTimeout).toIso8601String(),
      };

      final docRef = await _firestore.collection('media_processing_queue').add(job);

      debugPrint('✅ Job added to queue: ${docRef.id}');

      return docRef.id;
    } catch (e) {
      debugPrint('❌ Failed to add job to queue: $e');
      rethrow;
    }
  }

  /// Get next job from queue (priority-based)
  Future<ProcessingJob?> getNextJob() async {
    try {
      // Query for pending jobs ordered by priority (descending) and creation time
      final querySnapshot = await _firestore
          .collection('media_processing_queue')
          .where('status', isEqualTo: JobStatus.pending.name)
          .orderBy('priority', descending: true)
          .orderBy('createdAt')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      // Check dependencies
      final dependencies = List<String>.from(data['dependencies'] ?? []);
      if (dependencies.isNotEmpty) {
        final allDependenciesCompleted = await _checkDependencies(dependencies);
        if (!allDependenciesCompleted) {
          debugPrint('⏳ Job ${doc.id} has pending dependencies');
          return null;
        }
      }

      // Mark job as processing
      await _updateJobStatus(doc.id, JobStatus.processing);

      return ProcessingJob(
        id: doc.id,
        type: ProcessingJobType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => ProcessingJobType.videoCompression,
        ),
        data: Map<String, dynamic>.from(data['data']),
        userId: data['userId'],
        priority: ProcessingPriority.fromValue(data['priority']),
        status: JobStatus.processing,
        retryCount: data['retryCount'] ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Failed to get next job: $e');
      return null;
    }
  }

  /// Update job status
  Future<void> updateJobStatus({
    required String jobId,
    required JobStatus status,
    Map<String, dynamic>? result,
    String? error,
  }) async {
    try {
      await _updateJobStatus(jobId, status, result: result, error: error);
    } catch (e) {
      debugPrint('❌ Failed to update job status: $e');
    }
  }

  /// Mark job as completed
  Future<void> completeJob({
    required String jobId,
    required Map<String, dynamic> result,
  }) async {
    try {
      await _firestore.collection('media_processing_queue').doc(jobId).update({
        'status': JobStatus.completed.name,
        'result': result,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Job completed: $jobId');
    } catch (e) {
      debugPrint('❌ Failed to complete job: $e');
    }
  }

  /// Mark job as failed
  Future<void> failJob({
    required String jobId,
    required String error,
    bool retry = true,
  }) async {
    try {
      final doc = await _firestore.collection('media_processing_queue').doc(jobId).get();

      if (!doc.exists) {
        return;
      }

      final data = doc.data()!;
      final retryCount = (data['retryCount'] ?? 0) as int;
      final maxRetries = (data['maxRetries'] ?? 3) as int;

      if (retry && retryCount < maxRetries) {
        // Retry job
        await _firestore.collection('media_processing_queue').doc(jobId).update({
          'status': JobStatus.pending.name,
          'retryCount': retryCount + 1,
          'lastError': error,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('🔄 Job will be retried: $jobId (attempt ${retryCount + 1}/$maxRetries)');
      } else {
        // Mark as failed
        await _firestore.collection('media_processing_queue').doc(jobId).update({
          'status': JobStatus.failed.name,
          'error': error,
          'failedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('❌ Job failed: $jobId');
      }
    } catch (e) {
      debugPrint('❌ Failed to fail job: $e');
    }
  }

  /// Get job status
  Future<ProcessingJob?> getJobStatus(String jobId) async {
    try {
      final doc = await _firestore.collection('media_processing_queue').doc(jobId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;

      return ProcessingJob(
        id: doc.id,
        type: ProcessingJobType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => ProcessingJobType.videoCompression,
        ),
        data: Map<String, dynamic>.from(data['data']),
        userId: data['userId'],
        priority: ProcessingPriority.fromValue(data['priority']),
        status: JobStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => JobStatus.pending,
        ),
        retryCount: data['retryCount'] ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
        result: data['result'],
        error: data['error'],
      );
    } catch (e) {
      debugPrint('❌ Failed to get job status: $e');
      return null;
    }
  }

  /// Get queue statistics
  Future<QueueStatistics> getQueueStatistics() async {
    try {
      final pendingQuery = await _firestore
          .collection('media_processing_queue')
          .where('status', isEqualTo: JobStatus.pending.name)
          .count()
          .get();

      final processingQuery = await _firestore
          .collection('media_processing_queue')
          .where('status', isEqualTo: JobStatus.processing.name)
          .count()
          .get();

      final completedQuery = await _firestore
          .collection('media_processing_queue')
          .where('status', isEqualTo: JobStatus.completed.name)
          .count()
          .get();

      final failedQuery = await _firestore
          .collection('media_processing_queue')
          .where('status', isEqualTo: JobStatus.failed.name)
          .count()
          .get();

      return QueueStatistics(
        pendingJobs: pendingQuery.count ?? 0,
        processingJobs: processingQuery.count ?? 0,
        completedJobs: completedQuery.count ?? 0,
        failedJobs: failedQuery.count ?? 0,
      );
    } catch (e) {
      debugPrint('❌ Failed to get queue statistics: $e');
      return const QueueStatistics(
        pendingJobs: 0,
        processingJobs: 0,
        completedJobs: 0,
        failedJobs: 0,
      );
    }
  }

  /// Clean up old completed jobs
  Future<void> cleanupOldJobs({Duration age = const Duration(days: 7)}) async {
    try {
      final cutoffDate = DateTime.now().subtract(age);

      final querySnapshot = await _firestore
          .collection('media_processing_queue')
          .where('status', isEqualTo: JobStatus.completed.name)
          .where('completedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      debugPrint('🧹 Cleaned up ${querySnapshot.docs.length} old jobs');
    } catch (e) {
      debugPrint('❌ Failed to cleanup old jobs: $e');
    }
  }

  /// Internal: Update job status
  Future<void> _updateJobStatus(
    String jobId,
    JobStatus status, {
    Map<String, dynamic>? result,
    String? error,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (result != null) {
      updates['result'] = result;
    }

    if (error != null) {
      updates['error'] = error;
    }

    if (status == JobStatus.completed) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    } else if (status == JobStatus.failed) {
      updates['failedAt'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('media_processing_queue').doc(jobId).update(updates);
  }

  /// Internal: Check if all dependencies are completed
  Future<bool> _checkDependencies(List<String> dependencies) async {
    try {
      for (final depId in dependencies) {
        final doc = await _firestore.collection('media_processing_queue').doc(depId).get();

        if (!doc.exists) {
          return false;
        }

        final status = doc.data()?['status'];
        if (status != JobStatus.completed.name) {
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to check dependencies: $e');
      return false;
    }
  }
}

// Enums

enum ProcessingJobType {
  videoCompression,
  videoTranscoding,
  thumbnailGeneration,
  previewClipGeneration,
  hlsManifestGeneration,
  imageOptimization,
  webpConversion,
  multiResolutionGeneration,
  audioTranscoding,
}

enum JobStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

enum ProcessingPriority {
  low(1),
  normal(5),
  high(10),
  urgent(20);

  final int value;
  const ProcessingPriority(this.value);

  static ProcessingPriority fromValue(int value) {
    return ProcessingPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProcessingPriority.normal,
    );
  }
}

// Data Classes

class ProcessingJob {
  final String id;
  final ProcessingJobType type;
  final Map<String, dynamic> data;
  final String userId;
  final ProcessingPriority priority;
  final JobStatus status;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? result;
  final String? error;

  const ProcessingJob({
    required this.id,
    required this.type,
    required this.data,
    required this.userId,
    required this.priority,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    this.completedAt,
    this.result,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'data': data,
        'userId': userId,
        'priority': priority.value,
        'status': status.name,
        'retryCount': retryCount,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'result': result,
        'error': error,
      };
}

class QueueStatistics {
  final int pendingJobs;
  final int processingJobs;
  final int completedJobs;
  final int failedJobs;

  const QueueStatistics({
    required this.pendingJobs,
    required this.processingJobs,
    required this.completedJobs,
    required this.failedJobs,
  });

  int get totalJobs => pendingJobs + processingJobs + completedJobs + failedJobs;

  Map<String, dynamic> toJson() => {
        'pendingJobs': pendingJobs,
        'processingJobs': processingJobs,
        'completedJobs': completedJobs,
        'failedJobs': failedJobs,
        'totalJobs': totalJobs,
      };
}
