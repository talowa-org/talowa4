// Legal Case Service for TALOWA
// Comprehensive legal case management and tracking system
// Reference: TALOWA_APP_BLUEPRINT.md - Legal Support Features

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/constants/app_constants.dart';

class LegalCaseService {
  static final LegalCaseService _instance = LegalCaseService._internal();
  factory LegalCaseService() => _instance;
  LegalCaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all legal cases for current user
  Stream<List<LegalCase>> getUserLegalCases() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.collectionLegalCases)
        .where('clientId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LegalCase.fromFirestore(doc))
            .toList());
  }

  /// Get legal case by ID
  Future<LegalCase?> getLegalCase(String caseId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.collectionLegalCases)
          .doc(caseId)
          .get();

      if (doc.exists) {
        return LegalCase.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting legal case: $e');
      return null;
    }
  }

  /// Create new legal case
  Future<String?> createLegalCase({
    required String title,
    required LegalCaseType type,
    required String description,
    String? landRecordId,
    String? opposingParty,
    String? courtName,
    DateTime? filingDate,
    List<String>? documentUrls,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate case number
      final caseNumber = await _generateCaseNumber(type);

      // Create legal case
      final legalCase = LegalCase(
        id: '', // Will be set by Firestore
        caseNumber: caseNumber,
        clientId: user.uid,
        title: title,
        type: type,
        description: description,
        landRecordId: landRecordId,
        opposingParty: opposingParty,
        courtName: courtName,
        filingDate: filingDate,
        status: CaseStatus.filed,
        priority: CasePriority.medium,
        documentUrls: documentUrls ?? [],
        hearingDates: [],
        timeline: [
          CaseTimelineEntry(
            date: DateTime.now(),
            event: 'Case Created',
            description: 'Legal case created in TALOWA system',
            attachments: [],
            addedBy: user.uid,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection(AppConstants.collectionLegalCases)
          .add(legalCase.toMap());

      // Update user's case count
      await _updateUserCaseCount(user.uid, 1);

      // Log activity
      await _logCaseActivity(
        caseId: docRef.id,
        action: 'case_created',
        details: 'Legal case created: $title',
      );

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating legal case: $e');
      return null;
    }
  }

  /// Update legal case
  Future<bool> updateLegalCase({
    required String caseId,
    String? title,
    String? description,
    String? opposingParty,
    String? courtName,
    DateTime? filingDate,
    CaseStatus? status,
    CasePriority? priority,
    String? lawyerId,
    List<String>? documentUrls,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (opposingParty != null) updates['opposingParty'] = opposingParty;
      if (courtName != null) updates['courtName'] = courtName;
      if (filingDate != null) updates['filingDate'] = Timestamp.fromDate(filingDate);
      if (status != null) updates['status'] = status.toString();
      if (priority != null) updates['priority'] = priority.toString();
      if (lawyerId != null) updates['lawyerId'] = lawyerId;
      if (documentUrls != null) updates['documentUrls'] = documentUrls;

      await _firestore
          .collection(AppConstants.collectionLegalCases)
          .doc(caseId)
          .update(updates);

      // Add timeline entry for status change
      if (status != null) {
        await addTimelineEntry(
          caseId: caseId,
          event: 'Status Updated',
          description: 'Case status changed to ${status.toString()}',
        );
      }

      // Log activity
      await _logCaseActivity(
        caseId: caseId,
        action: 'case_updated',
        details: 'Legal case updated',
      );

      return true;
    } catch (e) {
      debugPrint('Error updating legal case: $e');
      return false;
    }
  }

  /// Add hearing date
  Future<bool> addHearingDate({
    required String caseId,
    required DateTime hearingDate,
    required String purpose,
    String? notes,
    String? courtRoom,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final hearing = HearingDate(
        date: hearingDate,
        purpose: purpose,
        notes: notes,
        courtRoom: courtRoom,
        status: HearingStatus.scheduled,
        addedBy: user.uid,
        addedAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.collectionLegalCases)
          .doc(caseId)
          .update({
        'hearingDates': FieldValue.arrayUnion([hearing.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add timeline entry
      await addTimelineEntry(
        caseId: caseId,
        event: 'Hearing Scheduled',
        description: 'Hearing scheduled for ${hearingDate.day}/${hearingDate.month}/${hearingDate.year} - $purpose',
      );

      // Schedule reminder notification
      await _scheduleHearingReminder(caseId, hearing);

      // Log activity
      await _logCaseActivity(
        caseId: caseId,
        action: 'hearing_added',
        details: 'Hearing date added: $purpose',
      );

      return true;
    } catch (e) {
      debugPrint('Error adding hearing date: $e');
      return false;
    }
  }

  /// Update hearing status
  Future<bool> updateHearingStatus({
    required String caseId,
    required DateTime hearingDate,
    required HearingStatus status,
    String? outcome,
    DateTime? nextHearingDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get current case
      final caseDoc = await _firestore
          .collection(AppConstants.collectionLegalCases)
          .doc(caseId)
          .get();

      if (!caseDoc.exists) {
        throw Exception('Case not found');
      }

      final legalCase = LegalCase.fromFirestore(caseDoc);
      final updatedHearings = legalCase.hearingDates.map((hearing) {
        if (hearing.date.isAtSameMomentAs(hearingDate)) {
          return hearing.copyWith(
            status: status,
            outcome: outcome,
            nextHearingDate: nextHearingDate,
          );
        }
        return hearing;
      }).toList();

      await _firestore
          .collection(AppConstants.collectionLegalCases)
          .doc(caseId)
          .update({
        'hearingDates': updatedHearings.map((h) => h.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add timeline entry
      await addTimelineEntry(
        caseId: caseId,
        event: 'Hearing Updated',
        description: 'Hearing status updated to ${status.toString()}${outcome != null ? ': $outcome' : ''}',
      );

      // Schedule next hearing reminder if applicable
      if (nextHearingDate != null) {
        final nextHearing = HearingDate(
          date: nextHearingDate,
          purpose: 'Follow-up hearing',
          status: HearingStatus.scheduled,
          addedBy: user.uid,
          addedAt: DateTime.now(),
        );
        await addHearingDate(
          caseId: caseId,
          hearingDate: nextHearingDate,
          purpose: 'Follow-up hearing',
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error updating hearing status: $e');
      return false;
    }
  }

  /// Add timeline entry
  Future<bool> addTimelineEntry({
    required String caseId,
    required String event,
    required String description,
    List<String>? attachments,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final timelineEntry = CaseTimelineEntry(
        date: DateTime.now(),
        event: event,
        description: description,
        attachments: attachments ?? [],
        addedBy: user.uid,
      );

      await _firestore
          .collection(AppConstants.collectionLegalCases)
          .doc(caseId)
          .update({
        'timeline': FieldValue.arrayUnion([timelineEntry.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error adding timeline entry: $e');
      return false;
    }
  }

  /// Upload case document
  Future<String?> uploadCaseDocument({
    required String caseId,
    required File documentFile,
    required String documentType,
    String? description,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = documentFile.path.split('.').last;
      final fileName = '${caseId}_${documentType}_$timestamp.$extension';

      // Upload to Firebase Storage
      final ref = _storage
          .ref()
          .child('legal_cases')
          .child(user.uid)
          .child(fileName);

      final uploadTask = ref.putFile(documentFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update case with document URL
      await _firestore
          .collection(AppConstants.collectionLegalCases)
          .doc(caseId)
          .update({
        'documentUrls': FieldValue.arrayUnion([downloadUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add timeline entry
      await addTimelineEntry(
        caseId: caseId,
        event: 'Document Added',
        description: 'Document uploaded: $documentType${description != null ? ' - $description' : ''}',
        attachments: [downloadUrl],
      );

      // Log activity
      await _logCaseActivity(
        caseId: caseId,
        action: 'document_uploaded',
        details: 'Document uploaded: $documentType',
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading case document: $e');
      return null;
    }
  }

  /// Get available lawyers
  Future<List<Lawyer>> getAvailableLawyers({
    String? specialization,
    String? location,
  }) async {
    try {
      Query query = _firestore.collection('lawyers').where('isActive', isEqualTo: true);

      if (specialization != null) {
        query = query.where('specializations', arrayContains: specialization);
      }

      if (location != null) {
        query = query.where('practiceAreas', arrayContains: location);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Lawyer.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting lawyers: $e');
      return [];
    }
  }

  /// Assign lawyer to case
  Future<bool> assignLawyer({
    required String caseId,
    required String lawyerId,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.collectionLegalCases)
          .doc(caseId)
          .update({
        'lawyerId': lawyerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add timeline entry
      await addTimelineEntry(
        caseId: caseId,
        event: 'Lawyer Assigned',
        description: 'Legal representation assigned',
      );

      // Notify lawyer
      await _notifyLawyerAssignment(lawyerId, caseId);

      return true;
    } catch (e) {
      debugPrint('Error assigning lawyer: $e');
      return false;
    }
  }

  /// Get case statistics
  Future<LegalCaseStats> getCaseStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return LegalCaseStats.empty();
      }

      final snapshot = await _firestore
          .collection(AppConstants.collectionLegalCases)
          .where('clientId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final cases = snapshot.docs
          .map((doc) => LegalCase.fromFirestore(doc))
          .toList();

      return LegalCaseStats.fromCases(cases);
    } catch (e) {
      debugPrint('Error getting case statistics: $e');
      return LegalCaseStats.empty();
    }
  }

  /// Get upcoming hearings
  Future<List<UpcomingHearing>> getUpcomingHearings({
    int daysAhead = 30,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final endDate = DateTime.now().add(Duration(days: daysAhead));
      
      final snapshot = await _firestore
          .collection(AppConstants.collectionLegalCases)
          .where('clientId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      List<UpcomingHearing> upcomingHearings = [];

      for (final doc in snapshot.docs) {
        final legalCase = LegalCase.fromFirestore(doc);
        
        for (final hearing in legalCase.hearingDates) {
          if (hearing.date.isAfter(DateTime.now()) &&
              hearing.date.isBefore(endDate) &&
              hearing.status == HearingStatus.scheduled) {
            upcomingHearings.add(UpcomingHearing(
              caseId: legalCase.id,
              caseTitle: legalCase.title,
              hearing: hearing,
            ));
          }
        }
      }

      // Sort by date
      upcomingHearings.sort((a, b) => a.hearing.date.compareTo(b.hearing.date));

      return upcomingHearings;
    } catch (e) {
      debugPrint('Error getting upcoming hearings: $e');
      return [];
    }
  }

  // Private helper methods

  Future<String> _generateCaseNumber(LegalCaseType type) async {
    final year = DateTime.now().year;
    final typeCode = _getCaseTypeCode(type);
    
    // Get count of cases this year
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31);
    
    final snapshot = await _firestore
        .collection(AppConstants.collectionLegalCases)
        .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
        .where('createdAt', isLessThanOrEqualTo: endOfYear)
        .get();

    final count = snapshot.docs.length + 1;
    
    return 'TALOWA-$typeCode-$year-${count.toString().padLeft(4, '0')}';
  }

  String _getCaseTypeCode(LegalCaseType type) {
    switch (type) {
      case LegalCaseType.landDispute:
        return 'LD';
      case LegalCaseType.pattaApplication:
        return 'PA';
      case LegalCaseType.encroachment:
        return 'EN';
      case LegalCaseType.harassment:
        return 'HR';
      case LegalCaseType.civilCase:
        return 'CV';
      case LegalCaseType.criminalCase:
        return 'CR';
      default:
        return 'GN';
    }
  }

  Future<void> _updateUserCaseCount(String userId, int change) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'legalCaseCount': FieldValue.increment(change),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating user case count: $e');
    }
  }

  Future<void> _scheduleHearingReminder(String caseId, HearingDate hearing) async {
    // This would integrate with notification scheduling service
    debugPrint('Scheduling reminder for hearing on ${hearing.date}');
  }

  Future<void> _notifyLawyerAssignment(String lawyerId, String caseId) async {
    // This would send notification to lawyer
    debugPrint('Notifying lawyer $lawyerId about case assignment $caseId');
  }

  Future<void> _logCaseActivity({
    required String caseId,
    required String action,
    required String details,
  }) async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('legal_case_activities').add({
        'caseId': caseId,
        'userId': user?.uid,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging case activity: $e');
    }
  }
}

// Data models for legal case system

enum LegalCaseType {
  landDispute,
  pattaApplication,
  encroachment,
  harassment,
  civilCase,
  criminalCase,
  other,
}

enum CaseStatus {
  filed,
  underReview,
  hearingScheduled,
  inProgress,
  resolved,
  dismissed,
  appealed,
}

enum CasePriority {
  low,
  medium,
  high,
  urgent,
}

enum HearingStatus {
  scheduled,
  completed,
  postponed,
  cancelled,
}

class LegalCase {
  final String id;
  final String caseNumber;
  final String clientId;
  final String title;
  final LegalCaseType type;
  final String description;
  final String? landRecordId;
  final String? opposingParty;
  final String? courtName;
  final DateTime? filingDate;
  final CaseStatus status;
  final CasePriority priority;
  final String? lawyerId;
  final List<String> documentUrls;
  final List<HearingDate> hearingDates;
  final List<CaseTimelineEntry> timeline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  LegalCase({
    required this.id,
    required this.caseNumber,
    required this.clientId,
    required this.title,
    required this.type,
    required this.description,
    this.landRecordId,
    this.opposingParty,
    this.courtName,
    this.filingDate,
    required this.status,
    required this.priority,
    this.lawyerId,
    required this.documentUrls,
    required this.hearingDates,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'caseNumber': caseNumber,
      'clientId': clientId,
      'title': title,
      'type': type.toString(),
      'description': description,
      'landRecordId': landRecordId,
      'opposingParty': opposingParty,
      'courtName': courtName,
      'filingDate': filingDate != null ? Timestamp.fromDate(filingDate!) : null,
      'status': status.toString(),
      'priority': priority.toString(),
      'lawyerId': lawyerId,
      'documentUrls': documentUrls,
      'hearingDates': hearingDates.map((h) => h.toMap()).toList(),
      'timeline': timeline.map((t) => t.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  factory LegalCase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LegalCase(
      id: doc.id,
      caseNumber: data['caseNumber'] ?? '',
      clientId: data['clientId'] ?? '',
      title: data['title'] ?? '',
      type: LegalCaseType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => LegalCaseType.other,
      ),
      description: data['description'] ?? '',
      landRecordId: data['landRecordId'],
      opposingParty: data['opposingParty'],
      courtName: data['courtName'],
      filingDate: data['filingDate'] != null
          ? (data['filingDate'] as Timestamp).toDate()
          : null,
      status: CaseStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => CaseStatus.filed,
      ),
      priority: CasePriority.values.firstWhere(
        (e) => e.toString() == data['priority'],
        orElse: () => CasePriority.medium,
      ),
      lawyerId: data['lawyerId'],
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      hearingDates: (data['hearingDates'] as List<dynamic>? ?? [])
          .map((h) => HearingDate.fromMap(h))
          .toList(),
      timeline: (data['timeline'] as List<dynamic>? ?? [])
          .map((t) => CaseTimelineEntry.fromMap(t))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
}

class HearingDate {
  final DateTime date;
  final String purpose;
  final String? notes;
  final String? courtRoom;
  final HearingStatus status;
  final String? outcome;
  final DateTime? nextHearingDate;
  final String addedBy;
  final DateTime addedAt;

  HearingDate({
    required this.date,
    required this.purpose,
    this.notes,
    this.courtRoom,
    required this.status,
    this.outcome,
    this.nextHearingDate,
    required this.addedBy,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'purpose': purpose,
      'notes': notes,
      'courtRoom': courtRoom,
      'status': status.toString(),
      'outcome': outcome,
      'nextHearingDate': nextHearingDate != null
          ? Timestamp.fromDate(nextHearingDate!)
          : null,
      'addedBy': addedBy,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  factory HearingDate.fromMap(Map<String, dynamic> map) {
    return HearingDate(
      date: (map['date'] as Timestamp).toDate(),
      purpose: map['purpose'] ?? '',
      notes: map['notes'],
      courtRoom: map['courtRoom'],
      status: HearingStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => HearingStatus.scheduled,
      ),
      outcome: map['outcome'],
      nextHearingDate: map['nextHearingDate'] != null
          ? (map['nextHearingDate'] as Timestamp).toDate()
          : null,
      addedBy: map['addedBy'] ?? '',
      addedAt: (map['addedAt'] as Timestamp).toDate(),
    );
  }

  HearingDate copyWith({
    DateTime? date,
    String? purpose,
    String? notes,
    String? courtRoom,
    HearingStatus? status,
    String? outcome,
    DateTime? nextHearingDate,
  }) {
    return HearingDate(
      date: date ?? this.date,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      courtRoom: courtRoom ?? this.courtRoom,
      status: status ?? this.status,
      outcome: outcome ?? this.outcome,
      nextHearingDate: nextHearingDate ?? this.nextHearingDate,
      addedBy: addedBy,
      addedAt: addedAt,
    );
  }
}

class CaseTimelineEntry {
  final DateTime date;
  final String event;
  final String description;
  final List<String> attachments;
  final String addedBy;

  CaseTimelineEntry({
    required this.date,
    required this.event,
    required this.description,
    required this.attachments,
    required this.addedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'event': event,
      'description': description,
      'attachments': attachments,
      'addedBy': addedBy,
    };
  }

  factory CaseTimelineEntry.fromMap(Map<String, dynamic> map) {
    return CaseTimelineEntry(
      date: (map['date'] as Timestamp).toDate(),
      event: map['event'] ?? '',
      description: map['description'] ?? '',
      attachments: List<String>.from(map['attachments'] ?? []),
      addedBy: map['addedBy'] ?? '',
    );
  }
}

class Lawyer {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final List<String> specializations;
  final List<String> practiceAreas;
  final double rating;
  final int experienceYears;
  final bool isActive;

  Lawyer({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.specializations,
    required this.practiceAreas,
    required this.rating,
    required this.experienceYears,
    required this.isActive,
  });

  factory Lawyer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lawyer(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      specializations: List<String>.from(data['specializations'] ?? []),
      practiceAreas: List<String>.from(data['practiceAreas'] ?? []),
      rating: (data['rating'] ?? 0.0).toDouble(),
      experienceYears: data['experienceYears'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }
}

class LegalCaseStats {
  final int totalCases;
  final int activeCases;
  final int resolvedCases;
  final int upcomingHearings;
  final Map<String, int> casesByType;
  final Map<String, int> casesByStatus;

  LegalCaseStats({
    required this.totalCases,
    required this.activeCases,
    required this.resolvedCases,
    required this.upcomingHearings,
    required this.casesByType,
    required this.casesByStatus,
  });

  factory LegalCaseStats.empty() {
    return LegalCaseStats(
      totalCases: 0,
      activeCases: 0,
      resolvedCases: 0,
      upcomingHearings: 0,
      casesByType: {},
      casesByStatus: {},
    );
  }

  factory LegalCaseStats.fromCases(List<LegalCase> cases) {
    int activeCases = 0;
    int resolvedCases = 0;
    Map<String, int> byType = {};
    Map<String, int> byStatus = {};

    for (final case_ in cases) {
      // Count active/resolved
      if (case_.status == CaseStatus.resolved) {
        resolvedCases++;
      } else {
        activeCases++;
      }

      // Count by type
      final type = case_.type.toString().split('.').last;
      byType[type] = (byType[type] ?? 0) + 1;

      // Count by status
      final status = case_.status.toString().split('.').last;
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }

    return LegalCaseStats(
      totalCases: cases.length,
      activeCases: activeCases,
      resolvedCases: resolvedCases,
      upcomingHearings: 0, // Would be calculated separately
      casesByType: byType,
      casesByStatus: byStatus,
    );
  }
}

class UpcomingHearing {
  final String caseId;
  final String caseTitle;
  final HearingDate hearing;

  UpcomingHearing({
    required this.caseId,
    required this.caseTitle,
    required this.hearing,
  });
}
