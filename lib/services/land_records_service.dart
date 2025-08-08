// Land Records Service for TALOWA
// Comprehensive land record management with GPS integration
// Reference: TALOWA_APP_BLUEPRINT.md - Land Records System

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/land_record_model.dart';
import '../core/constants/app_constants.dart';

// Create LandRecord alias for compatibility
typedef LandRecord = LandRecordModel;

class LandRecordsService {
  static final LandRecordsService _instance = LandRecordsService._internal();
  factory LandRecordsService() => _instance;
  LandRecordsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all land records for current user
  Stream<List<LandRecord>> getUserLandRecords() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.collectionLandRecords)
        .where('ownerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LandRecord.fromFirestore(doc))
            .toList());
  }

  /// Get land record by ID
  Future<LandRecord?> getLandRecord(String recordId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.collectionLandRecords)
          .doc(recordId)
          .get();

      if (doc.exists) {
        return LandRecord.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting land record: $e');
      return null;
    }
  }

  /// Create new land record
  Future<String?> createLandRecord({
    required String surveyNumber,
    required String village,
    required String mandal,
    required String district,
    required double area,
    required String areaUnit,
    required LandType landType,
    required PattaStatus pattaStatus,
    String? description,
    List<String>? documentUrls,
    Position? gpsLocation,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create land record document using existing model structure
      final landRecord = LandRecordModel(
        id: '', // Will be set by Firestore
        ownerId: user.uid,
        ownerPhone: user.phoneNumber ?? '',
        surveyNumber: surveyNumber,
        area: area,
        unit: areaUnit,
        landType: landType.toString().split('.').last,
        location: LandLocation(
          village: village,
          mandal: mandal,
          district: district,
          state: 'Telangana',
          coordinates: gpsLocation != null
              ? GeoCoordinates(
                  latitude: gpsLocation.latitude,
                  longitude: gpsLocation.longitude,
                )
              : null,
        ),
        legalStatus: pattaStatus.toString().split('.').last,
        documents: LandDocuments(
          photos: documentUrls ?? [],
        ),
        issues: LandIssues(
          hasEncroachment: false,
          hasDispute: false,
          hasLegalCase: false,
          description: description,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to Firestore
      final docRef = await _firestore
          .collection(AppConstants.collectionLandRecords)
          .add(landRecord.toFirestore());

      // Update user's land record count
      await _updateUserLandRecordCount(user.uid, 1);

      // Log activity
      await _logLandRecordActivity(
        recordId: docRef.id,
        action: 'created',
        details: 'Land record created for survey number $surveyNumber',
      );

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating land record: $e');
      return null;
    }
  }

  /// Update existing land record
  Future<bool> updateLandRecord({
    required String recordId,
    String? surveyNumber,
    String? village,
    String? mandal,
    String? district,
    double? area,
    String? areaUnit,
    LandType? landType,
    PattaStatus? pattaStatus,
    String? description,
    List<String>? documentUrls,
    Position? gpsLocation,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (surveyNumber != null) updates['surveyNumber'] = surveyNumber;
      if (village != null) updates['village'] = village;
      if (mandal != null) updates['mandal'] = mandal;
      if (district != null) updates['district'] = district;
      if (area != null) updates['area'] = area;
      if (areaUnit != null) updates['areaUnit'] = areaUnit;
      if (landType != null) updates['landType'] = landType.toString();
      if (pattaStatus != null) updates['pattaStatus'] = pattaStatus.toString();
      if (description != null) updates['description'] = description;
      if (documentUrls != null) updates['documentUrls'] = documentUrls;
      if (gpsLocation != null) {
        updates['gpsCoordinates'] = GeoPoint(
          gpsLocation.latitude,
          gpsLocation.longitude,
        );
      }

      await _firestore
          .collection(AppConstants.collectionLandRecords)
          .doc(recordId)
          .update(updates);

      // Log activity
      await _logLandRecordActivity(
        recordId: recordId,
        action: 'updated',
        details: 'Land record updated',
      );

      return true;
    } catch (e) {
      debugPrint('Error updating land record: $e');
      return false;
    }
  }

  /// Delete land record
  Future<bool> deleteLandRecord(String recordId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Soft delete - mark as inactive
      await _firestore
          .collection(AppConstants.collectionLandRecords)
          .doc(recordId)
          .update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user's land record count
      await _updateUserLandRecordCount(user.uid, -1);

      // Log activity
      await _logLandRecordActivity(
        recordId: recordId,
        action: 'deleted',
        details: 'Land record marked as inactive',
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting land record: $e');
      return false;
    }
  }

  /// Upload document for land record
  Future<String?> uploadDocument({
    required String recordId,
    required File documentFile,
    required String documentType,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = documentFile.path.split('.').last;
      final fileName = '${recordId}_${documentType}_$timestamp.$extension';

      // Upload to Firebase Storage
      final ref = _storage
          .ref()
          .child('land_records')
          .child(user.uid)
          .child(fileName);

      final uploadTask = ref.putFile(documentFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update land record with document URL
      await _firestore
          .collection(AppConstants.collectionLandRecords)
          .doc(recordId)
          .update({
        'documentUrls': FieldValue.arrayUnion([downloadUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await _logLandRecordActivity(
        recordId: recordId,
        action: 'document_uploaded',
        details: 'Document uploaded: $documentType',
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading document: $e');
      return null;
    }
  }

  /// Get current GPS location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Search land records by survey number
  Future<List<LandRecord>> searchBySurveyNumber(String surveyNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final snapshot = await _firestore
          .collection(AppConstants.collectionLandRecords)
          .where('ownerId', isEqualTo: user.uid)
          .where('surveyNumber', isEqualTo: surveyNumber)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => LandRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error searching land records: $e');
      return [];
    }
  }

  /// Get land records by location
  Future<List<LandRecord>> getLandRecordsByLocation({
    required String village,
    String? mandal,
    String? district,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      Query query = _firestore
          .collection(AppConstants.collectionLandRecords)
          .where('ownerId', isEqualTo: user.uid)
          .where('village', isEqualTo: village)
          .where('isActive', isEqualTo: true);

      if (mandal != null) {
        query = query.where('mandal', isEqualTo: mandal);
      }

      if (district != null) {
        query = query.where('district', isEqualTo: district);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => LandRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting land records by location: $e');
      return [];
    }
  }

  /// Get land records statistics
  Future<LandRecordStats> getLandRecordStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return LandRecordStats.empty();
      }

      final snapshot = await _firestore
          .collection(AppConstants.collectionLandRecords)
          .where('ownerId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final records = snapshot.docs
          .map((doc) => LandRecord.fromFirestore(doc))
          .toList();

      return LandRecordStats.fromRecords(records);
    } catch (e) {
      debugPrint('Error getting land record stats: $e');
      return LandRecordStats.empty();
    }
  }

  /// Check for potential land disputes
  Future<List<LandDispute>> checkForDisputes(String recordId) async {
    try {
      // This would integrate with government databases in production
      // For now, return mock data based on record analysis
      
      final record = await getLandRecord(recordId);
      if (record == null) return [];

      List<LandDispute> disputes = [];

      // Check for overlapping survey numbers in the area
      final nearbyRecords = await getLandRecordsByLocation(
        village: record.location.village,
        mandal: record.location.mandal,
        district: record.location.district,
      );

      for (final nearbyRecord in nearbyRecords) {
        if (nearbyRecord.id != recordId &&
            nearbyRecord.surveyNumber == record.surveyNumber) {
          disputes.add(LandDispute(
            type: DisputeType.surveyNumberConflict,
            description: 'Duplicate survey number found in same area',
            severity: DisputeSeverity.high,
            conflictingRecordId: nearbyRecord.id,
          ));
        }
      }

      return disputes;
    } catch (e) {
      debugPrint('Error checking for disputes: $e');
      return [];
    }
  }

  /// Generate land record report
  Future<Map<String, dynamic>> generateReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      Query query = _firestore
          .collection(AppConstants.collectionLandRecords)
          .where('ownerId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final records = snapshot.docs
          .map((doc) => LandRecord.fromFirestore(doc))
          .toList();

      final stats = LandRecordStats.fromRecords(records);

      return {
        'totalRecords': records.length,
        'totalArea': stats.totalArea,
        'pattaReceived': stats.pattaReceivedCount,
        'pattaPending': stats.pattaPendingCount,
        'disputed': stats.disputedCount,
        'byLandType': stats.landTypeDistribution,
        'byLocation': stats.locationDistribution,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error generating report: $e');
      return {};
    }
  }

  // Private helper methods

  Future<void> _updateUserLandRecordCount(String userId, int change) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'landRecordCount': FieldValue.increment(change),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating user land record count: $e');
    }
  }

  Future<void> _logLandRecordActivity({
    required String recordId,
    required String action,
    required String details,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('land_record_activities').add({
        'recordId': recordId,
        'userId': user.uid,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging land record activity: $e');
    }
  }
}

// Data models for land records

enum LandType {
  agricultural,
  residential,
  commercial,
  industrial,
  forest,
  wasteland,
}

enum PattaStatus {
  received,
  pending,
  applied,
  rejected,
  underReview,
}

enum DisputeType {
  surveyNumberConflict,
  boundaryDispute,
  ownershipConflict,
  encroachment,
}

enum DisputeSeverity {
  low,
  medium,
  high,
  critical,
}

class LandDispute {
  final DisputeType type;
  final String description;
  final DisputeSeverity severity;
  final String? conflictingRecordId;

  LandDispute({
    required this.type,
    required this.description,
    required this.severity,
    this.conflictingRecordId,
  });
}

class LandRecordStats {
  final int totalRecords;
  final double totalArea;
  final int pattaReceivedCount;
  final int pattaPendingCount;
  final int disputedCount;
  final Map<String, int> landTypeDistribution;
  final Map<String, int> locationDistribution;

  LandRecordStats({
    required this.totalRecords,
    required this.totalArea,
    required this.pattaReceivedCount,
    required this.pattaPendingCount,
    required this.disputedCount,
    required this.landTypeDistribution,
    required this.locationDistribution,
  });

  factory LandRecordStats.empty() {
    return LandRecordStats(
      totalRecords: 0,
      totalArea: 0.0,
      pattaReceivedCount: 0,
      pattaPendingCount: 0,
      disputedCount: 0,
      landTypeDistribution: {},
      locationDistribution: {},
    );
  }

  factory LandRecordStats.fromRecords(List<LandRecord> records) {
    double totalArea = 0.0;
    int pattaReceived = 0;
    int pattaPending = 0;
    int disputed = 0;
    Map<String, int> landTypes = {};
    Map<String, int> locations = {};

    for (final record in records) {
      totalArea += record.area;

      // Count patta status based on legal status
      switch (record.legalStatus) {
        case 'received':
        case 'patta_received':
          pattaReceived++;
          break;
        case 'pending':
        case 'applied':
        case 'under_review':
          pattaPending++;
          break;
        default:
          break;
      }

      // Count land types
      final landType = record.landType;
      landTypes[landType] = (landTypes[landType] ?? 0) + 1;

      // Count locations
      final location = '${record.location.village}, ${record.location.mandal}';
      locations[location] = (locations[location] ?? 0) + 1;
    }

    return LandRecordStats(
      totalRecords: records.length,
      totalArea: totalArea,
      pattaReceivedCount: pattaReceived,
      pattaPendingCount: pattaPending,
      disputedCount: disputed,
      landTypeDistribution: landTypes,
      locationDistribution: locations,
    );
  }
}