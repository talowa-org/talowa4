// Campaign Model for TALOWA
// Reference: TALOWA_APP_BLUEPRINT.md - Campaign Management

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class CampaignModel {
  final String id;
  final String name;
  final String description;
  final CampaignType type;
  final CampaignStatus status;
  final String createdBy;
  final List<String> coordinatorIds;
  final CampaignLocation location;
  final DateTime startDate;
  final DateTime? endDate;
  final CampaignGoals goals;
  final List<CampaignEvent> events;
  final CampaignMetrics metrics;
  final String? groupId; // Associated messaging group
  final List<String> documentUrls;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  CampaignModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    required this.createdBy,
    required this.coordinatorIds,
    required this.location,
    required this.startDate,
    this.endDate,
    required this.goals,
    required this.events,
    required this.metrics,
    this.groupId,
    required this.documentUrls,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory CampaignModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CampaignModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: CampaignTypeExtension.fromString(data['type'] ?? 'awareness'),
      status: CampaignStatusExtension.fromString(data['status'] ?? 'planning'),
      createdBy: data['createdBy'] ?? '',
      coordinatorIds: List<String>.from(data['coordinatorIds'] ?? []),
      location: CampaignLocation.fromMap(data['location'] ?? {}),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      goals: CampaignGoals.fromMap(data['goals'] ?? {}),
      events: (data['events'] as List<dynamic>?)
          ?.map((e) => CampaignEvent.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      metrics: CampaignMetrics.fromMap(data['metrics'] ?? {}),
      groupId: data['groupId'],
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'type': type.value,
      'status': status.value,
      'createdBy': createdBy,
      'coordinatorIds': coordinatorIds,
      'location': location.toMap(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'goals': goals.toMap(),
      'events': events.map((e) => e.toMap()).toList(),
      'metrics': metrics.toMap(),
      'groupId': groupId,
      'documentUrls': documentUrls,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  CampaignModel copyWith({
    String? id,
    String? name,
    String? description,
    CampaignType? type,
    CampaignStatus? status,
    String? createdBy,
    List<String>? coordinatorIds,
    CampaignLocation? location,
    DateTime? startDate,
    DateTime? endDate,
    CampaignGoals? goals,
    List<CampaignEvent>? events,
    CampaignMetrics? metrics,
    String? groupId,
    List<String>? documentUrls,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return CampaignModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      coordinatorIds: coordinatorIds ?? this.coordinatorIds,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      goals: goals ?? this.goals,
      events: events ?? this.events,
      metrics: metrics ?? this.metrics,
      groupId: groupId ?? this.groupId,
      documentUrls: documentUrls ?? this.documentUrls,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum CampaignType {
  awareness,
  protest,
  legalAction,
  documentation,
  training,
  meeting,
  other,
}

extension CampaignTypeExtension on CampaignType {
  String get value {
    switch (this) {
      case CampaignType.awareness:
        return 'awareness';
      case CampaignType.protest:
        return 'protest';
      case CampaignType.legalAction:
        return 'legal_action';
      case CampaignType.documentation:
        return 'documentation';
      case CampaignType.training:
        return 'training';
      case CampaignType.meeting:
        return 'meeting';
      case CampaignType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case CampaignType.awareness:
        return 'Awareness Campaign';
      case CampaignType.protest:
        return 'Protest/Rally';
      case CampaignType.legalAction:
        return 'Legal Action';
      case CampaignType.documentation:
        return 'Documentation Drive';
      case CampaignType.training:
        return 'Training Program';
      case CampaignType.meeting:
        return 'Community Meeting';
      case CampaignType.other:
        return 'Other';
    }
  }

  static CampaignType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'protest':
        return CampaignType.protest;
      case 'legal_action':
        return CampaignType.legalAction;
      case 'documentation':
        return CampaignType.documentation;
      case 'training':
        return CampaignType.training;
      case 'meeting':
        return CampaignType.meeting;
      case 'other':
        return CampaignType.other;
      default:
        return CampaignType.awareness;
    }
  }
}

enum CampaignStatus {
  planning,
  active,
  completed,
  cancelled,
  postponed,
}

extension CampaignStatusExtension on CampaignStatus {
  String get value {
    switch (this) {
      case CampaignStatus.planning:
        return 'planning';
      case CampaignStatus.active:
        return 'active';
      case CampaignStatus.completed:
        return 'completed';
      case CampaignStatus.cancelled:
        return 'cancelled';
      case CampaignStatus.postponed:
        return 'postponed';
    }
  }

  String get displayName {
    switch (this) {
      case CampaignStatus.planning:
        return 'Planning';
      case CampaignStatus.active:
        return 'Active';
      case CampaignStatus.completed:
        return 'Completed';
      case CampaignStatus.cancelled:
        return 'Cancelled';
      case CampaignStatus.postponed:
        return 'Postponed';
    }
  }

  static CampaignStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return CampaignStatus.active;
      case 'completed':
        return CampaignStatus.completed;
      case 'cancelled':
        return CampaignStatus.cancelled;
      case 'postponed':
        return CampaignStatus.postponed;
      default:
        return CampaignStatus.planning;
    }
  }
}

class CampaignLocation {
  final String level; // village, mandal, district, state
  final String locationId;
  final String locationName;
  final List<String> targetAreas;
  final CampaignCoordinates? coordinates;

  CampaignLocation({
    required this.level,
    required this.locationId,
    required this.locationName,
    required this.targetAreas,
    this.coordinates,
  });

  factory CampaignLocation.fromMap(Map<String, dynamic> map) {
    return CampaignLocation(
      level: map['level'] ?? AppConstants.levelVillage,
      locationId: map['locationId'] ?? '',
      locationName: map['locationName'] ?? '',
      targetAreas: List<String>.from(map['targetAreas'] ?? []),
      coordinates: map['coordinates'] != null
          ? CampaignCoordinates.fromMap(map['coordinates'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'locationId': locationId,
      'locationName': locationName,
      'targetAreas': targetAreas,
      'coordinates': coordinates?.toMap(),
    };
  }
}

class CampaignCoordinates {
  final double latitude;
  final double longitude;
  final double? radius; // For area campaigns

  CampaignCoordinates({
    required this.latitude,
    required this.longitude,
    this.radius,
  });

  factory CampaignCoordinates.fromMap(Map<String, dynamic> map) {
    return CampaignCoordinates(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      radius: map['radius']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }
}

class CampaignGoals {
  final int targetParticipants;
  final int targetLandRecords;
  final int targetPattaApplications;
  final List<String> objectives;
  final Map<String, dynamic> customGoals;

  CampaignGoals({
    required this.targetParticipants,
    required this.targetLandRecords,
    required this.targetPattaApplications,
    required this.objectives,
    required this.customGoals,
  });

  factory CampaignGoals.fromMap(Map<String, dynamic> map) {
    return CampaignGoals(
      targetParticipants: map['targetParticipants'] ?? 0,
      targetLandRecords: map['targetLandRecords'] ?? 0,
      targetPattaApplications: map['targetPattaApplications'] ?? 0,
      objectives: List<String>.from(map['objectives'] ?? []),
      customGoals: Map<String, dynamic>.from(map['customGoals'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetParticipants': targetParticipants,
      'targetLandRecords': targetLandRecords,
      'targetPattaApplications': targetPattaApplications,
      'objectives': objectives,
      'customGoals': customGoals,
    };
  }
}

class CampaignEvent {
  final String id;
  final String name;
  final String description;
  final DateTime scheduledAt;
  final String? location;
  final EventStatus status;
  final List<String> participantIds;
  final Map<String, dynamic> metadata;

  CampaignEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.scheduledAt,
    this.location,
    required this.status,
    required this.participantIds,
    required this.metadata,
  });

  factory CampaignEvent.fromMap(Map<String, dynamic> map) {
    return CampaignEvent(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: map['location'],
      status: EventStatusExtension.fromString(map['status'] ?? 'scheduled'),
      participantIds: List<String>.from(map['participantIds'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'location': location,
      'status': status.value,
      'participantIds': participantIds,
      'metadata': metadata,
    };
  }
}

enum EventStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
  postponed,
}

extension EventStatusExtension on EventStatus {
  String get value {
    switch (this) {
      case EventStatus.scheduled:
        return 'scheduled';
      case EventStatus.inProgress:
        return 'in_progress';
      case EventStatus.completed:
        return 'completed';
      case EventStatus.cancelled:
        return 'cancelled';
      case EventStatus.postponed:
        return 'postponed';
    }
  }

  static EventStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return EventStatus.inProgress;
      case 'completed':
        return EventStatus.completed;
      case 'cancelled':
        return EventStatus.cancelled;
      case 'postponed':
        return EventStatus.postponed;
      default:
        return EventStatus.scheduled;
    }
  }
}

class CampaignMetrics {
  final int actualParticipants;
  final int landRecordsDocumented;
  final int pattaApplicationsSubmitted;
  final int eventsCompleted;
  final double successRate;
  final Map<String, int> customMetrics;

  CampaignMetrics({
    required this.actualParticipants,
    required this.landRecordsDocumented,
    required this.pattaApplicationsSubmitted,
    required this.eventsCompleted,
    required this.successRate,
    required this.customMetrics,
  });

  factory CampaignMetrics.fromMap(Map<String, dynamic> map) {
    return CampaignMetrics(
      actualParticipants: map['actualParticipants'] ?? 0,
      landRecordsDocumented: map['landRecordsDocumented'] ?? 0,
      pattaApplicationsSubmitted: map['pattaApplicationsSubmitted'] ?? 0,
      eventsCompleted: map['eventsCompleted'] ?? 0,
      successRate: (map['successRate'] ?? 0.0).toDouble(),
      customMetrics: Map<String, int>.from(map['customMetrics'] ?? {}),
    );
  }

  factory CampaignMetrics.empty() {
    return CampaignMetrics(
      actualParticipants: 0,
      landRecordsDocumented: 0,
      pattaApplicationsSubmitted: 0,
      eventsCompleted: 0,
      successRate: 0.0,
      customMetrics: {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actualParticipants': actualParticipants,
      'landRecordsDocumented': landRecordsDocumented,
      'pattaApplicationsSubmitted': pattaApplicationsSubmitted,
      'eventsCompleted': eventsCompleted,
      'successRate': successRate,
      'customMetrics': customMetrics,
    };
  }
}
