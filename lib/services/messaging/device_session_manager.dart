// Device Session Manager for TALOWA
// Implements Task 9: Cross-device compatibility and data synchronization - Device Session Management
// Reference: in-app-communication/requirements.md - Requirements 8.1, 8.6

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import '../auth_service.dart';

class DeviceSessionManager {
  static final DeviceSessionManager _instance = DeviceSessionManager._internal();
  factory DeviceSessionManager() => _instance;
  DeviceSessionManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  final StreamController<List<DeviceSession>> _deviceSessionsController = 
      StreamController<List<DeviceSession>>.broadcast();
  final StreamController<DeviceSessionEvent> _sessionEventsController = 
      StreamController<DeviceSessionEvent>.broadcast();
  
  StreamSubscription<QuerySnapshot>? _sessionsSubscription;
  String? _currentDeviceId;
  DeviceSession? _currentSession;
  
  // Configuration
  static const String _deviceIdKey = 'device_session_id';
  static const String _sessionCollectionName = 'device_sessions';

  static const int _maxDevicesPerUser = 10;
  
  // Getters
  Stream<List<DeviceSession>> get deviceSessionsStream => _deviceSessionsController.stream;
  Stream<DeviceSessionEvent> get sessionEventsStream => _sessionEventsController.stream;
  String? get currentDeviceId => _currentDeviceId;
  DeviceSession? get currentSession => _currentSession;

  /// Initialize device session manager
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Device Session Manager');
      
      await _initializeDeviceId();
      await _createOrUpdateCurrentSession();
      await _startSessionMonitoring();
      
      debugPrint('Device Session Manager initialized with device ID: $_currentDeviceId');
    } catch (e) {
      debugPrint('Error initializing device session manager: $e');
      rethrow;
    }
  }

  /// Create new device session for current user
  Future<DeviceSession> createDeviceSession() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final deviceInfo = await _getDeviceInfo();
      final sessionId = _generateSessionId();
      
      final session = DeviceSession(
        id: sessionId,
        userId: currentUser.uid,
        deviceId: _currentDeviceId!,
        deviceName: deviceInfo.deviceName,
        deviceType: deviceInfo.deviceType,
        platform: deviceInfo.platform,
        appVersion: deviceInfo.appVersion,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isActive: true,
        ipAddress: await _getIpAddress(),
        location: await _getLocationInfo(),
        metadata: deviceInfo.metadata,
      );

      // Check device limit
      await _enforceDeviceLimit(currentUser.uid);
      
      // Save session to Firestore
      await _firestore
          .collection(_sessionCollectionName)
          .doc(sessionId)
          .set(session.toFirestore());

      _currentSession = session;
      
      // Notify session created
      _sessionEventsController.add(DeviceSessionEvent(
        type: SessionEventType.sessionCreated,
        session: session,
        timestamp: DateTime.now(),
      ));

      debugPrint('Created device session: ${session.id}');
      return session;
    } catch (e) {
      debugPrint('Error creating device session: $e');
      rethrow;
    }
  }

  /// Update current session activity
  Future<void> updateSessionActivity() async {
    try {
      if (_currentSession == null) return;

      final updatedSession = _currentSession!.copyWith(
        lastActiveAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_sessionCollectionName)
          .doc(_currentSession!.id)
          .update({
        'lastActiveAt': Timestamp.fromDate(updatedSession.lastActiveAt),
        'isActive': true,
      });

      _currentSession = updatedSession;
    } catch (e) {
      debugPrint('Error updating session activity: $e');
    }
  }

  /// Get all active sessions for current user
  Future<List<DeviceSession>> getUserSessions() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(_sessionCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('lastActiveAt', descending: true)
          .get();

      final sessions = snapshot.docs
          .map((doc) => DeviceSession.fromFirestore(doc))
          .toList();

      return sessions;
    } catch (e) {
      debugPrint('Error getting user sessions: $e');
      return [];
    }
  }

  /// Terminate specific device session
  Future<void> terminateSession(String sessionId) async {
    try {
      await _firestore
          .collection(_sessionCollectionName)
          .doc(sessionId)
          .update({
        'isActive': false,
        'terminatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // If terminating current session, clear local data
      if (_currentSession?.id == sessionId) {
        await _clearLocalSessionData();
      }

      // Notify session terminated
      _sessionEventsController.add(DeviceSessionEvent(
        type: SessionEventType.sessionTerminated,
        sessionId: sessionId,
        timestamp: DateTime.now(),
      ));

      debugPrint('Terminated session: $sessionId');
    } catch (e) {
      debugPrint('Error terminating session: $e');
      rethrow;
    }
  }

  /// Terminate all other sessions except current
  Future<void> terminateAllOtherSessions() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_sessionCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .get();

      int terminatedCount = 0;
      for (final doc in snapshot.docs) {
        if (doc.id != _currentSession?.id) {
          batch.update(doc.reference, {
            'isActive': false,
            'terminatedAt': Timestamp.fromDate(DateTime.now()),
          });
          terminatedCount++;
        }
      }

      await batch.commit();

      // Notify sessions terminated
      _sessionEventsController.add(DeviceSessionEvent(
        type: SessionEventType.allOtherSessionsTerminated,
        metadata: {'terminatedCount': terminatedCount},
        timestamp: DateTime.now(),
      ));

      debugPrint('Terminated $terminatedCount other sessions');
    } catch (e) {
      debugPrint('Error terminating all other sessions: $e');
      rethrow;
    }
  }

  /// Perform secure logout with session cleanup
  Future<void> performSecureLogout({
    bool terminateAllSessions = false,
    bool clearLocalData = true,
  }) async {
    try {
      debugPrint('Performing secure logout...');

      if (terminateAllSessions) {
        await terminateAllOtherSessions();
      }

      // Terminate current session
      if (_currentSession != null) {
        await terminateSession(_currentSession!.id);
      }

      if (clearLocalData) {
        await _clearAllLocalData();
      }

      // Stop session monitoring
      await _stopSessionMonitoring();

      // Notify logout completed
      _sessionEventsController.add(DeviceSessionEvent(
        type: SessionEventType.logoutCompleted,
        timestamp: DateTime.now(),
      ));

      debugPrint('Secure logout completed');
    } catch (e) {
      debugPrint('Error during secure logout: $e');
      rethrow;
    }
  }

  /// Check if device is trusted
  Future<bool> isDeviceTrusted(String deviceId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _firestore
          .collection(_sessionCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .where('deviceId', isEqualTo: deviceId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking device trust: $e');
      return false;
    }
  }

  /// Get session statistics
  Future<SessionStatistics> getSessionStatistics() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection(_sessionCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final allSessions = snapshot.docs
          .map((doc) => DeviceSession.fromFirestore(doc))
          .toList();

      final activeSessions = allSessions.where((s) => s.isActive).toList();
      final recentSessions = allSessions
          .where((s) => s.lastActiveAt.isAfter(
              DateTime.now().subtract(const Duration(days: 7))))
          .toList();

      return SessionStatistics(
        totalSessions: allSessions.length,
        activeSessions: activeSessions.length,
        recentSessions: recentSessions.length,
        currentSession: _currentSession,
        deviceTypes: _getDeviceTypeDistribution(allSessions),
        platforms: _getPlatformDistribution(allSessions),
      );
    } catch (e) {
      debugPrint('Error getting session statistics: $e');
      return SessionStatistics(
        totalSessions: 0,
        activeSessions: 0,
        recentSessions: 0,
        currentSession: null,
        deviceTypes: {},
        platforms: {},
      );
    }
  }

  // Private helper methods

  /// Initialize device ID
  Future<void> _initializeDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentDeviceId = prefs.getString(_deviceIdKey);

      if (_currentDeviceId == null) {
        _currentDeviceId = await _generateDeviceId();
        await prefs.setString(_deviceIdKey, _currentDeviceId!);
      }
    } catch (e) {
      debugPrint('Error initializing device ID: $e');
      rethrow;
    }
  }

  /// Generate unique device ID
  Future<String> _generateDeviceId() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecondsSinceEpoch;
      
      final input = '${deviceInfo.deviceName}_${deviceInfo.platform}_${timestamp}_$random';
      final bytes = utf8.encode(input);
      final digest = sha256.convert(bytes);
      
      return digest.toString().substring(0, 32);
    } catch (e) {
      debugPrint('Error generating device ID: $e');
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Generate session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    return 'session_${_currentDeviceId}_${timestamp}_$random';
  }

  /// Get device information
  Future<DeviceInfo> _getDeviceInfo() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return DeviceInfo(
          deviceName: '${webInfo.browserName} on ${webInfo.platform}',
          deviceType: DeviceType.web,
          platform: 'web',
          appVersion: '1.0.0', // Get from package info
          metadata: {
            'browser': webInfo.browserName,
            'userAgent': webInfo.userAgent,
            'platform': webInfo.platform,
          },
        );
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return DeviceInfo(
          deviceName: '${androidInfo.brand} ${androidInfo.model}',
          deviceType: DeviceType.mobile,
          platform: 'android',
          appVersion: '1.0.0', // Get from package info
          metadata: {
            'brand': androidInfo.brand,
            'model': androidInfo.model,
            'version': androidInfo.version.release,
            'sdkInt': androidInfo.version.sdkInt,
          },
        );
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return DeviceInfo(
          deviceName: '${iosInfo.name} ${iosInfo.model}',
          deviceType: DeviceType.mobile,
          platform: 'ios',
          appVersion: '1.0.0', // Get from package info
          metadata: {
            'name': iosInfo.name,
            'model': iosInfo.model,
            'systemVersion': iosInfo.systemVersion,
          },
        );
      } else {
        return DeviceInfo(
          deviceName: 'Unknown Device',
          deviceType: DeviceType.desktop,
          platform: Platform.operatingSystem,
          appVersion: '1.0.0',
          metadata: {},
        );
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return DeviceInfo(
        deviceName: 'Unknown Device',
        deviceType: DeviceType.unknown,
        platform: 'unknown',
        appVersion: '1.0.0',
        metadata: {},
      );
    }
  }

  /// Get IP address (simplified)
  Future<String?> _getIpAddress() async {
    try {
      // This is a simplified implementation
      // In production, you might want to use a service to get public IP
      return null;
    } catch (e) {
      debugPrint('Error getting IP address: $e');
      return null;
    }
  }

  /// Get location info (simplified)
  Future<String?> _getLocationInfo() async {
    try {
      // This is a simplified implementation
      // In production, you might want to get approximate location
      return null;
    } catch (e) {
      debugPrint('Error getting location info: $e');
      return null;
    }
  }

  /// Create or update current session
  Future<void> _createOrUpdateCurrentSession() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      // Check if session already exists for this device
      final existingSnapshot = await _firestore
          .collection(_sessionCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .where('deviceId', isEqualTo: _currentDeviceId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        // Update existing session
        final sessionDoc = existingSnapshot.docs.first;
        _currentSession = DeviceSession.fromFirestore(sessionDoc);
        await updateSessionActivity();
      } else {
        // Create new session
        _currentSession = await createDeviceSession();
      }
    } catch (e) {
      debugPrint('Error creating/updating current session: $e');
    }
  }

  /// Start monitoring sessions
  Future<void> _startSessionMonitoring() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) return;

      _sessionsSubscription = _firestore
          .collection(_sessionCollectionName)
          .where('userId', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        final sessions = snapshot.docs
            .map((doc) => DeviceSession.fromFirestore(doc))
            .toList();
        
        _deviceSessionsController.add(sessions);
        
        // Check for session changes
        for (final change in snapshot.docChanges) {
          final session = DeviceSession.fromFirestore(change.doc);
          
          switch (change.type) {
            case DocumentChangeType.added:
              if (session.id != _currentSession?.id) {
                _sessionEventsController.add(DeviceSessionEvent(
                  type: SessionEventType.newSessionDetected,
                  session: session,
                  timestamp: DateTime.now(),
                ));
              }
              break;
            case DocumentChangeType.removed:
              _sessionEventsController.add(DeviceSessionEvent(
                type: SessionEventType.sessionTerminated,
                sessionId: session.id,
                timestamp: DateTime.now(),
              ));
              break;
            case DocumentChangeType.modified:
              // Handle session updates if needed
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting session monitoring: $e');
    }
  }

  /// Stop session monitoring
  Future<void> _stopSessionMonitoring() async {
    await _sessionsSubscription?.cancel();
    _sessionsSubscription = null;
  }

  /// Enforce device limit per user
  Future<void> _enforceDeviceLimit(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_sessionCollectionName)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('lastActiveAt', descending: false)
          .get();

      if (snapshot.docs.length >= _maxDevicesPerUser) {
        // Terminate oldest sessions
        final sessionsToTerminate = snapshot.docs.take(
          snapshot.docs.length - _maxDevicesPerUser + 1
        );

        final batch = _firestore.batch();
        for (final doc in sessionsToTerminate) {
          batch.update(doc.reference, {
            'isActive': false,
            'terminatedAt': Timestamp.fromDate(DateTime.now()),
            'terminationReason': 'device_limit_exceeded',
          });
        }
        await batch.commit();

        debugPrint('Terminated ${sessionsToTerminate.length} sessions due to device limit');
      }
    } catch (e) {
      debugPrint('Error enforcing device limit: $e');
    }
  }

  /// Clear local session data
  Future<void> _clearLocalSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      _currentSession = null;
      _currentDeviceId = null;
    } catch (e) {
      debugPrint('Error clearing local session data: $e');
    }
  }

  /// Clear all local data
  Future<void> _clearAllLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear other local data as needed
      // This could include clearing local database, cache, etc.
      
      debugPrint('Cleared all local data');
    } catch (e) {
      debugPrint('Error clearing all local data: $e');
    }
  }

  /// Get device type distribution
  Map<String, int> _getDeviceTypeDistribution(List<DeviceSession> sessions) {
    final distribution = <String, int>{};
    for (final session in sessions) {
      final type = session.deviceType.name;
      distribution[type] = (distribution[type] ?? 0) + 1;
    }
    return distribution;
  }

  /// Get platform distribution
  Map<String, int> _getPlatformDistribution(List<DeviceSession> sessions) {
    final distribution = <String, int>{};
    for (final session in sessions) {
      final platform = session.platform;
      distribution[platform] = (distribution[platform] ?? 0) + 1;
    }
    return distribution;
  }

  /// Dispose resources
  void dispose() {
    _stopSessionMonitoring();
    _deviceSessionsController.close();
    _sessionEventsController.close();
  }
}

// Data models for device session management

class DeviceSession {
  final String id;
  final String userId;
  final String deviceId;
  final String deviceName;
  final DeviceType deviceType;
  final String platform;
  final String appVersion;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isActive;
  final String? ipAddress;
  final String? location;
  final DateTime? terminatedAt;
  final String? terminationReason;
  final Map<String, dynamic> metadata;

  DeviceSession({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    required this.appVersion,
    required this.createdAt,
    required this.lastActiveAt,
    required this.isActive,
    this.ipAddress,
    this.location,
    this.terminatedAt,
    this.terminationReason,
    required this.metadata,
  });

  factory DeviceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DeviceSession(
      id: doc.id,
      userId: data['userId'] ?? '',
      deviceId: data['deviceId'] ?? '',
      deviceName: data['deviceName'] ?? 'Unknown Device',
      deviceType: DeviceType.values.firstWhere(
        (e) => e.name == data['deviceType'],
        orElse: () => DeviceType.unknown,
      ),
      platform: data['platform'] ?? 'unknown',
      appVersion: data['appVersion'] ?? '1.0.0',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      ipAddress: data['ipAddress'],
      location: data['location'],
      terminatedAt: (data['terminatedAt'] as Timestamp?)?.toDate(),
      terminationReason: data['terminationReason'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType.name,
      'platform': platform,
      'appVersion': appVersion,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'isActive': isActive,
      'ipAddress': ipAddress,
      'location': location,
      'terminatedAt': terminatedAt != null ? Timestamp.fromDate(terminatedAt!) : null,
      'terminationReason': terminationReason,
      'metadata': metadata,
    };
  }

  DeviceSession copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? deviceName,
    DeviceType? deviceType,
    String? platform,
    String? appVersion,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isActive,
    String? ipAddress,
    String? location,
    DateTime? terminatedAt,
    String? terminationReason,
    Map<String, dynamic>? metadata,
  }) {
    return DeviceSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
      ipAddress: ipAddress ?? this.ipAddress,
      location: location ?? this.location,
      terminatedAt: terminatedAt ?? this.terminatedAt,
      terminationReason: terminationReason ?? this.terminationReason,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isCurrentDevice => DateTime.now().difference(lastActiveAt).inMinutes < 5;
  bool get isRecentlyActive => DateTime.now().difference(lastActiveAt).inHours < 24;
  String get displayName => '$deviceName ($platform)';
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
  web,
  unknown,
}

class DeviceInfo {
  final String deviceName;
  final DeviceType deviceType;
  final String platform;
  final String appVersion;
  final Map<String, dynamic> metadata;

  DeviceInfo({
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    required this.appVersion,
    required this.metadata,
  });
}

enum SessionEventType {
  sessionCreated,
  sessionTerminated,
  newSessionDetected,
  allOtherSessionsTerminated,
  logoutCompleted,
}

class DeviceSessionEvent {
  final SessionEventType type;
  final DeviceSession? session;
  final String? sessionId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  DeviceSessionEvent({
    required this.type,
    this.session,
    this.sessionId,
    required this.timestamp,
    this.metadata,
  });
}

class SessionStatistics {
  final int totalSessions;
  final int activeSessions;
  final int recentSessions;
  final DeviceSession? currentSession;
  final Map<String, int> deviceTypes;
  final Map<String, int> platforms;

  SessionStatistics({
    required this.totalSessions,
    required this.activeSessions,
    required this.recentSessions,
    required this.currentSession,
    required this.deviceTypes,
    required this.platforms,
  });

  bool get hasMultipleDevices => activeSessions > 1;
  double get activeSessionRatio => totalSessions > 0 ? activeSessions / totalSessions : 0.0;
}