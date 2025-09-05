// Enterprise Security Service for TALOWA
// Comprehensive security, audit logging, and compliance features

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class EnterpriseSecurityService {
  static final EnterpriseSecurityService _instance = EnterpriseSecurityService._internal();
  factory EnterpriseSecurityService() => _instance;
  EnterpriseSecurityService._internal();

  // Database (using SharedPreferences for web compatibility)
  Database? _auditDatabase;
  Database? _securityDatabase;
  
  // Security configuration
  SecurityConfig _config = SecurityConfig();
  
  // Session management
  final Map<String, UserSession> _activeSessions = {};
  Timer? _sessionCleanupTimer;
  
  // Audit logging
  final StreamController<AuditEvent> _auditStreamController = StreamController.broadcast();
  final List<AuditEvent> _auditBuffer = [];
  Timer? _auditFlushTimer;
  
  // Security monitoring
  final List<SecurityThreat> _detectedThreats = [];
  
  // Device fingerprinting
  String? _deviceFingerprint;
  
  /// Initialize enterprise security service
  Future<void> initialize() async {
    try {
      await _initializeDatabases();
      await _loadSecurityConfig();
      await _initializeDeviceFingerprinting();
      _startSessionManagement();
      _startAuditLogging();
      _startSecurityMonitoring();
      
      await logAuditEvent(
        AuditEvent(
          eventType: AuditEventType.systemStart,
          description: 'Enterprise Security Service initialized',
          severity: AuditSeverity.info,
        ),
      );
      
      debugPrint('EnterpriseSecurityService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing EnterpriseSecurityService: $e');
    }
  }

  /// Initialize security databases
  Future<void> _initializeDatabases() async {
    // On web, sqlite isn't available. Skip database initialization.
    if (kIsWeb) {
      _auditDatabase = null;
      _securityDatabase = null;
      return;
    }
    
    try {
      // Audit database
      _auditDatabase = await openDatabase(
        'security_audit.db',
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE audit_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event_type TEXT NOT NULL,
              user_id TEXT,
              session_id TEXT,
              description TEXT NOT NULL,
              severity TEXT NOT NULL,
              metadata TEXT,
              ip_address TEXT,
              user_agent TEXT,
              device_fingerprint TEXT,
              timestamp INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          
          await db.execute('''
            CREATE TABLE compliance_reports (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              report_type TEXT NOT NULL,
              period_start INTEGER NOT NULL,
              period_end INTEGER NOT NULL,
              data TEXT NOT NULL,
              generated_by TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          
          // Create indexes
          await db.execute('CREATE INDEX idx_audit_timestamp ON audit_events(timestamp)');
          await db.execute('CREATE INDEX idx_audit_user ON audit_events(user_id)');
          await db.execute('CREATE INDEX idx_audit_type ON audit_events(event_type)');
        },
      );
      
      // Security database
      _securityDatabase = await openDatabase(
        'security_data.db',
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE user_sessions (
              session_id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              device_fingerprint TEXT,
              ip_address TEXT,
              user_agent TEXT,
              created_at INTEGER NOT NULL,
              last_activity INTEGER NOT NULL,
              expires_at INTEGER NOT NULL,
              is_active INTEGER DEFAULT 1
            )
          ''');
          
          await db.execute('''
            CREATE TABLE security_threats (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              threat_type TEXT NOT NULL,
              severity TEXT NOT NULL,
              description TEXT NOT NULL,
              source_ip TEXT,
              user_id TEXT,
              session_id TEXT,
              metadata TEXT,
              status TEXT DEFAULT 'detected',
              detected_at INTEGER NOT NULL,
              resolved_at INTEGER
            )
          ''');
          
          await db.execute('''
            CREATE TABLE failed_login_attempts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_identifier TEXT NOT NULL,
              ip_address TEXT,
              user_agent TEXT,
              attempt_time INTEGER NOT NULL,
              failure_reason TEXT
            )
          ''');
          
          // Create indexes
          await db.execute('CREATE INDEX idx_sessions_user ON user_sessions(user_id)');
          await db.execute('CREATE INDEX idx_sessions_active ON user_sessions(is_active)');
          await db.execute('CREATE INDEX idx_threats_severity ON security_threats(severity)');
          await db.execute('CREATE INDEX idx_failed_logins_ip ON failed_login_attempts(ip_address)');
        },
      );
    } catch (e) {
      debugPrint('Error initializing security databases: $e');
    }
  }

  /// Load security configuration
  Future<void> _loadSecurityConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('security_config');
      
      if (configJson != null) {
        final configMap = jsonDecode(configJson);
        _config = SecurityConfig.fromMap(configMap);
      }
    } catch (e) {
      debugPrint('Error loading security config: $e');
      // Use default config
      _config = SecurityConfig();
    }
  }

  /// Initialize device fingerprinting
  Future<void> _initializeDeviceFingerprinting() async {
    // On web, device info and platform detection aren't available.
    if (kIsWeb) {
      _deviceFingerprint = 'web_device';
      return;
    }
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      String fingerprint = '';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        fingerprint = '${androidInfo.model}_${androidInfo.id}_${androidInfo.brand}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        fingerprint = '${iosInfo.model}_${iosInfo.identifierForVendor}_${iosInfo.systemVersion}';
      }
      
      fingerprint += '_${packageInfo.version}_${packageInfo.buildNumber}';
      
      // Hash the fingerprint for privacy
      final bytes = utf8.encode(fingerprint);
      final digest = sha256.convert(bytes);
      _deviceFingerprint = digest.toString();
      
    } catch (e) {
      debugPrint('Error initializing device fingerprinting: $e');
      _deviceFingerprint = 'unknown_device';
    }
  }

  /// Start session management
  void _startSessionManagement() {
    _sessionCleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanupExpiredSessions();
    });
  }

  /// Start audit logging
  void _startAuditLogging() {
    _auditFlushTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _flushAuditBuffer();
    });
  }

  /// Start security monitoring
  void _startSecurityMonitoring() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      _analyzeSecurityThreats();
    });
  }

  /// Create user session
  Future<UserSession> createUserSession({
    required String userId,
    String? ipAddress,
    String? userAgent,
    Duration? sessionDuration,
  }) async {
    try {
      final sessionId = _generateSessionId();
      final now = DateTime.now();
      final duration = sessionDuration ?? _config.sessionTimeout;
      
      final session = UserSession(
        sessionId: sessionId,
        userId: userId,
        deviceFingerprint: _deviceFingerprint,
        ipAddress: ipAddress,
        userAgent: userAgent,
        createdAt: now,
        lastActivity: now,
        expiresAt: now.add(duration),
        isActive: true,
      );
      
      // Store in memory
      _activeSessions[sessionId] = session;
      
      // Store in database
      if (_securityDatabase != null) {
        await _securityDatabase!.insert('user_sessions', session.toMap());
      }
      
      // Log audit event
      await logAuditEvent(
        AuditEvent(
          eventType: AuditEventType.userLogin,
          userId: userId,
          sessionId: sessionId,
          description: 'User session created',
          severity: AuditSeverity.info,
          ipAddress: ipAddress,
          userAgent: userAgent,
        ),
      );
      
      return session;
    } catch (e) {
      debugPrint('Error creating user session: $e');
      throw SecurityException('Failed to create user session');
    }
  }

  /// Validate user session
  Future<bool> validateSession(String sessionId) async {
    try {
      // Check memory first
      final session = _activeSessions[sessionId];
      if (session != null) {
        if (session.isActive && session.expiresAt.isAfter(DateTime.now())) {
          // Update last activity
          session.lastActivity = DateTime.now();
          await _updateSessionActivity(sessionId);
          return true;
        } else {
          // Session expired
          await invalidateSession(sessionId, 'Session expired');
          return false;
        }
      }
      
      // Check database
      if (_securityDatabase != null) {
        final result = await _securityDatabase!.query(
          'user_sessions',
          where: 'session_id = ? AND is_active = 1 AND expires_at > ?',
          whereArgs: [sessionId, DateTime.now().millisecondsSinceEpoch],
        );
        
        if (result.isNotEmpty) {
          final dbSession = UserSession.fromMap(result.first);
          _activeSessions[sessionId] = dbSession;
          await _updateSessionActivity(sessionId);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Error validating session: $e');
      return false;
    }
  }

  /// Invalidate user session
  Future<void> invalidateSession(String sessionId, String reason) async {
    try {
      final session = _activeSessions[sessionId];
      
      // Remove from memory
      _activeSessions.remove(sessionId);
      
      // Update database
      if (_securityDatabase != null) {
        await _securityDatabase!.update(
          'user_sessions',
          {'is_active': 0},
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
      }
      
      // Log audit event
      if (session != null) {
        await logAuditEvent(
          AuditEvent(
            eventType: AuditEventType.userLogout,
            userId: session.userId,
            sessionId: sessionId,
            description: 'User session invalidated: $reason',
            severity: AuditSeverity.info,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error invalidating session: $e');
    }
  }

  /// Log audit event
  Future<void> logAuditEvent(AuditEvent event) async {
    try {
      // Add device fingerprint
      event.deviceFingerprint = _deviceFingerprint;
      
      // Add to buffer for batch processing
      _auditBuffer.add(event);
      
      // Emit to stream for real-time monitoring
      _auditStreamController.add(event);
      
      // Immediate flush for critical events
      if (event.severity == AuditSeverity.critical || event.severity == AuditSeverity.high) {
        await _flushAuditBuffer();
      }
    } catch (e) {
      debugPrint('Error logging audit event: $e');
    }
  }

  /// Record failed login attempt
  Future<void> recordFailedLogin({
    required String userIdentifier,
    String? ipAddress,
    String? userAgent,
    String? failureReason,
  }) async {
    try {
      if (_securityDatabase != null) {
        await _securityDatabase!.insert('failed_login_attempts', {
          'user_identifier': userIdentifier,
          'ip_address': ipAddress,
          'user_agent': userAgent,
          'attempt_time': DateTime.now().millisecondsSinceEpoch,
          'failure_reason': failureReason,
        });
      }
      
      // Check for brute force attacks
      await _checkBruteForceAttack(userIdentifier, ipAddress);
      
      // Log audit event
      await logAuditEvent(
        AuditEvent(
          eventType: AuditEventType.loginFailed,
          description: 'Failed login attempt for $userIdentifier',
          severity: AuditSeverity.warning,
          ipAddress: ipAddress,
          userAgent: userAgent,
          metadata: {'failure_reason': failureReason},
        ),
      );
    } catch (e) {
      debugPrint('Error recording failed login: $e');
    }
  }

  /// Generate compliance report
  Future<ComplianceReport> generateComplianceReport({
    required ComplianceReportType reportType,
    required DateTime startDate,
    required DateTime endDate,
    String? generatedBy,
  }) async {
    try {
      final reportData = <String, dynamic>{};
      
      switch (reportType) {
        case ComplianceReportType.auditLog:
          reportData['audit_events'] = await _getAuditEventsForPeriod(startDate, endDate);
          break;
        case ComplianceReportType.userActivity:
          reportData['user_sessions'] = await _getUserActivityForPeriod(startDate, endDate);
          break;
        case ComplianceReportType.securityIncidents:
          reportData['security_threats'] = await _getSecurityThreatsForPeriod(startDate, endDate);
          break;
        case ComplianceReportType.dataAccess:
          reportData['data_access_logs'] = await _getDataAccessLogsForPeriod(startDate, endDate);
          break;
      }
      
      final report = ComplianceReport(
        id: _generateReportId(),
        reportType: reportType,
        periodStart: startDate,
        periodEnd: endDate,
        data: reportData,
        generatedBy: generatedBy,
        createdAt: DateTime.now(),
      );
      
      // Store report
      if (_auditDatabase != null) {
        await _auditDatabase!.insert('compliance_reports', report.toMap());
      }
      
      // Log audit event
      await logAuditEvent(
        AuditEvent(
          eventType: AuditEventType.complianceReport,
          description: 'Compliance report generated: ${reportType.name}',
          severity: AuditSeverity.info,
          metadata: {'report_id': report.id},
        ),
      );
      
      return report;
    } catch (e) {
      debugPrint('Error generating compliance report: $e');
      throw SecurityException('Failed to generate compliance report');
    }
  }

  /// Get security metrics
  Future<Map<String, dynamic>> getSecurityMetrics() async {
    try {
      final metrics = <String, dynamic>{};
      
      // Active sessions
      metrics['active_sessions'] = _activeSessions.length;
      
      // Recent audit events
      final recentEvents = await _getRecentAuditEvents(const Duration(hours: 24));
      metrics['recent_audit_events'] = recentEvents.length;
      
      // Security threats
      metrics['detected_threats'] = _detectedThreats.length;
      
      // Failed login attempts
      final failedLogins = await _getRecentFailedLogins(const Duration(hours: 24));
      metrics['failed_logins_24h'] = failedLogins.length;
      
      return metrics;
    } catch (e) {
      debugPrint('Error getting security metrics: $e');
      return {};
    }
  }

  /// Private helper methods
  Future<void> _cleanupExpiredSessions() async {
    try {
      final now = DateTime.now();
      final expiredSessions = <String>[];
      
      _activeSessions.forEach((sessionId, session) {
        if (!session.isActive || session.expiresAt.isBefore(now)) {
          expiredSessions.add(sessionId);
        }
      });
      
      for (final sessionId in expiredSessions) {
        await invalidateSession(sessionId, 'Session expired');
      }
    } catch (e) {
      debugPrint('Error cleaning up expired sessions: $e');
    }
  }

  Future<void> _flushAuditBuffer() async {
    if (_auditBuffer.isEmpty || _auditDatabase == null) return;
    
    try {
      final batch = _auditDatabase!.batch();
      
      for (final event in _auditBuffer) {
        batch.insert('audit_events', event.toMap());
      }
      
      await batch.commit();
      _auditBuffer.clear();
    } catch (e) {
      debugPrint('Error flushing audit buffer: $e');
    }
  }

  Future<void> _updateSessionActivity(String sessionId) async {
    try {
      if (_securityDatabase != null) {
        await _securityDatabase!.update(
          'user_sessions',
          {'last_activity': DateTime.now().millisecondsSinceEpoch},
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
      }
    } catch (e) {
      debugPrint('Error updating session activity: $e');
    }
  }

  Future<void> _checkBruteForceAttack(String? userIdentifier, String? ipAddress) async {
    try {
      if (_securityDatabase == null) return;
      
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 15)).millisecondsSinceEpoch;
      
      // Check by user identifier
      if (userIdentifier != null) {
        final userAttempts = await _securityDatabase!.query(
          'failed_login_attempts',
          where: 'user_identifier = ? AND attempt_time > ?',
          whereArgs: [userIdentifier, cutoffTime],
        );
        
        if (userAttempts.length >= _config.maxFailedLoginAttempts) {
          await _recordSecurityThreat(
            SecurityThreat(
              threatType: ThreatType.bruteForce,
              severity: ThreatSeverity.high,
              description: 'Brute force attack detected for user: $userIdentifier',
              userId: userIdentifier,
              metadata: {'attempt_count': userAttempts.length},
            ),
          );
        }
      }
      
      // Check by IP address
      if (ipAddress != null) {
        final ipAttempts = await _securityDatabase!.query(
          'failed_login_attempts',
          where: 'ip_address = ? AND attempt_time > ?',
          whereArgs: [ipAddress, cutoffTime],
        );
        
        if (ipAttempts.length >= _config.maxFailedLoginAttemptsPerIP) {
          await _recordSecurityThreat(
            SecurityThreat(
              threatType: ThreatType.bruteForce,
              severity: ThreatSeverity.high,
              description: 'Brute force attack detected from IP: $ipAddress',
              sourceIp: ipAddress,
              metadata: {'attempt_count': ipAttempts.length},
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking brute force attack: $e');
    }
  }

  Future<void> _recordSecurityThreat(SecurityThreat threat) async {
    try {
      _detectedThreats.add(threat);
      
      if (_securityDatabase != null) {
        await _securityDatabase!.insert('security_threats', threat.toMap());
      }
      
      // Log critical audit event
      await logAuditEvent(
        AuditEvent(
          eventType: AuditEventType.securityThreat,
          userId: threat.userId,
          description: threat.description,
          severity: AuditSeverity.critical,
          ipAddress: threat.sourceIp,
          metadata: threat.metadata,
        ),
      );
    } catch (e) {
      debugPrint('Error recording security threat: $e');
    }
  }

  void _analyzeSecurityThreats() {
    // Implement real-time threat analysis
    // This could include ML-based anomaly detection
  }

  // Data retrieval methods
  Future<List<Map<String, dynamic>>> _getAuditEventsForPeriod(DateTime start, DateTime end) async {
    if (_auditDatabase == null) return [];
    
    return await _auditDatabase!.query(
      'audit_events',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> _getUserActivityForPeriod(DateTime start, DateTime end) async {
    if (_securityDatabase == null) return [];
    
    return await _securityDatabase!.query(
      'user_sessions',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> _getSecurityThreatsForPeriod(DateTime start, DateTime end) async {
    if (_securityDatabase == null) return [];
    
    return await _securityDatabase!.query(
      'security_threats',
      where: 'detected_at >= ? AND detected_at <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'detected_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> _getDataAccessLogsForPeriod(DateTime start, DateTime end) async {
    // This would integrate with data access logging
    return [];
  }

  Future<List<Map<String, dynamic>>> _getRecentAuditEvents(Duration duration) async {
    if (_auditDatabase == null) return [];
    
    final cutoff = DateTime.now().subtract(duration).millisecondsSinceEpoch;
    return await _auditDatabase!.query(
      'audit_events',
      where: 'timestamp > ?',
      whereArgs: [cutoff],
    );
  }

  Future<List<Map<String, dynamic>>> _getRecentFailedLogins(Duration duration) async {
    if (_securityDatabase == null) return [];
    
    final cutoff = DateTime.now().subtract(duration).millisecondsSinceEpoch;
    return await _securityDatabase!.query(
      'failed_login_attempts',
      where: 'attempt_time > ?',
      whereArgs: [cutoff],
    );
  }

  // Utility methods
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return sha256.convert(utf8.encode(random)).toString().substring(0, 32);
  }

  String _generateReportId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'RPT_${timestamp}_${(timestamp % 10000).toString().padLeft(4, '0')}';
  }

  /// Get audit event stream
  Stream<AuditEvent> get auditEventStream => _auditStreamController.stream;

  /// Dispose resources
  Future<void> dispose() async {
    _sessionCleanupTimer?.cancel();
    _auditFlushTimer?.cancel();
    await _flushAuditBuffer();
    await _auditDatabase?.close();
    await _securityDatabase?.close();
    await _auditStreamController.close();
  }
}

// Security models and enums
class SecurityConfig {
  final Duration sessionTimeout;
  final int maxFailedLoginAttempts;
  final int maxFailedLoginAttemptsPerIP;
  final bool enableDeviceFingerprinting;
  final bool enableAuditLogging;
  
  SecurityConfig({
    this.sessionTimeout = const Duration(hours: 8),
    this.maxFailedLoginAttempts = 5,
    this.maxFailedLoginAttemptsPerIP = 10,
    this.enableDeviceFingerprinting = true,
    this.enableAuditLogging = true,
  });
  
  factory SecurityConfig.fromMap(Map<String, dynamic> map) {
    return SecurityConfig(
      sessionTimeout: Duration(milliseconds: map['session_timeout'] ?? 28800000),
      maxFailedLoginAttempts: map['max_failed_login_attempts'] ?? 5,
      maxFailedLoginAttemptsPerIP: map['max_failed_login_attempts_per_ip'] ?? 10,
      enableDeviceFingerprinting: map['enable_device_fingerprinting'] ?? true,
      enableAuditLogging: map['enable_audit_logging'] ?? true,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'session_timeout': sessionTimeout.inMilliseconds,
      'max_failed_login_attempts': maxFailedLoginAttempts,
      'max_failed_login_attempts_per_ip': maxFailedLoginAttemptsPerIP,
      'enable_device_fingerprinting': enableDeviceFingerprinting,
      'enable_audit_logging': enableAuditLogging,
    };
  }
}

class UserSession {
  final String sessionId;
  final String userId;
  final String? deviceFingerprint;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;
  DateTime lastActivity;
  final DateTime expiresAt;
  bool isActive;
  
  UserSession({
    required this.sessionId,
    required this.userId,
    this.deviceFingerprint,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
    required this.lastActivity,
    required this.expiresAt,
    required this.isActive,
  });
  
  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      sessionId: map['session_id'],
      userId: map['user_id'],
      deviceFingerprint: map['device_fingerprint'],
      ipAddress: map['ip_address'],
      userAgent: map['user_agent'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      lastActivity: DateTime.fromMillisecondsSinceEpoch(map['last_activity']),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at']),
      isActive: map['is_active'] == 1,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'device_fingerprint': deviceFingerprint,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_activity': lastActivity.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
    };
  }
}

class AuditEvent {
  final String id;
  final AuditEventType eventType;
  final String? userId;
  final String? sessionId;
  final String description;
  final AuditSeverity severity;
  final Map<String, dynamic>? metadata;
  final String? ipAddress;
  final String? userAgent;
  String? deviceFingerprint;
  final DateTime timestamp;
  
  AuditEvent({
    String? id,
    required this.eventType,
    this.userId,
    this.sessionId,
    required this.description,
    required this.severity,
    this.metadata,
    this.ipAddress,
    this.userAgent,
    this.deviceFingerprint,
    DateTime? timestamp,
  }) : id = id ?? _generateEventId(),
       timestamp = timestamp ?? DateTime.now();
  
  static String _generateEventId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'AE_${now}_${(now % 10000).toString().padLeft(4, '0')}';
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_type': eventType.name,
      'user_id': userId,
      'session_id': sessionId,
      'description': description,
      'severity': severity.name,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'device_fingerprint': deviceFingerprint,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class SecurityThreat {
  final String id;
  final ThreatType threatType;
  final ThreatSeverity severity;
  final String description;
  final String? sourceIp;
  final String? userId;
  final String? sessionId;
  final Map<String, dynamic>? metadata;
  final ThreatStatus status;
  final DateTime detectedAt;
  DateTime? resolvedAt;
  
  SecurityThreat({
    String? id,
    required this.threatType,
    required this.severity,
    required this.description,
    this.sourceIp,
    this.userId,
    this.sessionId,
    this.metadata,
    this.status = ThreatStatus.detected,
    DateTime? detectedAt,
    this.resolvedAt,
  }) : id = id ?? _generateThreatId(),
       detectedAt = detectedAt ?? DateTime.now();
  
  static String _generateThreatId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'ST_${now}_${(now % 10000).toString().padLeft(4, '0')}';
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'threat_type': threatType.name,
      'severity': severity.name,
      'description': description,
      'source_ip': sourceIp,
      'user_id': userId,
      'session_id': sessionId,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'status': status.name,
      'detected_at': detectedAt.millisecondsSinceEpoch,
      'resolved_at': resolvedAt?.millisecondsSinceEpoch,
    };
  }
}

class ComplianceReport {
  final String id;
  final ComplianceReportType reportType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, dynamic> data;
  final String? generatedBy;
  final DateTime createdAt;
  
  ComplianceReport({
    required this.id,
    required this.reportType,
    required this.periodStart,
    required this.periodEnd,
    required this.data,
    this.generatedBy,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_type': reportType.name,
      'period_start': periodStart.millisecondsSinceEpoch,
      'period_end': periodEnd.millisecondsSinceEpoch,
      'data': jsonEncode(data),
      'generated_by': generatedBy,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

class SecurityMetrics {
  int count = 0;
  DateTime? lastOccurrence;
  
  void increment() {
    count++;
    lastOccurrence = DateTime.now();
  }
}

// Enums
enum AuditEventType {
  systemStart,
  systemStop,
  userLogin,
  userLogout,
  loginFailed,
  dataAccess,
  dataModification,
  securityThreat,
  complianceReport,
  configurationChange,
}

enum AuditSeverity {
  info,
  warning,
  high,
  critical,
}

enum ThreatType {
  bruteForce,
  suspiciousActivity,
  dataExfiltration,
  unauthorizedAccess,
  maliciousRequest,
}

enum ThreatSeverity {
  low,
  medium,
  high,
  critical,
}

enum ThreatStatus {
  detected,
  investigating,
  resolved,
  falsePositive,
}

enum ComplianceReportType {
  auditLog,
  userActivity,
  securityIncidents,
  dataAccess,
}

// Exceptions
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}