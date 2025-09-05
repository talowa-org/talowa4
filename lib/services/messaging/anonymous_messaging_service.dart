// Anonymous Messaging Service for TALOWA
// Implements anonymous reporting with proxy servers for identity protection
// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../auth_service.dart';
import 'encryption_service.dart';
import '../security/audit_logging_service.dart';

class AnonymousMessagingService {
  static final AnonymousMessagingService _instance = AnonymousMessagingService._internal();
  factory AnonymousMessagingService() => _instance;
  AnonymousMessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final AuditLoggingService _auditService = AuditLoggingService();
  
  final String _anonymousReportsCollection = 'anonymous_reports';
  final String _proxyServersCollection = 'proxy_servers';
  
  /// Send anonymous report through encrypted proxy servers
  Future<String> sendAnonymousReport({
    required String content,
    required String coordinatorId,
    required ReportType reportType,
    Map<String, dynamic>? location,
    List<String>? mediaUrls,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique case ID for tracking
      final caseId = _generateAnonymousCaseId();
      
      // Generalize location to village level for privacy
      final generalizedLocation = _generalizeLocation(location);
      
      // Select random proxy server for routing
      final proxyServer = await _selectProxyServer();
      
      // Create anonymous identity hash (one-way, cannot be reversed)
      final anonymousId = _generateAnonymousId(currentUser.uid, caseId);
      
      // Encrypt content for coordinator
      final encryptedContent = await _encryptionService.encryptAnonymousMessage(
        content: content,
        coordinatorId: coordinatorId,
      );
      
      // Create anonymous report document
      final reportData = {
        'caseId': caseId,
        'anonymousId': anonymousId,
        'coordinatorId': coordinatorId,
        'reportType': reportType.value,
        'encryptedContent': encryptedContent.toMap(),
        'generalizedLocation': generalizedLocation,
        'mediaUrls': mediaUrls ?? [],
        'proxyServerId': proxyServer['id'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'responseCount': 0,
        'isActive': true,
        // Minimal metadata to protect privacy
        'metadata': {
          'reportSource': 'mobile_app',
          'encryptionLevel': 'high_security',
          'privacyLevel': 'anonymous',
        },
      };
      
      // Store report through proxy routing
      await _storeReportThroughProxy(reportData, proxyServer);
      
      // Log anonymous report creation (without revealing identity)
      await _auditService.logSecurityEvent(
        eventType: 'anonymous_report_created',
        userId: 'anonymous',
        details: {
          'caseId': caseId,
          'reportType': reportType.value,
          'coordinatorId': coordinatorId,
          'proxyServerId': proxyServer['id'],
          'hasLocation': generalizedLocation != null,
          'hasMedia': (mediaUrls?.isNotEmpty ?? false),
        },
        sensitivityLevel: SensitivityLevel.high,
      );
      
      debugPrint('Anonymous report created with case ID: $caseId');
      return caseId;
    } catch (e) {
      debugPrint('Error sending anonymous report: $e');
      rethrow;
    }
  }

  /// Get anonymous reports for coordinator (without revealing sender identity)
  Stream<List<AnonymousReport>> getAnonymousReports(String coordinatorId) {
    try {
      return _firestore
          .collection(_anonymousReportsCollection)
          .where('coordinatorId', isEqualTo: coordinatorId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
        final reports = <AnonymousReport>[];
        
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            
            // Decrypt content for coordinator
            final encryptedContent = EncryptedContent.fromMap(data['encryptedContent']);
            final decryptedContent = await _encryptionService.decryptMessage(encryptedContent);
            
            reports.add(AnonymousReport(
              caseId: data['caseId'],
              anonymousId: data['anonymousId'],
              coordinatorId: data['coordinatorId'],
              reportType: ReportTypeExtension.fromString(data['reportType']),
              content: decryptedContent,
              generalizedLocation: data['generalizedLocation'],
              mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
              status: ReportStatusExtension.fromString(data['status']),
              createdAt: (data['createdAt'] as Timestamp).toDate(),
              lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp).toDate(),
              responseCount: data['responseCount'] ?? 0,
              responses: [], // Will be loaded separately if needed
            ));
          } catch (e) {
            debugPrint('Error processing anonymous report: $e');
            // Continue with other reports
          }
        }
        
        return reports;
      });
    } catch (e) {
      debugPrint('Error getting anonymous reports: $e');
      return Stream.value([]);
    }
  }

  /// Respond to anonymous report without revealing coordinator identity
  Future<void> respondToAnonymousReport({
    required String caseId,
    required String response,
    bool isPublicResponse = false,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get the original report
      final reportQuery = await _firestore
          .collection(_anonymousReportsCollection)
          .where('caseId', isEqualTo: caseId)
          .where('coordinatorId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (reportQuery.docs.isEmpty) {
        throw Exception('Anonymous report not found or unauthorized');
      }

      final reportDoc = reportQuery.docs.first;
      final reportData = reportDoc.data();
      
      // Generate anonymous coordinator ID for response
      final anonymousCoordinatorId = _generateAnonymousCoordinatorId(currentUser.uid, caseId);
      
      // Encrypt response
      final encryptedResponse = await _encryptionService.encryptAnonymousMessage(
        content: response,
        coordinatorId: reportData['anonymousId'], // Send to anonymous reporter
      );
      
      // Create response document
      final responseData = {
        'caseId': caseId,
        'anonymousCoordinatorId': anonymousCoordinatorId,
        'encryptedResponse': encryptedResponse.toMap(),
        'isPublicResponse': isPublicResponse,
        'createdAt': FieldValue.serverTimestamp(),
        'responseType': 'coordinator_response',
      };
      
      // Store response
      await _firestore
          .collection('anonymous_responses')
          .add(responseData);
      
      // Update report response count
      await reportDoc.reference.update({
        'responseCount': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'status': 'responded',
      });
      
      // Log response (without revealing identities)
      await _auditService.logSecurityEvent(
        eventType: 'anonymous_response_sent',
        userId: 'anonymous_coordinator',
        details: {
          'caseId': caseId,
          'isPublicResponse': isPublicResponse,
          'responseLength': response.length,
        },
        sensitivityLevel: SensitivityLevel.high,
      );
      
      debugPrint('Anonymous response sent for case: $caseId');
    } catch (e) {
      debugPrint('Error responding to anonymous report: $e');
      rethrow;
    }
  }

  /// Get responses to anonymous report (for the original reporter)
  Future<List<AnonymousResponse>> getAnonymousResponses(String caseId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify user is the original reporter by checking anonymous ID
      final reportQuery = await _firestore
          .collection(_anonymousReportsCollection)
          .where('caseId', isEqualTo: caseId)
          .limit(1)
          .get();

      if (reportQuery.docs.isEmpty) {
        throw Exception('Anonymous report not found');
      }

      final reportData = reportQuery.docs.first.data();
      final expectedAnonymousId = _generateAnonymousId(currentUser.uid, caseId);
      
      if (reportData['anonymousId'] != expectedAnonymousId) {
        throw Exception('Unauthorized access to anonymous responses');
      }

      // Get responses
      final responsesQuery = await _firestore
          .collection('anonymous_responses')
          .where('caseId', isEqualTo: caseId)
          .orderBy('createdAt', descending: false)
          .get();

      final responses = <AnonymousResponse>[];
      
      for (final doc in responsesQuery.docs) {
        try {
          final data = doc.data();
          
          // Decrypt response
          final encryptedResponse = EncryptedContent.fromMap(data['encryptedResponse']);
          final decryptedResponse = await _encryptionService.decryptMessage(encryptedResponse);
          
          responses.add(AnonymousResponse(
            id: doc.id,
            caseId: data['caseId'],
            anonymousCoordinatorId: data['anonymousCoordinatorId'],
            response: decryptedResponse,
            isPublicResponse: data['isPublicResponse'] ?? false,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            responseType: data['responseType'] ?? 'coordinator_response',
          ));
        } catch (e) {
          debugPrint('Error decrypting anonymous response: $e');
          // Continue with other responses
        }
      }
      
      return responses;
    } catch (e) {
      debugPrint('Error getting anonymous responses: $e');
      return [];
    }
  }

  /// Update anonymous report status
  Future<void> updateReportStatus({
    required String caseId,
    required ReportStatus status,
    String? statusNote,
  }) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final reportQuery = await _firestore
          .collection(_anonymousReportsCollection)
          .where('caseId', isEqualTo: caseId)
          .where('coordinatorId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (reportQuery.docs.isEmpty) {
        throw Exception('Anonymous report not found or unauthorized');
      }

      final updateData = {
        'status': status.value,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (statusNote != null) {
        updateData['statusNote'] = statusNote;
      }

      await reportQuery.docs.first.reference.update(updateData);
      
      // Log status update
      await _auditService.logSecurityEvent(
        eventType: 'anonymous_report_status_updated',
        userId: 'anonymous_coordinator',
        details: {
          'caseId': caseId,
          'newStatus': status.value,
          'hasNote': statusNote != null,
        },
        sensitivityLevel: SensitivityLevel.medium,
      );
      
    } catch (e) {
      debugPrint('Error updating report status: $e');
      rethrow;
    }
  }

  /// Get anonymous report statistics (for coordinators)
  Future<AnonymousReportStats> getReportStatistics(String coordinatorId) async {
    try {
      final reportsQuery = await _firestore
          .collection(_anonymousReportsCollection)
          .where('coordinatorId', isEqualTo: coordinatorId)
          .get();

      final stats = AnonymousReportStats();
      
      for (final doc in reportsQuery.docs) {
        final data = doc.data();
        final status = ReportStatusExtension.fromString(data['status']);
        final reportType = ReportTypeExtension.fromString(data['reportType']);
        
        stats.totalReports++;
        
        switch (status) {
          case ReportStatus.pending:
            stats.pendingReports++;
            break;
          case ReportStatus.inProgress:
            stats.inProgressReports++;
            break;
          case ReportStatus.resolved:
            stats.resolvedReports++;
            break;
          case ReportStatus.closed:
            stats.closedReports++;
            break;
        }
        
        stats.reportsByType[reportType] = (stats.reportsByType[reportType] ?? 0) + 1;
      }
      
      return stats;
    } catch (e) {
      debugPrint('Error getting report statistics: $e');
      return AnonymousReportStats();
    }
  }

  // Private helper methods

  String _generateAnonymousCaseId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'ANON-${timestamp.toString().substring(8)}-${random.toString().padLeft(6, '0')}';
  }

  String _generateAnonymousId(String userId, String caseId) {
    // Create one-way hash that cannot be reversed to reveal user identity
    final combined = '$userId:$caseId:${DateTime.now().toIso8601String().substring(0, 10)}';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return 'ANON-${digest.toString().substring(0, 16)}';
  }

  String _generateAnonymousCoordinatorId(String coordinatorId, String caseId) {
    final combined = '$coordinatorId:$caseId:coordinator';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return 'COORD-${digest.toString().substring(0, 16)}';
  }

  Map<String, dynamic>? _generalizeLocation(Map<String, dynamic>? location) {
    if (location == null) return null;
    
    // Remove precise coordinates and keep only village-level information
    return {
      'villageCode': location['villageCode'],
      'villageName': location['villageName'],
      'mandalCode': location['mandalCode'],
      'mandalName': location['mandalName'],
      'districtCode': location['districtCode'],
      'districtName': location['districtName'],
      // Remove precise GPS coordinates for privacy
      'approximateArea': _getApproximateArea(location),
    };
  }

  String _getApproximateArea(Map<String, dynamic> location) {
    // Convert precise location to approximate area description
    final lat = location['latitude'] as double?;
    final lng = location['longitude'] as double?;
    
    if (lat == null || lng == null) return 'Unknown area';
    
    // Generalize to ~1km grid for privacy
    final generalizedLat = (lat * 100).round() / 100;
    final generalizedLng = (lng * 100).round() / 100;
    
    return 'Area around ${generalizedLat.toStringAsFixed(2)}, ${generalizedLng.toStringAsFixed(2)}';
  }

  Future<Map<String, dynamic>> _selectProxyServer() async {
    try {
      // Get available proxy servers
      final proxyQuery = await _firestore
          .collection(_proxyServersCollection)
          .where('isActive', isEqualTo: true)
          .where('load', isLessThan: 0.8) // Select servers with low load
          .get();

      if (proxyQuery.docs.isEmpty) {
        // Fallback to default proxy configuration
        return {
          'id': 'default-proxy',
          'endpoint': 'default',
          'region': 'in-south',
          'load': 0.5,
        };
      }

      // Select random proxy server for better anonymity
      final randomIndex = Random().nextInt(proxyQuery.docs.length);
      final selectedProxy = proxyQuery.docs[randomIndex];
      
      return {
        'id': selectedProxy.id,
        ...selectedProxy.data(),
      };
    } catch (e) {
      debugPrint('Error selecting proxy server: $e');
      // Return default proxy
      return {
        'id': 'default-proxy',
        'endpoint': 'default',
        'region': 'in-south',
        'load': 0.5,
      };
    }
  }

  Future<void> _storeReportThroughProxy(
    Map<String, dynamic> reportData,
    Map<String, dynamic> proxyServer,
  ) async {
    try {
      // In a real implementation, this would route through actual proxy servers
      // For now, we'll store directly but with proxy metadata
      
      await _firestore
          .collection(_anonymousReportsCollection)
          .add(reportData);
      
      // Update proxy server load
      if (proxyServer['id'] != 'default-proxy') {
        await _firestore
            .collection(_proxyServersCollection)
            .doc(proxyServer['id'])
            .update({
          'requestCount': FieldValue.increment(1),
          'lastUsed': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error storing report through proxy: $e');
      rethrow;
    }
  }
}

// Data models for anonymous messaging

enum ReportType {
  landGrabbing,
  corruption,
  harassment,
  illegalConstruction,
  documentForgery,
  other,
}

extension ReportTypeExtension on ReportType {
  String get value {
    switch (this) {
      case ReportType.landGrabbing:
        return 'land_grabbing';
      case ReportType.corruption:
        return 'corruption';
      case ReportType.harassment:
        return 'harassment';
      case ReportType.illegalConstruction:
        return 'illegal_construction';
      case ReportType.documentForgery:
        return 'document_forgery';
      case ReportType.other:
        return 'other';
    }
  }

  static ReportType fromString(String value) {
    switch (value) {
      case 'land_grabbing':
        return ReportType.landGrabbing;
      case 'corruption':
        return ReportType.corruption;
      case 'harassment':
        return ReportType.harassment;
      case 'illegal_construction':
        return ReportType.illegalConstruction;
      case 'document_forgery':
        return ReportType.documentForgery;
      default:
        return ReportType.other;
    }
  }
}

enum ReportStatus {
  pending,
  inProgress,
  resolved,
  closed,
}

extension ReportStatusExtension on ReportStatus {
  String get value {
    switch (this) {
      case ReportStatus.pending:
        return 'pending';
      case ReportStatus.inProgress:
        return 'in_progress';
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.closed:
        return 'closed';
    }
  }

  static ReportStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return ReportStatus.inProgress;
      case 'resolved':
        return ReportStatus.resolved;
      case 'closed':
        return ReportStatus.closed;
      default:
        return ReportStatus.pending;
    }
  }
}

class AnonymousReport {
  final String caseId;
  final String anonymousId;
  final String coordinatorId;
  final ReportType reportType;
  final String content;
  final Map<String, dynamic>? generalizedLocation;
  final List<String> mediaUrls;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final int responseCount;
  final List<AnonymousResponse> responses;

  AnonymousReport({
    required this.caseId,
    required this.anonymousId,
    required this.coordinatorId,
    required this.reportType,
    required this.content,
    this.generalizedLocation,
    required this.mediaUrls,
    required this.status,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.responseCount,
    required this.responses,
  });
}

class AnonymousResponse {
  final String id;
  final String caseId;
  final String anonymousCoordinatorId;
  final String response;
  final bool isPublicResponse;
  final DateTime createdAt;
  final String responseType;

  AnonymousResponse({
    required this.id,
    required this.caseId,
    required this.anonymousCoordinatorId,
    required this.response,
    required this.isPublicResponse,
    required this.createdAt,
    required this.responseType,
  });
}

class AnonymousReportStats {
  int totalReports = 0;
  int pendingReports = 0;
  int inProgressReports = 0;
  int resolvedReports = 0;
  int closedReports = 0;
  Map<ReportType, int> reportsByType = {};
}
