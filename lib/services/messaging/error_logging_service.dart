// Error Logging Service for TALOWA Messaging System
// Implements Task 8: Build comprehensive error handling and loading states
// Requirements: 7.5, 7.6

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';

/// Service for logging errors while maintaining user privacy
class ErrorLoggingService {
  static final ErrorLoggingService _instance = ErrorLoggingService._internal();
  factory ErrorLoggingService() => _instance;
  ErrorLoggingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<ErrorLogEntry> _localErrorLog = [];
  final StreamController<ErrorLogEntry> _errorLogController = 
      StreamController<ErrorLogEntry>.broadcast();

  // Configuration
  static const int _maxLocalLogSize = 100;
  static const Duration _logUploadInterval = Duration(minutes: 5);
  
  Timer? _uploadTimer;
  bool _isInitialized = false;

  Stream<ErrorLogEntry> get errorLogStream => _errorLogController.stream;

  /// Initialize error logging service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Error Logging Service...');
      
      // Start periodic log upload
      _startPeriodicUpload();
      
      _isInitialized = true;
      debugPrint('Error Logging Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Error Logging Service: $e');
      // Don't rethrow - logging service should not break the app
    }
  }

  /// Log an error with privacy protection
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    required String severity,
    String? component,
    String? operationId,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
    bool includeUserInfo = false,
  }) async {
    try {
      final logEntry = ErrorLogEntry(
        id: _generateLogId(),
        timestamp: DateTime.now(),
        errorType: errorType,
        errorMessage: _sanitizeErrorMessage(errorMessage),
        severity: severity,
        component: component ?? 'unknown',
        operationId: operationId,
        context: _sanitizeContext(context ?? {}),
        stackTrace: _sanitizeStackTrace(stackTrace),
        userId: includeUserInfo ? _getCurrentUserId() : null,
        deviceInfo: _getDeviceInfo(),
        appVersion: _getAppVersion(),
      );

      // Add to local log
      _addToLocalLog(logEntry);
      
      // Emit to stream
      _errorLogController.add(logEntry);
      
      // Log to console in debug mode
      if (kDebugMode) {
        _logToConsole(logEntry);
      }
      
      // Upload immediately for critical errors
      if (severity == 'critical') {
        await _uploadLogEntry(logEntry);
      }
    } catch (e) {
      // Fail silently to avoid recursive errors
      if (kDebugMode) {
        debugPrint('Error logging failed: $e');
      }
    }
  }

  /// Log network error
  Future<void> logNetworkError({
    required String operation,
    required String errorMessage,
    String? url,
    int? statusCode,
    Map<String, dynamic>? headers,
  }) async {
    await logError(
      errorType: 'network_error',
      errorMessage: errorMessage,
      severity: 'medium',
      component: 'network',
      context: {
        'operation': operation,
        'url': _sanitizeUrl(url),
        'statusCode': statusCode,
        'hasHeaders': headers != null,
      },
    );
  }

  /// Log authentication error
  Future<void> logAuthError({
    required String operation,
    required String errorMessage,
    String? errorCode,
  }) async {
    await logError(
      errorType: 'auth_error',
      errorMessage: errorMessage,
      severity: 'high',
      component: 'authentication',
      context: {
        'operation': operation,
        'errorCode': errorCode,
      },
      includeUserInfo: false, // Never include user info for auth errors
    );
  }

  /// Log messaging error
  Future<void> logMessagingError({
    required String operation,
    required String errorMessage,
    String? conversationId,
    String? messageId,
    String? messageType,
  }) async {
    await logError(
      errorType: 'messaging_error',
      errorMessage: errorMessage,
      severity: 'medium',
      component: 'messaging',
      context: {
        'operation': operation,
        'conversationId': _sanitizeId(conversationId),
        'messageId': _sanitizeId(messageId),
        'messageType': messageType,
      },
    );
  }

  /// Log voice call error
  Future<void> logVoiceCallError({
    required String operation,
    required String errorMessage,
    String? callId,
    String? callType,
    int? duration,
  }) async {
    await logError(
      errorType: 'voice_call_error',
      errorMessage: errorMessage,
      severity: 'medium',
      component: 'voice_calls',
      context: {
        'operation': operation,
        'callId': _sanitizeId(callId),
        'callType': callType,
        'duration': duration,
      },
    );
  }

  /// Log file operation error
  Future<void> logFileError({
    required String operation,
    required String errorMessage,
    String? fileName,
    int? fileSize,
    String? fileType,
  }) async {
    await logError(
      errorType: 'file_error',
      errorMessage: errorMessage,
      severity: 'low',
      component: 'file_operations',
      context: {
        'operation': operation,
        'fileName': _sanitizeFileName(fileName),
        'fileSize': fileSize,
        'fileType': fileType,
      },
    );
  }

  /// Log performance issue
  Future<void> logPerformanceIssue({
    required String operation,
    required int duration,
    String? details,
    Map<String, dynamic>? metrics,
  }) async {
    await logError(
      errorType: 'performance_issue',
      errorMessage: 'Operation took ${duration}ms: $operation',
      severity: duration > 5000 ? 'medium' : 'low',
      component: 'performance',
      context: {
        'operation': operation,
        'duration': duration,
        'details': details,
        'metrics': _sanitizeContext(metrics ?? {}),
      },
    );
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStatistics() {
    final errors = List<ErrorLogEntry>.from(_localErrorLog);
    
    if (errors.isEmpty) {
      return {
        'totalErrors': 0,
        'errorsByType': {},
        'errorsBySeverity': {},
        'errorsByComponent': {},
        'recentErrors': [],
      };
    }

    final errorsByType = <String, int>{};
    final errorsBySeverity = <String, int>{};
    final errorsByComponent = <String, int>{};

    for (final error in errors) {
      errorsByType[error.errorType] = (errorsByType[error.errorType] ?? 0) + 1;
      errorsBySeverity[error.severity] = (errorsBySeverity[error.severity] ?? 0) + 1;
      errorsByComponent[error.component] = (errorsByComponent[error.component] ?? 0) + 1;
    }

    return {
      'totalErrors': errors.length,
      'errorsByType': errorsByType,
      'errorsBySeverity': errorsBySeverity,
      'errorsByComponent': errorsByComponent,
      'recentErrors': errors.take(10).map((e) => e.toSummaryMap()).toList(),
      'oldestError': errors.isNotEmpty ? errors.first.timestamp.toIso8601String() : null,
      'newestError': errors.isNotEmpty ? errors.last.timestamp.toIso8601String() : null,
    };
  }

  /// Get recent errors
  List<ErrorLogEntry> getRecentErrors({int limit = 20}) {
    final errors = List<ErrorLogEntry>.from(_localErrorLog);
    errors.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return errors.take(limit).toList();
  }

  /// Clear local error log
  void clearLocalLog() {
    _localErrorLog.clear();
    debugPrint('Local error log cleared');
  }

  /// Export error log for debugging
  String exportErrorLog() {
    final errors = List<ErrorLogEntry>.from(_localErrorLog);
    errors.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final exportData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalErrors': errors.length,
      'errors': errors.map((e) => e.toMap()).toList(),
    };
    
    return jsonEncode(exportData);
  }

  // Private methods

  void _addToLocalLog(ErrorLogEntry entry) {
    _localErrorLog.add(entry);
    
    // Maintain log size
    if (_localErrorLog.length > _maxLocalLogSize) {
      _localErrorLog.removeAt(0);
    }
  }

  void _startPeriodicUpload() {
    _uploadTimer = Timer.periodic(_logUploadInterval, (timer) {
      _uploadPendingLogs();
    });
  }

  Future<void> _uploadPendingLogs() async {
    try {
      final pendingLogs = _localErrorLog.where((log) => !log.uploaded).toList();
      
      if (pendingLogs.isEmpty) return;
      
      // Upload in batches
      const batchSize = 10;
      for (int i = 0; i < pendingLogs.length; i += batchSize) {
        final batch = pendingLogs.skip(i).take(batchSize).toList();
        await _uploadLogBatch(batch);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading logs: $e');
      }
    }
  }

  Future<void> _uploadLogBatch(List<ErrorLogEntry> logs) async {
    try {
      final batch = _firestore.batch();
      
      for (final log in logs) {
        final docRef = _firestore.collection('error_logs').doc(log.id);
        batch.set(docRef, log.toFirestoreMap());
      }
      
      await batch.commit();
      
      // Mark as uploaded
      for (final log in logs) {
        log.uploaded = true;
      }
      
      debugPrint('Uploaded ${logs.length} error logs');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading log batch: $e');
      }
    }
  }

  Future<void> _uploadLogEntry(ErrorLogEntry entry) async {
    try {
      await _firestore.collection('error_logs').doc(entry.id).set(entry.toFirestoreMap());
      entry.uploaded = true;
      debugPrint('Uploaded critical error log: ${entry.id}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading critical log: $e');
      }
    }
  }

  void _logToConsole(ErrorLogEntry entry) {
    final prefix = _getSeverityPrefix(entry.severity);
    debugPrint('$prefix [${entry.component}] ${entry.errorType}: ${entry.errorMessage}');
    
    if (entry.context.isNotEmpty) {
      debugPrint('  Context: ${entry.context}');
    }
    
    if (entry.stackTrace != null) {
      debugPrint('  Stack: ${entry.stackTrace}');
    }
  }

  String _getSeverityPrefix(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return '🚨';
      case 'high':
        return '❌';
      case 'medium':
        return '⚠️';
      case 'low':
        return 'ℹ️';
      default:
        return '📝';
    }
  }

  String _generateLogId() {
    return 'log_${DateTime.now().millisecondsSinceEpoch}_${_localErrorLog.length}';
  }

  String? _getCurrentUserId() {
    try {
      return AuthService.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _getDeviceInfo() {
    return {
      'pl}
  }
 };ponent,
   oment': ccompony,
      'verit seerity':      'sevge,
rorMessa': erMessage      'errorerrorType,
rType': 
      'erro,ing()1Str60.toIso8 timestampmestamp':'ti,
       id':
      'idreturn {  
  ap() {ummaryMnamic> toSing, dyStrap<
  M

  }
    };n,appVersioon': pVersi'ap
      nfo,: deviceIeviceInfo' 'drId,
     serId': use  'uace,
    stackTr: race'kT    'stac,
  ntextontext': co
      'cionId,perat o':ionIdoperat   'onent,
   nt': comp  'componeity,
    verty': se   'severie,
   ssagge': errorMe'errorMessa
      orType,pe': errrorTy'er
      amp),est(timmDateamp.fro Timest'timestamp':
         return {reMap() {
 toesirc> toFnamidyString, p< Ma
 
   };
  }uploaded,
 'uploaded': n,
      VersioapppVersion':     'apnfo,
  eviceI': ddeviceInfo  'd,
    Id': userI      'userckTrace,
Trace': sta 'stack    context,
 ext':  'contonId,
     Id': operatiperation
      'ont,omponet': conen    'compity,
  ity': sever     'severessage,
 ge': errorMrMessa  'erro    rrorType,
: epe'rorTy
      'ertring(),1SIso860timestamp.tomp': ta      'times'id': id,
    
  eturn {    r {
ap()dynamic> toMap<String, 
  M
  });
ed = false,his.upload  t  pVersion,
is.apired th   requeInfo,
  this.deviciredrequ    
erId,  this.uskTrace,
    this.stac
  s.context, thirequired    nId,
s.operatiot,
    thionenmped this.coequirity,
    rerthis.sevrequired age,
    rorMess.erisired th,
    requrorTypeired this.erqu,
    reis.timestampd th   requireis.id,
  thed
    requirEntry({ ErrorLog

  uploaded;
  boolon;Versiring appl St
  finaeInfo;ic devdynamic>g, Map<Strin
  final erId; String? usfinal  Trace;
ing? stack  final Str context;
ic>, dynamringap<St;
  final MIdon? operatiringStnal ent;
  fimponng cotri Snality;
  fitring sever final Sessage;
  errorMtring Spe;
  finaling errorTyfinal Str
  mestamp;tiDateTime 
  final d;String il ry {
  finarorLogEntErel
class  modtryror log en
}

/// Er);
  }er.close(ntrollCoorLogerr  await _;
    
  s()ingLoguploadPendait _awogs
    ing lemainload any r// Up
        ancel();
Timer?.cad    _uploc {
asynispose() <void> duture  Furces
se reso/ Dispo

  //
  }astDot)}';tring(leName.subsiln '[FILE]${f retur
   LE]';
    rn '[FI-1) retuot ==    if (lastDf('.');
 ndexOeName.lastIfilot = lastD final ging
   debugfor tension  ex only   // Keep
 null;
    turn = null) ree =fileNam   if ( {
 leName)fing? trieName(SanitizeFil_sring? 
  St }
 3)}';
 ngth -ng(id.le.substri.${id(0, 3)}..ubstringurn '${id.s
    retturn '[ID]';re6) <= (id.length ng
    if  debuggiers for charact and last 3irsty fonlp  // Kee  
   ull;
  eturn null) r= n  if (id =) {
  (String? idnitizeId? _sa

  Stringh}';
  }t}${uri.pat://${uri.hoscheme}ri.s '${urnretu    
    
';D_URL] '[INVALIurn== null) retri     if (u(url);
tryParsei = Uri.al urata
    finensitive din sonta might chateters tuery paramve q  // Remo
    
  eturn null;ll) r= nu if (url =) {
   rlng? uzeUrl(Strig? _saniti
  Strin);
  }
\n'in('0).jotake(1turn lines.    reit('\n');
tring().splkTrace.toSlines = stacinal 
    fthlengstack trace  // Limit    
    
]';ACE_REDACTED_TRACK'[STode) return DebugM if (!kug mode
    debce in tra stackudeincl   // Only ;
    
  return nullace == null)Trtack  if (s
  tackTrace) {ackTrace? sackTrace(StsanitizeStng? _

  Stri }[ID]');
 , '0,}\b')Za-z0-9]{2A-Exp(r'\b[eAll(Regacpl        .re]')
'[EMAIL,}\b'), z]{2]+\.[A-Z|a-z0-9.-%+-]+@[A-Za-a-z0-9._p(r'\b[A-Z(RegEx .replaceAll
       ]')), '[PHONEb',}\(r'\b\d{10ExpplaceAll(Reg    .reue
     return valalue) {
   ing vzeString(Straniti  String _s}

);
  tive)sis(senKey.contain loweritive) =>((senss.anyeKeyrn sensitiv
    retu);e(oLowerCasy = key.terKefinal low  
    
    ];
  nal', 'perso'user',, , 'name'dress' 'adl',ne', 'emai 'pho
     ntial',th', 'credeey', 'aut', 'kn', 'secreord', 'toke'passw  
    iveKeys = [sit  final sen{
  ring key) (StiveKey_isSensit
  bool 
d;
  }rn sanitize  retu
       }
}
       
  lue;= va[key] zed saniti
        else {   }alue);
   ing(vizeStr = _sanittized[key]       saniing) {
 alue is Strf (ves
      iluvaze string niti  // Sa     
    
      }
 ntinue;      coD]';
  REDACTE '[ed[key] =anitiz{
        skey)) sitiveKey(sSen  if (_iys
    sensitive ke    // Skip 
   alue;
     y.v entr =nal value
      fintry.key;al key = efin) {
      triesn context.enntry i efinal    for ({};
    
g, dynamic> = <Strintized final saniext) {
    contynamic>p<String, dt(MaeContex> _sanitizdynamicring, ap<St
  }

  MEN]');OK'[T\b'), 0,}A-Za-z0-9]{2p(r'\b[ExaceAll(Reg      .repl
   '[EMAIL]'){2,}\b'),A-Z|a-z]-]+.[A-Za-z0-9.0-9._%+-]+@['\b[A-Za-zgExp(r(ReeAll    .replac)
    E_NUMBER]'ON'[PH\b'), d{10,}gExp(r'\b\ReaceAll(      .replge
   messaeturnsages
    rrror mesPII from eotential ve p  // Remo) {
  sagetring mes(SsagerrorMes _sanitizeEring
  St0';
  }
turn '1.0. reus
   info_plge_rom packawould come fapp, this eal  a r{
    // Inion() getAppVerstring _
  }

  Se,
    };seModse': kReleaelea      'isReMode,
 kProfilfile':  'isProMode,
    ug': kDebugsDeb     'ig(),
 form.toStrinatTargetPlefault': drmatfo