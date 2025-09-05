// Land Record Model for TALOWA
// Reference: TECHNICAL_ARCHITECTURE.md - Land Records Collections

import 'package:cloud_firestore/cloud_firestore.dart';

class LandRecordModel {
  final String id;
  final String ownerId;
  final String ownerPhone;
  final String surveyNumber;
  final double area;
  final String unit;
  final String landType;
  final LandLocation location;
  final String legalStatus;
  final DateTime? assignmentDate;
  final DateTime? pattaApplicationDate;
  final DateTime? pattaReceivedDate;
  final LandDocuments documents;
  final LandIssues issues;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;

  LandRecordModel({
    required this.id,
    required this.ownerId,
    required this.ownerPhone,
    required this.surveyNumber,
    required this.area,
    required this.unit,
    required this.landType,
    required this.location,
    required this.legalStatus,
    this.assignmentDate,
    this.pattaApplicationDate,
    this.pattaReceivedDate,
    required this.documents,
    required this.issues,
    required this.createdAt,
    required this.updatedAt,
    this.verifiedAt,
    this.verifiedBy,
  });

  factory LandRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return LandRecordModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      ownerPhone: data['ownerPhone'] ?? '',
      surveyNumber: data['surveyNumber'] ?? '',
      area: (data['area'] ?? 0).toDouble(),
      unit: data['unit'] ?? 'acres',
      landType: data['landType'] ?? 'agricultural',
      location: LandLocation.fromMap(data['location'] ?? {}),
      legalStatus: data['legalStatus'] ?? 'assigned',
      assignmentDate: (data['assignmentDate'] as Timestamp?)?.toDate(),
      pattaApplicationDate: (data['pattaApplicationDate'] as Timestamp?)?.toDate(),
      pattaReceivedDate: (data['pattaReceivedDate'] as Timestamp?)?.toDate(),
      documents: LandDocuments.fromMap(data['documents'] ?? {}),
      issues: LandIssues.fromMap(data['issues'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      verifiedBy: data['verifiedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'ownerPhone': ownerPhone,
      'surveyNumber': surveyNumber,
      'area': area,
      'unit': unit,
      'landType': landType,
      'location': location.toMap(),
      'legalStatus': legalStatus,
      'assignmentDate': assignmentDate != null ? Timestamp.fromDate(assignmentDate!) : null,
      'pattaApplicationDate': pattaApplicationDate != null ? Timestamp.fromDate(pattaApplicationDate!) : null,
      'pattaReceivedDate': pattaReceivedDate != null ? Timestamp.fromDate(pattaReceivedDate!) : null,
      'documents': documents.toMap(),
      'issues': issues.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'verifiedBy': verifiedBy,
    };
  }
}

class LandLocation {
  final String village;
  final String mandal;
  final String district;
  final String state;
  final GeoCoordinates? coordinates;

  LandLocation({
    required this.village,
    required this.mandal,
    required this.district,
    required this.state,
    this.coordinates,
  });

  factory LandLocation.fromMap(Map<String, dynamic> map) {
    return LandLocation(
      village: map['village'] ?? '',
      mandal: map['mandal'] ?? '',
      district: map['district'] ?? '',
      state: map['state'] ?? '',
      coordinates: map['coordinates'] != null 
          ? GeoCoordinates.fromMap(map['coordinates'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'village': village,
      'mandal': mandal,
      'district': district,
      'state': state,
      'coordinates': coordinates?.toMap(),
    };
  }
}

class GeoCoordinates {
  final double latitude;
  final double longitude;

  GeoCoordinates({
    required this.latitude,
    required this.longitude,
  });

  factory GeoCoordinates.fromMap(Map<String, dynamic> map) {
    return GeoCoordinates(
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class LandDocuments {
  final String? assignmentOrder;
  final String? surveySettlement;
  final String? pattaDocument;
  final List<String> photos;

  LandDocuments({
    this.assignmentOrder,
    this.surveySettlement,
    this.pattaDocument,
    required this.photos,
  });

  factory LandDocuments.fromMap(Map<String, dynamic> map) {
    return LandDocuments(
      assignmentOrder: map['assignmentOrder'],
      surveySettlement: map['surveySettlement'],
      pattaDocument: map['pattaDocument'],
      photos: List<String>.from(map['photos'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assignmentOrder': assignmentOrder,
      'surveySettlement': surveySettlement,
      'pattaDocument': pattaDocument,
      'photos': photos,
    };
  }
}

class LandIssues {
  final bool hasEncroachment;
  final bool hasDispute;
  final bool hasLegalCase;
  final String? description;

  LandIssues({
    required this.hasEncroachment,
    required this.hasDispute,
    required this.hasLegalCase,
    this.description,
  });

  factory LandIssues.fromMap(Map<String, dynamic> map) {
    return LandIssues(
      hasEncroachment: map['hasEncroachment'] ?? false,
      hasDispute: map['hasDispute'] ?? false,
      hasLegalCase: map['hasLegalCase'] ?? false,
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasEncroachment': hasEncroachment,
      'hasDispute': hasDispute,
      'hasLegalCase': hasLegalCase,
      'description': description,
    };
  }
}
