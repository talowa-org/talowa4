// Presence Models for TALOWA Messaging System
// Requirements: 1.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6

import 'package:cloud_firestore/cloud_firestore.dart';

/// User presence status enum
enum PresenceStatus {
  available,
  busy,
  away,
  doNotDisturb,
  invisible,
}

extension PresenceStatusExtension on PresenceStatus {
  String get value {
    switch (this) {
      case PresenceStatus.available:
        return 'available';
      case PresenceStatus.busy:
        return 'busy';
      case PresenceStatus.away:
        return 'away';
      case PresenceStatus.doNotDisturb:
        return 'do_not_disturb';
      case PresenceStatus.invisible:
        return 'invisible';
    }
  }

  String get displayName {
    switch (this) {
      case PresenceStatus.available:
        return 'Available';
      case PresenceStatus.busy:
        return 'Busy';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.doNotDisturb:
        return 'Do Not Disturb';
      case PresenceStatus.invisible:
        return 'Invisible';
    }
  }

  String get emoji {
    switch (this) {
      case PresenceStatus.available:
        return '🟢';
      case PresenceStatus.busy:
        return '🔴';
      case PresenceStatus.away:
        return '🟡';
      case PresenceStatus.doNotDisturb:
        return '⛔';
      case PresenceStatus.invisible:
        return '⚫';
    }
  }

  static PresenceStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'busy':
        return PresenceStatus.busy;
      case 'away':
        return PresenceStatus.away;
      case 'do_not_disturb':
        return PresenceStatus.doNotDisturb;
      case 'invisible':
        return PresenceStatus.invisible;
      default:
        return PresenceStatus.available;
    }
  }
}

/// User presence model
class UserPresence {
  final String userId;
  final bool isOnline;
  final DateTime lastSeen;
  final PresenceStatus? customStatus;
  final String? statusMessage;
  final DateTime updatedAt;

  UserPresence({
    required this.userId,
    required this.isOnline,
    required this.lastSeen,
    this.customStatus,
    this.statusMessage,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory UserPresence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserPresence(
      userId: doc.id,
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      customStatus: data['customStatus'] != null
          ? PresenceStatusExtension.fromString(data['customStatus'])
          : null,
      statusMessage: data['statusMessage'],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'customStatus': customStatus?.value,
      'statusMessage': statusMessage,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convert to Map for caching
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
      'customStatus': customStatus?.value,
      'statusMessage': statusMessage,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from Map for caching
  factory UserPresence.fromMap(Map<String, dynamic> map) {
    return UserPresence(
      userId: map['userId'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: DateTime.parse(map['lastSeen'] ?? DateTime.now().toIso8601String()),
      customStatus: map['customStatus'] != null
          ? PresenceStatusExtension.fromString(map['customStatus'])
          : null,
      statusMessage: map['statusMessage'],
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Get display status text
  String get displayStatus {
    if (!isOnline) {
      final timeDiff = DateTime.now().difference(lastSeen);
      if (timeDiff.inMinutes < 1) {
        return 'Last seen just now';
      } else if (timeDiff.inMinutes < 60) {
        return 'Last seen ${timeDiff.inMinutes}m ago';
      } else if (timeDiff.inHours < 24) {
        return 'Last seen ${timeDiff.inHours}h ago';
      } else {
        return 'Last seen ${timeDiff.inDays}d ago';
      }
    }
    
    if (customStatus != null) {
      return customStatus!.displayName;
    }
    
    return 'Online';
  }

  /// Get status emoji
  String get statusEmoji {
    if (!isOnline) {
      return '⚫'; // Offline
    }
    
    return customStatus?.emoji ?? '🟢'; // Online/Available
  }

  /// Check if user is currently active (online and recently seen)
  bool get isActive {
    if (!isOnline) return false;
    
    final timeDiff = DateTime.now().difference(lastSeen);
    return timeDiff.inMinutes < 5; // Active if seen within 5 minutes
  }

  /// Check if user is available for messaging
  bool get isAvailable {
    return isOnline && 
           (customStatus == null || 
            customStatus == PresenceStatus.available ||
            customStatus == PresenceStatus.away);
  }

  /// Check if user should not be disturbed
  bool get isDoNotDisturb {
    return customStatus == PresenceStatus.doNotDisturb;
  }

  /// Check if user is invisible
  bool get isInvisible {
    return customStatus == PresenceStatus.invisible;
  }

  /// Copy with method for updates
  UserPresence copyWith({
    String? userId,
    bool? isOnline,
    DateTime? lastSeen,
    PresenceStatus? customStatus,
    String? statusMessage,
    DateTime? updatedAt,
  }) {
    return UserPresence(
      userId: userId ?? this.userId,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      customStatus: customStatus ?? this.customStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserPresence(userId: $userId, isOnline: $isOnline, status: ${customStatus?.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPresence && 
           other.userId == userId &&
           other.isOnline == isOnline &&
           other.customStatus == customStatus;
  }

  @override
  int get hashCode => Object.hash(userId, isOnline, customStatus);
}

/// Typing indicator model
class TypingIndicator {
  final String userId;
  final String conversationId;
  final bool isTyping;
  final DateTime timestamp;

  TypingIndicator({
    required this.userId,
    required this.conversationId,
    required this.isTyping,
    required this.timestamp,
  });

  /// Create from Firestore document
  factory TypingIndicator.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TypingIndicator(
      userId: data['userId'] ?? '',
      conversationId: data['conversationId'] ?? '',
      isTyping: data['isTyping'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'conversationId': conversationId,
      'isTyping': isTyping,
      'timestamp': Timestamp.fromDate(timestamp),
      // Add TTL for automatic cleanup (expires after 10 seconds)
      'expiresAt': Timestamp.fromDate(timestamp.add(const Duration(seconds: 10))),
    };
  }

  /// Convert to Map for caching
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'conversationId': conversationId,
      'isTyping': isTyping,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from Map for caching
  factory TypingIndicator.fromMap(Map<String, dynamic> map) {
    return TypingIndicator(
      userId: map['userId'] ?? '',
      conversationId: map['conversationId'] ?? '',
      isTyping: map['isTyping'] ?? false,
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Check if typing indicator is still valid (not expired)
  bool get isValid {
    final timeDiff = DateTime.now().difference(timestamp);
    return timeDiff.inSeconds < 10; // Valid for 10 seconds
  }

  @override
  String toString() {
    return 'TypingIndicator(userId: $userId, conversationId: $conversationId, isTyping: $isTyping)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TypingIndicator && 
           other.userId == userId &&
           other.conversationId == conversationId;
  }

  @override
  int get hashCode => Object.hash(userId, conversationId);
}

/// Presence statistics model
class PresenceStats {
  final int totalUsers;
  final int onlineUsers;
  final int activeUsers; // Online and active within 5 minutes
  final int availableUsers; // Available for messaging
  final Map<PresenceStatus, int> statusCounts;
  final DateTime calculatedAt;

  PresenceStats({
    required this.totalUsers,
    required this.onlineUsers,
    required this.activeUsers,
    required this.availableUsers,
    required this.statusCounts,
    required this.calculatedAt,
  });

  /// Calculate online percentage
  double get onlinePercentage {
    if (totalUsers == 0) return 0.0;
    return (onlineUsers / totalUsers) * 100;
  }

  /// Calculate active percentage
  double get activePercentage {
    if (totalUsers == 0) return 0.0;
    return (activeUsers / totalUsers) * 100;
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'totalUsers': totalUsers,
      'onlineUsers': onlineUsers,
      'activeUsers': activeUsers,
      'availableUsers': availableUsers,
      'statusCounts': statusCounts.map((key, value) => MapEntry(key.value, value)),
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  /// Create from Map
  factory PresenceStats.fromMap(Map<String, dynamic> map) {
    return PresenceStats(
      totalUsers: map['totalUsers'] ?? 0,
      onlineUsers: map['onlineUsers'] ?? 0,
      activeUsers: map['activeUsers'] ?? 0,
      availableUsers: map['availableUsers'] ?? 0,
      statusCounts: Map<PresenceStatus, int>.fromEntries(
        (map['statusCounts'] as Map<String, dynamic>? ?? {})
            .entries
            .map((e) => MapEntry(
                  PresenceStatusExtension.fromString(e.key),
                  e.value as int,
                )),
      ),
      calculatedAt: DateTime.parse(
        map['calculatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  String toString() {
    return 'PresenceStats(total: $totalUsers, online: $onlineUsers, active: $activeUsers)';
  }
}