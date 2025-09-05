import 'call_participant.dart';
import 'call_quality.dart';

/// Voice call session model
class CallSession {
  final String id;
  final List<CallParticipant> participants;
  String status; // 'connecting', 'connected', 'ended', 'failed'
  final int startTime;
  int? endTime;
  CallQuality quality;
  final bool isEncrypted;

  CallSession({
    required this.id,
    required this.participants,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.quality,
    required this.isEncrypted,
  });

  /// Get call duration in seconds
  int get duration {
    if (endTime != null) {
      return ((endTime! - startTime) / 1000).round();
    } else if (status == 'connected') {
      return ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).round();
    }
    return 0;
  }

  /// Check if call is active
  bool get isActive => status == 'connected' || status == 'connecting';

  /// Get other participant (for 1-on-1 calls)
  CallParticipant? getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants.map((p) => p.toJson()).toList(),
      'status': status,
      'startTime': startTime,
      'endTime': endTime,
      'quality': quality.toJson(),
      'isEncrypted': isEncrypted,
    };
  }

  /// Create from JSON
  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id'],
      participants: (json['participants'] as List)
          .map((p) => CallParticipant.fromJson(p))
          .toList(),
      status: json['status'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      quality: CallQuality.fromJson(json['quality']),
      isEncrypted: json['isEncrypted'] ?? true,
    );
  }

  /// Create a copy with updated fields
  CallSession copyWith({
    String? status,
    int? endTime,
    CallQuality? quality,
    List<CallParticipant>? participants,
  }) {
    return CallSession(
      id: id,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      quality: quality ?? this.quality,
      isEncrypted: isEncrypted,
    );
  }
}

/// Incoming call model
class IncomingCall {
  final String id;
  final String callerId;
  final String callerName;
  final String callerRole;
  final String callType; // 'voice' or 'video'
  final int timestamp;

  IncomingCall({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.callerRole,
    required this.callType,
    required this.timestamp,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerRole': callerRole,
      'callType': callType,
      'timestamp': timestamp,
    };
  }

  /// Create from JSON
  factory IncomingCall.fromJson(Map<String, dynamic> json) {
    return IncomingCall(
      id: json['id'],
      callerId: json['callerId'],
      callerName: json['callerName'],
      callerRole: json['callerRole'],
      callType: json['callType'],
      timestamp: json['timestamp'],
    );
  }
}

/// Call history entry model
class CallHistoryEntry {
  final String id;
  final String participantId;
  final String participantName;
  final String participantRole;
  final String callType;
  final String status; // 'completed', 'missed', 'rejected', 'failed'
  final int startTime;
  final int? endTime;
  final int duration; // in seconds
  final bool isIncoming;
  final bool isEncrypted;

  CallHistoryEntry({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.participantRole,
    required this.callType,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.duration,
    required this.isIncoming,
    required this.isEncrypted,
  });

  /// Get formatted duration string
  String get formattedDuration {
    if (duration < 60) {
      return '${duration}s';
    } else if (duration < 3600) {
      final minutes = duration ~/ 60;
      final seconds = duration % 60;
      return '${minutes}m ${seconds}s';
    } else {
      final hours = duration ~/ 3600;
      final minutes = (duration % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  /// Get formatted timestamp
  String get formattedTime {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(startTime);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantId': participantId,
      'participantName': participantName,
      'participantRole': participantRole,
      'callType': callType,
      'status': status,
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
      'isIncoming': isIncoming,
      'isEncrypted': isEncrypted,
    };
  }

  /// Create from JSON
  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CallHistoryEntry(
      id: json['id'],
      participantId: json['participantId'],
      participantName: json['participantName'],
      participantRole: json['participantRole'],
      callType: json['callType'],
      status: json['status'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      duration: json['duration'],
      isIncoming: json['isIncoming'],
      isEncrypted: json['isEncrypted'] ?? true,
    );
  }
}

/// Missed call notification model
class MissedCallNotification {
  final String id;
  final String callerId;
  final String callerName;
  final String callerRole;
  final int timestamp;
  final bool isRead;

  MissedCallNotification({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.callerRole,
    required this.timestamp,
    this.isRead = false,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerRole': callerRole,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  /// Create from JSON
  factory MissedCallNotification.fromJson(Map<String, dynamic> json) {
    return MissedCallNotification(
      id: json['id'],
      callerId: json['callerId'],
      callerName: json['callerName'],
      callerRole: json['callerRole'],
      timestamp: json['timestamp'],
      isRead: json['isRead'] ?? false,
    );
  }

  /// Create a copy with updated fields
  MissedCallNotification copyWith({
    bool? isRead,
  }) {
    return MissedCallNotification(
      id: id,
      callerId: callerId,
      callerName: callerName,
      callerRole: callerRole,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
