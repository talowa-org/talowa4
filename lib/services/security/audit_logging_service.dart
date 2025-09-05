// Audit Logging Service for TALOWA
// Implements comprehensive audit logging for security monitoring and legal compliance
// Requirements: 10.2, 7.4

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../auth_service.dart';

class AuditLoggingService {
  static final AuditLoggingService _instance = AuditLoggingService._internal();
  factory AuditLoggingService() => _instance;
  AuditLoggingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  final String _auditLogsCollection = 'audit_logs';
  final String _securityEventsCollection = 'security_events';
  final String _complianceLogsCollection = 'compliance_logs';
  
  // Cache for device information
  Map<String, dynamic>? _deviceInfoCache;
  
  /// Log security-related events
  Future<void> logSecurityEvent({
    required String eventType,
    required String userId,
    required Map<String, dynamic> details,
    SensitivityLevel sensitivityLevel = SensitivityLevel.medium,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final timestamp = DateTime.now();
      
      final eventData = {
        'eventType': eventType,
        'userId': userId,
        'details': details,
        'sensitivityLevel': sensitivityLevel.value,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': deviceInfo,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'sessionId': _generateSessionId(),
        'eventId': _generateEventId(eventType, userId, timestamp),
        'source': 'mobile_app',
        'version': '1.0.0', // App version
      };
      
      // Store in security events collection
      await _firestore.collection(_securityEventsCollection).add(eventData);
      
      // Also store in main audit log if high sensitivity
      if (sensitivityLevel == SensitivityLevel.high || sensitivityLevel == SensitivityLevel.critical) {
        await _logAuditEvent(
          category: AuditCategory.security,
          action: eventType,
          userId: userId,
          details: details,
          sensitivityLevel: sensitivityLevel,
        );
      }
      
      debugPrint('Security event logged: $eventType for user: $userId');
    } catch (e) {
      debugPrint('Error logging security event: $e');
      // Don't rethrow to avoid breaking the main flow
    }
  }

  /// Log user actions for audit trail
  Future<void> logUserAction({
    required String action,
    required String userId,
    required Map<String, dynamic> details,
    String? targetUserId,
    String? resourceId,
    ActionResult result = ActionResult.success,
  }) async {
    try {
      await _logAuditEvent(
        category: AuditCategory.userAction,
        action: action,
        userId: userId,
        details: {
          ...details,
          'targetUserId': targetUserId,
          'resourceId': resourceId,
          'result': result.value,
        },
        sensitivityLevel: _getSensitivityForAction(action),
      );
    } catch (e) {
      debugPrint('Error logging user action: $e');
    }
  }

  /// Log data access events
  Future<void> logDataAccess({
    required String dataType,
    required String userId,
    required AccessType accessType,
    required String resourceId,
    Map<String, dynamic>? additionalDetails,
    bool isAuthorized = true,
  }) async {
    try {
      await _logAuditEvent(
        category: AuditCategory.dataAccess,
        action: '${accessType.value}_$dataType',
        userId: userId,
        details: {
          'dataType': dataType,
          'accessType': accessType.value,
          'resourceId': resourceId,
          'isAuthorized': isAuthorized,
          ...?additionalDetails,
        },
        sensitivityLevel: isAuthorized ? SensitivityLevel.low : SensitivityLevel.high,
      );
    } catch (e) {
      debugPrint('Error logging data access: $e');
    }
  }

  /// Log authentication events
  Future<void> logAuthEvent({
    required String eventType,
    required String userId,
    required Map<String, dynamic> details,
    bool isSuccessful = true,
  }) async {
    try {
      await _logAuditEvent(
        category: AuditCategory.authentication,
        action: eventType,
        userId: userId,
        details: {
          ...details,
          'isSuccessful': isSuccessful,
        },
        sensitivityLevel: isSuccessful ? SensitivityLevel.low : SensitivityLevel.medium,
      );
      
      // Also log as security event if failed
      if (!isSuccessful) {
        await logSecurityEvent(
          eventType: 'auth_failure',
          userId: userId,
          details: {
            'authEventType': eventType,
            ...details,
          },
          sensitivityLevel: SensitivityLevel.medium,
        );
      }
    } catch (e) {
      debugPrint('Error logging auth event: $e');
    }
  }

  /// Log legal compliance events
  Future<void> logComplianceEvent({
    required String eventType,
    required String userId,
    required Map<String, dynamic> details,
    ComplianceType complianceType = ComplianceType.dataProtection,
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      
      final complianceData = {
        'eventType': eventType,
        'userId': userId,
        'details': details,
        'complianceType': complianceType.value,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': deviceInfo,
        'legalBasis': _getLegalBasisForEvent(eventType),
        'retentionPeriod': _getRetentionPeriodForEvent(eventType),
        'dataClassification': _getDataClassificationForEvent(eventType),
      };
      
      await _firestore.collection(_complianceLogsCollection).add(complianceData);
      
      // Also log in main audit trail
      await _logAuditEvent(
        category: AuditCategory.compliance,
        action: eventType,
        userId: userId,
        details: details,
        sensitivityLevel: SensitivityLevel.high,
      );
      
    } catch (e) {
      debugPrint('Error logging compliance event: $e');
    }
  }

  /// Log administrative actions
  Future<void> logAdminAction({
    required String action,
    required String adminUserId,
    required String targetUserId,
    required Map<String, dynamic> details,
    String? justification,
  }) async {
    try {
      await _logAuditEvent(
        category: AuditCategory.administration,
        action: action,
        userId: adminUserId,
        details: {
          ...details,
          'targetUserId': targetUserId,
          'justification': justification,
          'adminLevel': await _getAdminLevel(adminUserId),
        },
        sensitivityLevel: SensitivityLevel.high,
      );
      
      // Also log as security event for high-risk admin actions
      if (_isHighRiskAdminAction(action)) {
        await logSecurityEvent(
          eventType: 'high_risk_admin_action',
          userId: adminUserId,
          details: {
            'adminAction': action,
            'targetUserId': targetUserId,
            'justification': justification,
          },
          sensitivityLevel: SensitivityLevel.critical,
        );
      }
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  /// Get audit logs with filtering
  Future<List<AuditLogEntry>> getAuditLogs({
    String? userId,
    AuditCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    SensitivityLevel? minSensitivity,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection(_auditLogsCollection);
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      if (category != null) {
        query = query.where('category', isEqualTo: category.value);
      }
      
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      query = query.orderBy('timestamp', descending: true).limit(limit);
      
      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AuditLogEntry.fromMap(doc.id, data);
      }).where((entry) {
        if (minSensitivity != null) {
          return entry.sensitivityLevel.index >= minSensitivity.index;
        }
        return true;
      }).toList();
    } catch (e) {
      debugPrint('Error getting audit logs: $e');
      return [];
    }
  }

  /// Get security events with filtering
  Future<List<SecurityEvent>> getSecurityEvents({
    String? userId,
    String? eventType,
    DateTime? startDate,
    DateTime? endDate,
    SensitivityLevel? minSensitivity,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection(_securityEventsCollection);
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      if (eventType != null) {
        query = query.where('eventType', isEqualTo: eventType);
      }
      
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      query = query.orderBy('timestamp', descending: true).limit(limit);
      
      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SecurityEvent.fromMap(doc.id, data);
      }).where((event) {
        if (minSensitivity != null) {
          return event.sensitivityLevel.index >= minSensitivity.index;
        }
        return true;
      }).toList();
    } catch (e) {
      debugPrint('Error getting security events: $e');
      return [];
    }
  }

  /// Generate audit report
  Future<AuditReport> generateAuditReport({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
    List<AuditCategory>? categories,
  }) async {
    try {
      final logs = await getAuditLogs(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
        limit: 10000,
      );
      
      final filteredLogs = categories != null 
          ? logs.where((log) => categories.contains(log.category)).toList()
          : logs;
      
      final report = AuditReport(
        startDate: startDate,
        endDate: endDate,
        totalEvents: filteredLogs.length,
        eventsByCategory: _groupEventsByCategory(filteredLogs),
        eventsBySensitivity: _groupEventsBySensitivity(filteredLogs),
        topUsers: _getTopUsersByActivity(filteredLogs),
        securityIncidents: await _getSecurityIncidents(startDate, endDate),
        complianceEvents: await _getComplianceEvents(startDate, endDate),
        generatedAt: DateTime.now(),
      );
      
      // Log report generation
      await logAdminAction(
        action: 'audit_report_generated',
        adminUserId: AuthService.currentUser?.uid ?? 'system',
        targetUserId: userId ?? 'all_users',
        details: {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'totalEvents': report.totalEvents,
          'categories': categories?.map((c) => c.value).toList(),
        },
      );
      
      return report;
    } catch (e) {
      debugPrint('Error generating audit report: $e');
      rethrow;
    }
  }

  /// Clean up old audit logs based on retention policy
  Future<void> cleanupOldLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 365 * 7)); // 7 years retention
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);
      
      // Clean up audit logs
      final oldAuditLogs = await _firestore
          .collection(_auditLogsCollection)
          .where('timestamp', isLessThan: cutoffTimestamp)
          .get();
      
      // Clean up security events (shorter retention)
      final securityCutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 365 * 2))); // 2 years
      final oldSecurityEvents = await _firestore
          .collection(_securityEventsCollection)
          .where('timestamp', isLessThan: securityCutoff)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in oldAuditLogs.docs) {
        batch.delete(doc.reference);
      }
      
      for (final doc in oldSecurityEvents.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      debugPrint('Cleaned up ${oldAuditLogs.docs.length} old audit logs and ${oldSecurityEvents.docs.length} old security events');
    } catch (e) {
      debugPrint('Error cleaning up old logs: $e');
    }
  }

  // Private helper methods

  Future<void> _logAuditEvent({
    required AuditCategory category,
    required String action,
    required String userId,
    required Map<String, dynamic> details,
    required SensitivityLevel sensitivityLevel,
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      
      final auditData = {
        'category': category.value,
        'action': action,
        'userId': userId,
        'details': details,
        'sensitivityLevel': sensitivityLevel.value,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': deviceInfo,
        'sessionId': _generateSessionId(),
        'eventId': _generateEventId(action, userId, DateTime.now()),
        'source': 'mobile_app',
        'version': '1.0.0',
      };
      
      await _firestore.collection(_auditLogsCollection).add(auditData);
    } catch (e) {
      debugPrint('Error logging audit event: $e');
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    if (_deviceInfoCache != null) {
      return _deviceInfoCache!;
    }
    
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceInfoCache = {
          'platform': 'android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'fingerprint': androidInfo.fingerprint.substring(0, 16), // Truncated for privacy
        };
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceInfoCache = {
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemVersion': iosInfo.systemVersion,
          'identifierForVendor': iosInfo.identifierForVendor?.substring(0, 16), // Truncated for privacy
        };
      } else {
        _deviceInfoCache = {
          'platform': 'unknown',
          'model': 'unknown',
        };
      }
      
      return _deviceInfoCache!;
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return {
        'platform': 'unknown',
        'error': e.toString(),
      };
    }
  }

  String _generateSessionId() {
    // Generate a session ID based on current user and timestamp
    final user = AuthService.currentUser;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${user?.uid ?? 'anonymous'}_$timestamp'.hashCode.toString();
  }

  String _generateEventId(String action, String userId, DateTime timestamp) {
    final combined = '$action:$userId:${timestamp.millisecondsSinceEpoch}';
    return combined.hashCode.abs().toString();
  }

  SensitivityLevel _getSensitivityForAction(String action) {
    const highSensitivityActions = [
      'delete_user',
      'change_role',
      'access_sensitive_data',
      'export_data',
      'admin_login',
    ];
    
    const mediumSensitivityActions = [
      'login',
      'logout',
      'update_profile',
      'send_message',
      'create_group',
    ];
    
    if (highSensitivityActions.contains(action)) {
      return SensitivityLevel.high;
    } else if (mediumSensitivityActions.contains(action)) {
      return SensitivityLevel.medium;
    } else {
      return SensitivityLevel.low;
    }
  }

  String _getLegalBasisForEvent(String eventType) {
    // Map event types to legal basis under data protection laws
    const legalBasisMap = {
      'data_export': 'Article 20 - Right to data portability',
      'data_deletion': 'Article 17 - Right to erasure',
      'consent_given': 'Article 6(1)(a) - Consent',
      'legitimate_interest': 'Article 6(1)(f) - Legitimate interests',
    };
    
    return legalBasisMap[eventType] ?? 'Article 6(1)(b) - Contract performance';
  }

  int _getRetentionPeriodForEvent(String eventType) {
    // Return retention period in days
    const retentionMap = {
      'security_incident': 2555, // 7 years
      'financial_transaction': 2555, // 7 years
      'legal_case_data': 3650, // 10 years
      'user_activity': 1095, // 3 years
    };
    
    return retentionMap[eventType] ?? 365; // Default 1 year
  }

  String _getDataClassificationForEvent(String eventType) {
    const classificationMap = {
      'personal_data_access': 'Personal Data',
      'sensitive_data_access': 'Sensitive Personal Data',
      'legal_data_access': 'Legal Data',
      'financial_data_access': 'Financial Data',
    };
    
    return classificationMap[eventType] ?? 'General Data';
  }

  Future<String> _getAdminLevel(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['role'] ?? 'user';
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  bool _isHighRiskAdminAction(String action) {
    const highRiskActions = [
      'delete_user_data',
      'change_user_role',
      'access_all_messages',
      'disable_user_account',
      'export_user_data',
    ];
    
    return highRiskActions.contains(action);
  }

  Map<AuditCategory, int> _groupEventsByCategory(List<AuditLogEntry> logs) {
    final grouped = <AuditCategory, int>{};
    for (final log in logs) {
      grouped[log.category] = (grouped[log.category] ?? 0) + 1;
    }
    return grouped;
  }

  Map<SensitivityLevel, int> _groupEventsBySensitivity(List<AuditLogEntry> logs) {
    final grouped = <SensitivityLevel, int>{};
    for (final log in logs) {
      grouped[log.sensitivityLevel] = (grouped[log.sensitivityLevel] ?? 0) + 1;
    }
    return grouped;
  }

  List<UserActivity> _getTopUsersByActivity(List<AuditLogEntry> logs) {
    final userCounts = <String, int>{};
    for (final log in logs) {
      userCounts[log.userId] = (userCounts[log.userId] ?? 0) + 1;
    }
    
    final sorted = userCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(10).map((entry) => UserActivity(
      userId: entry.key,
      activityCount: entry.value,
    )).toList();
  }

  Future<List<SecurityIncident>> _getSecurityIncidents(DateTime startDate, DateTime endDate) async {
    try {
      final incidents = await _firestore
          .collection(_securityEventsCollection)
          .where('sensitivityLevel', isEqualTo: SensitivityLevel.critical.value)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      return incidents.docs.map((doc) {
        final data = doc.data();
        return SecurityIncident(
          id: doc.id,
          eventType: data['eventType'],
          userId: data['userId'],
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          details: Map<String, dynamic>.from(data['details'] ?? {}),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting security incidents: $e');
      return [];
    }
  }

  Future<List<ComplianceEvent>> _getComplianceEvents(DateTime startDate, DateTime endDate) async {
    try {
      final events = await _firestore
          .collection(_complianceLogsCollection)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      return events.docs.map((doc) {
        final data = doc.data();
        return ComplianceEvent(
          id: doc.id,
          eventType: data['eventType'],
          userId: data['userId'],
          complianceType: ComplianceTypeExtension.fromString(data['complianceType']),
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          details: Map<String, dynamic>.from(data['details'] ?? {}),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting compliance events: $e');
      return [];
    }
  }
}

// Enums and data models

enum SensitivityLevel { low, medium, high, critical }

extension SensitivityLevelExtension on SensitivityLevel {
  String get value {
    switch (this) {
      case SensitivityLevel.low:
        return 'low';
      case SensitivityLevel.medium:
        return 'medium';
      case SensitivityLevel.high:
        return 'high';
      case SensitivityLevel.critical:
        return 'critical';
    }
  }

  static SensitivityLevel fromString(String value) {
    switch (value) {
      case 'medium':
        return SensitivityLevel.medium;
      case 'high':
        return SensitivityLevel.high;
      case 'critical':
        return SensitivityLevel.critical;
      default:
        return SensitivityLevel.low;
    }
  }
}

enum AuditCategory { 
  authentication, 
  userAction, 
  dataAccess, 
  security, 
  administration, 
  compliance 
}

extension AuditCategoryExtension on AuditCategory {
  String get value {
    switch (this) {
      case AuditCategory.authentication:
        return 'authentication';
      case AuditCategory.userAction:
        return 'user_action';
      case AuditCategory.dataAccess:
        return 'data_access';
      case AuditCategory.security:
        return 'security';
      case AuditCategory.administration:
        return 'administration';
      case AuditCategory.compliance:
        return 'compliance';
    }
  }

  static AuditCategory fromString(String value) {
    switch (value) {
      case 'authentication':
        return AuditCategory.authentication;
      case 'user_action':
        return AuditCategory.userAction;
      case 'data_access':
        return AuditCategory.dataAccess;
      case 'security':
        return AuditCategory.security;
      case 'administration':
        return AuditCategory.administration;
      case 'compliance':
        return AuditCategory.compliance;
      default:
        return AuditCategory.userAction;
    }
  }
}

enum AccessType { read, write, delete, update, create }

extension AccessTypeExtension on AccessType {
  String get value {
    switch (this) {
      case AccessType.read:
        return 'read';
      case AccessType.write:
        return 'write';
      case AccessType.delete:
        return 'delete';
      case AccessType.update:
        return 'update';
      case AccessType.create:
        return 'create';
    }
  }
}

enum ActionResult { success, failure, partial }

extension ActionResultExtension on ActionResult {
  String get value {
    switch (this) {
      case ActionResult.success:
        return 'success';
      case ActionResult.failure:
        return 'failure';
      case ActionResult.partial:
        return 'partial';
    }
  }
}

enum ComplianceType { dataProtection, privacy, legal, financial }

extension ComplianceTypeExtension on ComplianceType {
  String get value {
    switch (this) {
      case ComplianceType.dataProtection:
        return 'data_protection';
      case ComplianceType.privacy:
        return 'privacy';
      case ComplianceType.legal:
        return 'legal';
      case ComplianceType.financial:
        return 'financial';
    }
  }

  static ComplianceType fromString(String value) {
    switch (value) {
      case 'privacy':
        return ComplianceType.privacy;
      case 'legal':
        return ComplianceType.legal;
      case 'financial':
        return ComplianceType.financial;
      default:
        return ComplianceType.dataProtection;
    }
  }
}

// Data models

class AuditLogEntry {
  final String id;
  final AuditCategory category;
  final String action;
  final String userId;
  final Map<String, dynamic> details;
  final SensitivityLevel sensitivityLevel;
  final DateTime timestamp;
  final Map<String, dynamic> deviceInfo;
  final String sessionId;
  final String eventId;

  AuditLogEntry({
    required this.id,
    required this.category,
    required this.action,
    required this.userId,
    required this.details,
    required this.sensitivityLevel,
    required this.timestamp,
    required this.deviceInfo,
    required this.sessionId,
    required this.eventId,
  });

  factory AuditLogEntry.fromMap(String id, Map<String, dynamic> data) {
    return AuditLogEntry(
      id: id,
      category: AuditCategoryExtension.fromString(data['category']),
      action: data['action'],
      userId: data['userId'],
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      sensitivityLevel: SensitivityLevelExtension.fromString(data['sensitivityLevel']),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      deviceInfo: Map<String, dynamic>.from(data['deviceInfo'] ?? {}),
      sessionId: data['sessionId'] ?? '',
      eventId: data['eventId'] ?? '',
    );
  }
}

class SecurityEvent {
  final String id;
  final String eventType;
  final String userId;
  final Map<String, dynamic> details;
  final SensitivityLevel sensitivityLevel;
  final DateTime timestamp;
  final Map<String, dynamic> deviceInfo;

  SecurityEvent({
    required this.id,
    required this.eventType,
    required this.userId,
    required this.details,
    required this.sensitivityLevel,
    required this.timestamp,
    required this.deviceInfo,
  });

  factory SecurityEvent.fromMap(String id, Map<String, dynamic> data) {
    return SecurityEvent(
      id: id,
      eventType: data['eventType'],
      userId: data['userId'],
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      sensitivityLevel: SensitivityLevelExtension.fromString(data['sensitivityLevel']),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      deviceInfo: Map<String, dynamic>.from(data['deviceInfo'] ?? {}),
    );
  }
}

class AuditReport {
  final DateTime startDate;
  final DateTime endDate;
  final int totalEvents;
  final Map<AuditCategory, int> eventsByCategory;
  final Map<SensitivityLevel, int> eventsBySensitivity;
  final List<UserActivity> topUsers;
  final List<SecurityIncident> securityIncidents;
  final List<ComplianceEvent> complianceEvents;
  final DateTime generatedAt;

  AuditReport({
    required this.startDate,
    required this.endDate,
    required this.totalEvents,
    required this.eventsByCategory,
    required this.eventsBySensitivity,
    required this.topUsers,
    required this.securityIncidents,
    required this.complianceEvents,
    required this.generatedAt,
  });
}

class UserActivity {
  final String userId;
  final int activityCount;

  UserActivity({
    required this.userId,
    required this.activityCount,
  });
}

class SecurityIncident {
  final String id;
  final String eventType;
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  SecurityIncident({
    required this.id,
    required this.eventType,
    required this.userId,
    required this.timestamp,
    required this.details,
  });
}

class ComplianceEvent {
  final String id;
  final String eventType;
  final String userId;
  final ComplianceType complianceType;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  ComplianceEvent({
    required this.id,
    required this.eventType,
    required this.userId,
    required this.complianceType,
    required this.timestamp,
    required this.details,
  });
}
