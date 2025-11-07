import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service for recording live streams and post-stream processing
class StreamRecordingService {
  static final StreamRecordingService _instance = StreamRecordingService._internal();
  factory StreamRecordingService() => _instance;
  StreamRecordingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Start recording a stream
  Future<void> startRecording(String streamId) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'recordingStatus': 'recording',
      'recordingStartedAt': FieldValue.serverTimestamp(),
    });

    // In a real implementation, this would trigger a cloud function
    // to start recording the WebRTC stream
    print('Recording started for stream: $streamId');
  }

  /// Stop recording a stream
  Future<void> stopRecording(String streamId) async {
    await _firestore.collection('live_streams').doc(streamId).update({
      'recordingStatus': 'processing',
      'recordingEndedAt': FieldValue.serverTimestamp(),
    });

    // Trigger post-processing
    await _processRecording(streamId);
  }

  /// Process recorded stream
  Future<void> _processRecording(String streamId) async {
    try {
      // In a real implementation, this would:
      // 1. Transcode the recording to multiple qualities
      // 2. Generate thumbnails
      // 3. Extract highlights
      // 4. Upload to storage
      // 5. Update database with URLs

      // Simulate processing
      await Future.delayed(const Duration(seconds: 2));

      // Update with mock URLs (in production, these would be real URLs)
      final recordingUrl = 'https://storage.talowa.com/recordings/$streamId/recording.mp4';
      final thumbnailUrl = 'https://storage.talowa.com/recordings/$streamId/thumbnail.jpg';

      await _firestore.collection('live_streams').doc(streamId).update({
        'recordingStatus': 'completed',
        'recordingUrl': recordingUrl,
        'thumbnailUrl': thumbnailUrl,
        'recordingProcessedAt': FieldValue.serverTimestamp(),
      });

      print('Recording processed for stream: $streamId');
    } catch (e) {
      await _firestore.collection('live_streams').doc(streamId).update({
        'recordingStatus': 'failed',
        'recordingError': e.toString(),
      });
      print('Recording processing failed: $e');
    }
  }

  /// Get recording URL
  Future<String?> getRecordingUrl(String streamId) async {
    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();
    return data?['recordingUrl'] as String?;
  }

  /// Save stream as post
  Future<void> saveStreamAsPost(String streamId, PostMetadata metadata) async {
    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();

    if (data == null) {
      throw Exception('Stream not found');
    }

    final recordingUrl = data['recordingUrl'] as String?;
    if (recordingUrl == null) {
      throw Exception('Recording not available');
    }

    // Create post from stream
    await _firestore.collection('posts').add({
      'authorId': data['hostId'],
      'authorName': data['hostName'],
      'authorAvatarUrl': data['hostAvatarUrl'],
      'title': metadata.title ?? data['title'],
      'content': metadata.description ?? data['description'] ?? 'Live stream recording',
      'mediaAssets': [
        {
          'type': 'video',
          'url': recordingUrl,
          'thumbnailUrl': data['thumbnailUrl'],
          'duration': _calculateDuration(data),
        }
      ],
      'category': 'live_stream_recording',
      'hashtags': metadata.hashtags ?? [],
      'targeting': data['targeting'],
      'createdAt': FieldValue.serverTimestamp(),
      'streamId': streamId,
      'isStreamRecording': true,
      'streamAnalytics': {
        'totalViews': data['totalViews'] ?? 0,
        'peakViewers': data['peakViewers'] ?? 0,
        'chatMessages': data['chatMessages'] ?? 0,
        'reactions': data['reactions'] ?? 0,
      },
    });

    await _firestore.collection('live_streams').doc(streamId).update({
      'savedAsPost': true,
      'savedAsPostAt': FieldValue.serverTimestamp(),
    });
  }

  /// Generate stream highlights
  Future<List<StreamHighlight>> generateHighlights(String streamId) async {
    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();

    if (data == null) {
      throw Exception('Stream not found');
    }

    // Get engagement timeline
    final chatSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('chat')
        .orderBy('timestamp')
        .get();

    final reactionsSnapshot = await _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('reactions')
        .orderBy('timestamp')
        .get();

    // Find peak engagement moments
    final highlights = <StreamHighlight>[];
    final startedAt = (data['startedAt'] as Timestamp?)?.toDate();

    if (startedAt != null) {
      // Analyze engagement in 30-second windows
      final duration = _calculateDuration(data);
      for (var i = 0; i < duration; i += 30) {
        final windowStart = startedAt.add(Duration(seconds: i));
        final windowEnd = windowStart.add(const Duration(seconds: 30));

        final chatCount = chatSnapshot.docs.where((doc) {
          final timestamp = (doc.data()['timestamp'] as Timestamp?)?.toDate();
          return timestamp != null &&
              timestamp.isAfter(windowStart) &&
              timestamp.isBefore(windowEnd);
        }).length;

        final reactionCount = reactionsSnapshot.docs.where((doc) {
          final timestamp = (doc.data()['timestamp'] as Timestamp?)?.toDate();
          return timestamp != null &&
              timestamp.isAfter(windowStart) &&
              timestamp.isBefore(windowEnd);
        }).length;

        final engagement = chatCount + reactionCount;

        // Consider it a highlight if engagement is high
        if (engagement > 10) {
          highlights.add(StreamHighlight(
            timestamp: i,
            duration: 30,
            engagement: engagement,
            description: 'High engagement moment',
          ));
        }
      }
    }

    // Sort by engagement and take top 5
    highlights.sort((a, b) => b.engagement.compareTo(a.engagement));
    return highlights.take(5).toList();
  }

  /// Delete recording
  Future<void> deleteRecording(String streamId) async {
    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();

    if (data == null) {
      throw Exception('Stream not found');
    }

    final recordingUrl = data['recordingUrl'] as String?;
    if (recordingUrl != null) {
      try {
        // Delete from storage
        final ref = _storage.refFromURL(recordingUrl);
        await ref.delete();
      } catch (e) {
        print('Error deleting recording file: $e');
      }
    }

    await _firestore.collection('live_streams').doc(streamId).update({
      'recordingUrl': FieldValue.delete(),
      'recordingStatus': 'deleted',
      'recordingDeletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get recording status
  Future<RecordingStatus> getRecordingStatus(String streamId) async {
    final streamDoc = await _firestore.collection('live_streams').doc(streamId).get();
    final data = streamDoc.data();

    if (data == null) {
      throw Exception('Stream not found');
    }

    final status = data['recordingStatus'] as String?;
    switch (status) {
      case 'recording':
        return RecordingStatus.recording;
      case 'processing':
        return RecordingStatus.processing;
      case 'completed':
        return RecordingStatus.completed;
      case 'failed':
        return RecordingStatus.failed;
      case 'deleted':
        return RecordingStatus.deleted;
      default:
        return RecordingStatus.notStarted;
    }
  }

  /// Download recording
  Future<String> getDownloadUrl(String streamId) async {
    final recordingUrl = await getRecordingUrl(streamId);
    if (recordingUrl == null) {
      throw Exception('Recording not available');
    }

    // In production, this would generate a signed URL with expiration
    return recordingUrl;
  }

  int _calculateDuration(Map<String, dynamic> data) {
    final startedAt = data['startedAt'] as Timestamp?;
    final endedAt = data['endedAt'] as Timestamp?;

    if (startedAt != null && endedAt != null) {
      return endedAt.toDate().difference(startedAt.toDate()).inSeconds;
    }
    return 0;
  }
}

// Models
class PostMetadata {
  final String? title;
  final String? description;
  final List<String>? hashtags;

  PostMetadata({
    this.title,
    this.description,
    this.hashtags,
  });
}

class StreamHighlight {
  final int timestamp;
  final int duration;
  final int engagement;
  final String description;

  StreamHighlight({
    required this.timestamp,
    required this.duration,
    required this.engagement,
    required this.description,
  });
}

enum RecordingStatus {
  notStarted,
  recording,
  processing,
  completed,
  failed,
  deleted,
}
