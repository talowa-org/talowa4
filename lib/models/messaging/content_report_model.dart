// Content Report Model for TALOWA Messaging System
import 'package:cloud_firestore/cloud_firestore.dart';

class ContentReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String messageId;
  final String conversationId;
  final String reportedUserId;
  final String reportedUserName;
  final ReportType reportType;
  final String reason;
  final String? description;
  final ReportStatus status;
  final DateTime reportedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;
  final Map<String, dynamic> metadata;

  ContentReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.messageId,
    required this.conversationId,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.reportType,
    required this.reason,
    this.description,
    required this.status,
    required this.reportedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
    required this.metadata,
  });

  // Convert from Firestore document
  factory ContentReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ContentReportModel(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? 'Unknown User',
      messageId: data['messageId'] ?? '',
      conversationId: data['conversationId'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      reportedUserName: data['reportedUserName'] ?? 'Unknown User',
      reportType: ReportTypeExtension.fromString(data['reportType'] ?? 'inappropriate'),
      reason: data['reason'] ?? '',
      description: data['description'],
      status: ReportStatusExtension.fromString(data['status'] ?? 'pending'),
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
      reviewNotes: data['reviewNotes'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'messageId': messageId,
      'conversationId': conversationId,
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      'reportType': reportType.value,
      'reason': reason,
      'description': description,
      'status': status.value,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
      'metadata': metadata,
    };
  }

  // Copy with method for updates
  ContentReportModel copyWith({
    String? id,
    String? reporterId,
    String? reporterName,
    String? messageId,
    String? conversationId,
    String? reportedUserId,
    String? reportedUserName,
    ReportType? reportType,
    String? reason,
    String? description,
    ReportStatus? status,
    DateTime? reportedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewNotes,
    Map<String, dynamic>? metadata,
  }) {
    return ContentReportModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      reportedUserName: reportedUserName ?? this.reportedUserName,
      reportType: reportType ?? this.reportType,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      status: status ?? this.status,
      reportedAt: reportedAt ?? this.reportedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ContentReportModel(id: $id, reportType: ${reportType.value}, status: ${status.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentReportModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Report types enum
enum ReportType {
  inappropriate,
  spam,
  harassment,
  violence,
  misinformation,
  other,
}

extension ReportTypeExtension on ReportType {
  String get value {
    switch (this) {
      case ReportType.inappropriate:
        return 'inappropriate';
      case ReportType.spam:
        return 'spam';
      case ReportType.harassment:
        return 'harassment';
      case ReportType.violence:
        return 'violence';
      case ReportType.misinformation:
        return 'misinformation';
      case ReportType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case ReportType.inappropriate:
        return 'Inappropriate Content';
      case ReportType.spam:
        return 'Spam';
      case ReportType.harassment:
        return 'Harassment';
      case ReportType.violence:
        return 'Violence/Threats';
      case ReportType.misinformation:
        return 'Misinformation';
      case ReportType.other:
        return 'Other';
    }
  }

  static ReportType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'spam':
        return ReportType.spam;
      case 'harassment':
        return ReportType.harassment;
      case 'violence':
        return ReportType.violence;
      case 'misinformation':
        return ReportType.misinformation;
      case 'other':
        return ReportType.other;
      default:
        return ReportType.inappropriate;
    }
  }
}

// Report status enum
enum ReportStatus {
  pending,
  reviewing,
  resolved,
  dismissed,
}

extension ReportStatusExtension on ReportStatus {
  String get value {
    switch (this) {
      case ReportStatus.pending:
        return 'pending';
      case ReportStatus.reviewing:
        return 'reviewing';
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.dismissed:
        return 'dismissed';
    }
  }

  String get displayName {
    switch (this) {
      case ReportStatus.pending:
        return 'Pending Review';
      case ReportStatus.reviewing:
        return 'Under Review';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.dismissed:
        return 'Dismissed';
    }
  }

  static ReportStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'reviewing':
        return ReportStatus.reviewing;
      case 'resolved':
        return ReportStatus.resolved;
      case 'dismissed':
        return ReportStatus.dismissed;
      default:
        return ReportStatus.pending;
    }
  }
}