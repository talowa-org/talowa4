// Anonymous Message Model for TALOWA Communication System
// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5

import 'package:cloud_firestore/cloud_firestore.dart';

class AnonymousMessageModel {
  final String id;
  final String caseId; // Unique case ID for tracking
  final String coordinatorId; // Coordinator who will receive the message
  final String encryptedContent; // Encrypted message content
  final AnonymousMessageType messageType;
  final AnonymousMessageStatus status;
  final GeographicScope scope; // Generalized location information
  final List<String> mediaUrls; // Encrypted media files
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? responseContent; // Coordinator's encrypted response
  final Map<String, dynamic> metadata; // Minimal metadata for privacy

  AnonymousMessageModel({
    required this.id,
    required this.caseId,
    required this.coordinatorId,
    required this.encryptedContent,
    required this.messageType,
    required this.status,
    required this.scope,
    required this.mediaUrls,
    required this.createdAt,
    this.respondedAt,
    this.responseContent,
    required this.metadata,
  });

  // Convert from Firestore document
  factory AnonymousMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AnonymousMessageModel(
      id: doc.id,
      caseId: data['caseId'] ?? '',
      coordinatorId: data['coordinatorId'] ?? '',
      encryptedContent: data['encryptedContent'] ?? '',
      messageType: AnonymousMessageTypeExtension.fromString(data['messageType'] ?? 'land_grabbing'),
      status: AnonymousMessageStatusExtension.fromString(data['status'] ?? 'pending'),
      scope: GeographicScope.fromMap(data['scope'] ?? {}),
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      responseContent: data['responseContent'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'caseId': caseId,
      'coordinatorId': coordinatorId,
      'encryptedContent': encryptedContent,
      'messageType': messageType.value,
      'status': status.value,
      'scope': scope.toMap(),
      'mediaUrls': mediaUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'responseContent': responseContent,
      'metadata': metadata,
    };
  }

  // Copy with method for updates
  AnonymousMessageModel copyWith({
    String? id,
    String? caseId,
    String? coordinatorId,
    String? encryptedContent,
    AnonymousMessageType? messageType,
    AnonymousMessageStatus? status,
    GeographicScope? scope,
    List<String>? mediaUrls,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? responseContent,
    Map<String, dynamic>? metadata,
  }) {
    return AnonymousMessageModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      coordinatorId: coordinatorId ?? this.coordinatorId,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      messageType: messageType ?? this.messageType,
      status: status ?? this.status,
      scope: scope ?? this.scope,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      responseContent: responseContent ?? this.responseContent,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  bool get hasResponse => responseContent != null && responseContent!.isNotEmpty;
  bool get isPending => status == AnonymousMessageStatus.pending;
  bool get isResolved => status == AnonymousMessageStatus.resolved;

  @override
  String toString() {
    return 'AnonymousMessageModel(id: $id, caseId: $caseId, type: ${messageType.value}, status: ${status.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnonymousMessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Geographic scope model for privacy protection
class GeographicScope {
  final String level; // village, mandal, district
  final String locationId; // Generalized location identifier
  final String? locationName; // Human-readable location name

  GeographicScope({
    required this.level,
    required this.locationId,
    this.locationName,
  });

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'locationId': locationId,
      'locationName': locationName,
    };
  }

  factory GeographicScope.fromMap(Map<String, dynamic> map) {
    return GeographicScope(
      level: map['level'] ?? 'village',
      locationId: map['locationId'] ?? '',
      locationName: map['locationName'],
    );
  }

  GeographicScope copyWith({
    String? level,
    String? locationId,
    String? locationName,
  }) {
    return GeographicScope(
      level: level ?? this.level,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
    );
  }
}

// Anonymous message types
enum AnonymousMessageType {
  landGrabbing,
  corruption,
  harassment,
  legalIssue,
  emergencyAlert,
  other,
}

extension AnonymousMessageTypeExtension on AnonymousMessageType {
  String get value {
    switch (this) {
      case AnonymousMessageType.landGrabbing:
        return 'land_grabbing';
      case AnonymousMessageType.corruption:
        return 'corruption';
      case AnonymousMessageType.harassment:
        return 'harassment';
      case AnonymousMessageType.legalIssue:
        return 'legal_issue';
      case AnonymousMessageType.emergencyAlert:
        return 'emergency_alert';
      case AnonymousMessageType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case AnonymousMessageType.landGrabbing:
        return 'Land Grabbing';
      case AnonymousMessageType.corruption:
        return 'Corruption';
      case AnonymousMessageType.harassment:
        return 'Harassment';
      case AnonymousMessageType.legalIssue:
        return 'Legal Issue';
      case AnonymousMessageType.emergencyAlert:
        return 'Emergency Alert';
      case AnonymousMessageType.other:
        return 'Other';
    }
  }

  static AnonymousMessageType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'corruption':
        return AnonymousMessageType.corruption;
      case 'harassment':
        return AnonymousMessageType.harassment;
      case 'legal_issue':
        return AnonymousMessageType.legalIssue;
      case 'emergency_alert':
        return AnonymousMessageType.emergencyAlert;
      case 'other':
        return AnonymousMessageType.other;
      default:
        return AnonymousMessageType.landGrabbing;
    }
  }
}

// Anonymous message status
enum AnonymousMessageStatus {
  pending,
  acknowledged,
  investigating,
  resolved,
  closed,
}

extension AnonymousMessageStatusExtension on AnonymousMessageStatus {
  String get value {
    switch (this) {
      case AnonymousMessageStatus.pending:
        return 'pending';
      case AnonymousMessageStatus.acknowledged:
        return 'acknowledged';
      case AnonymousMessageStatus.investigating:
        return 'investigating';
      case AnonymousMessageStatus.resolved:
        return 'resolved';
      case AnonymousMessageStatus.closed:
        return 'closed';
    }
  }

  String get displayName {
    switch (this) {
      case AnonymousMessageStatus.pending:
        return 'Pending Review';
      case AnonymousMessageStatus.acknowledged:
        return 'Acknowledged';
      case AnonymousMessageStatus.investigating:
        return 'Under Investigation';
      case AnonymousMessageStatus.resolved:
        return 'Resolved';
      case AnonymousMessageStatus.closed:
        return 'Closed';
    }
  }

  static AnonymousMessageStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'acknowledged':
        return AnonymousMessageStatus.acknowledged;
      case 'investigating':
        return AnonymousMessageStatus.investigating;
      case 'resolved':
        return AnonymousMessageStatus.resolved;
      case 'closed':
        return AnonymousMessageStatus.closed;
      default:
        return AnonymousMessageStatus.pending;
    }
  }
}
