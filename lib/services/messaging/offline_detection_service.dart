// Offline Detection Service for TALOWA Messaging System
// Implements Task 8: Build comprehensive error handling and loading states
// Requirements: 7.4, 10.4, 10.6

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for detecting and managing offline state
class OfflineDetectionService {
  static final OfflineDetectionService _instance = OfflineDetectionService._internal();
  factory OfflineDetectionService() => _instance;
  OfflineDetectionService._internal();

  // Stream controllers
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  final StreamController<NetworkQuality> _networkQualityController = StreamController<NetworkQuality>.broadcast();
  final StreamController<OfflineMode> _offlineModeController = StreamController<OfflineMode>.broadcast();

  // State
  bool _isOnline = true;
  NetworkQuality _networkQuality = NetworkQuality.unknown;
  OfflineMode _offlineMode = OfflineMode.none;
  
  // Timers and monitoring
  Timer? _connectivityCheckTimer;
  Timer? _qualityCheckTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Configuration
  static const Duration _connectivityCheckInterval = Duration(seconds: 10);
  static const Duration _qualityCheckInterval = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 5);
  
  // Getters
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<NetworkQuality> get networkQualityStream => _networkQualityController.stream;
  Stream<OfflineMode> get offlineModeStream => _offlineModeController.stream;
  
  bool get isOnline => _isOnline;
  NetworkQuality get networkQuality => _networkQuality;
  OfflineMode get offlineMode => _offlineMode;

  /// Initialize offline detection service
  Future<void> initialize() async {
    try {
      debugPrint('Initializing Offline Detection Service...');
      
      // Check initial connectivity
      await _checkInitialConnectivity();
      
      // Start monitoring connectivity changes
      _startConnectivityMonitoring();
      
      // Start periodic checks
      _startPeriodicChecks();
      
      debugPrint('Offline Detection Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Offline Detection Service: $e');
      rethrow;
    }
  }

  /// Check initial connectivity state
  Future<void> _checkInitialConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final wasOnline = _isOnline;
      _isOnline = connectivityResult != ConnectivityResult.none;
      
      if (_isOnline) {
        // Verify actual internet connectivity
        _isOnline = await _verifyInternetConnectivity();
      }
      
      if (wasOnline != _isOnline) {
        _connectionStatusController.add(_isOnline);
        _updateOfflineMode();
      }
      
      // Check network quality if online
      if (_isOnline) {
        await _checkNetworkQuality();
      } else {
        _networkQuality = NetworkQuality.offline;
        _networkQualityController.add(_networkQuality);
      }
      
      debugPrint('Initial connectivity: ${_isOnline ? 'online' : 'offline'}');
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
      _isOnline = false;
      _connectionStatusController.add(_isOnline);
      _updateOfflineMode();
    }
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;
        
        if (_isOnline) {
          // Verify actual internet connectivity
          _isOnline = await _verifyInternetConnectivity();
        }
        
        if (wasOnline != _isOnline) {
          _connectionStatusController.add(_isOnline);
          _updateOfflineMode();
          
          if (_isOnline) {
            debugPrint('🌐 Connection restored');
            await _onConnectionRestored();
          } else {
            debugPrint('📵 Connection lost');
            await _onConnectionLost();
          }
        }
      },
      onError: (error) {
        debugPrint('Connectivity monitoring error: $error');
      },
    );
  }

  /// Start periodic connectivity and quality checks
  void _startPeriodicChecks() {
    // Periodic connectivity verification
    _connectivityCheckTimer = Timer.periodic(_connectivityCheckInterval, (timer) async {
      if (_isOnline) {
        final actuallyOnline = await _verifyInternetConnectivity();
        if (actuallyOnline != _isOnline) {
          _isOnline = actuallyOnline;
          _connectionStatusController.add(_isOnline);
          _updateOfflineMode();
          
          if (!_isOnline) {
            debugPrint('📵 Connection lost (detected via periodic check)');
            await _onConnectionLost();
          }
        }
      }
    });
    
    // Periodic network quality check
    _qualityCheckTimer = Timer.periodic(_qualityCheckInterval, (timer) async {
      if (_isOnline) {
        await _checkNetworkQuality();
      }
    });
  }

  /// Verify actual internet connectivity
  Future<bool> _verifyInternetConnectivity() async {
    try {
      // Try multiple verification methods
      final results = await Future.wait([
        _testFirebaseConnectivity(),
        _testHttpConnectivity(),
      ], eagerError: false);
      
      // Return true if any test succeeds
      return results.any((result) => result == true);
    } catch (e) {
      debugPrint('Internet connectivity verification failed: $e');
      return false;
    }
  }

  /// Test Firebase connectivity
  Future<bool> _testFirebaseConnectivity() async {
    try {
      await FirebaseFirestore.instance
          .collection('_connectivity_test')
          .limit(1)
          .get()
          .timeout(_connectionTimeout);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Test HTTP connectivity
  Future<bool> _testHttpConnectivity() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://www.google.com'))
          .timeout(_connectionTimeout);
      final response = await request.close().timeout(_connectionTimeout);
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Check network quality
  Future<void> _checkNetworkQuality() async {
    if (!_isOnline) {
      _networkQuality = NetworkQuality.offline;
      _networkQualityController.add(_networkQuality);
      return;
    }
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Test with Firebase operation
      await FirebaseFirestore.instance
          .collection('_network_test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;
      
      // Classify network quality
      NetworkQuality newQuality;
      if (latency < 300) {
        newQuality = NetworkQuality.excellent;
      } else if (latency < 800) {
        newQuality = NetworkQuality.good;
      } else if (latency < 1500) {
        newQuality = NetworkQuality.fair;
      } else if (latency < 3000) {
        newQuality = NetworkQuality.poor;
      } else {
        newQuality = NetworkQuality.veryPoor;
      }
      
      if (newQuality != _networkQuality) {
        _networkQuality = newQuality;
        _networkQualityController.add(_networkQuality);
        debugPrint('Network quality: $newQuality (${latency}ms)');
        
        // Update offline mode based on quality
        _updateOfflineMode();
      }
    } catch (e) {
      _networkQuality = NetworkQuality.poor;
      _networkQualityController.add(_networkQuality);
      debugPrint('Network quality check failed: $e');
    }
  }

  /// Update offline mode based on connectivity and quality
  void _updateOfflineMode() {
    OfflineMode newMode;
    
    if (!_isOnline) {
      newMode = OfflineMode.full;
    } else {
      switch (_networkQuality) {
        case NetworkQuality.offline:
          newMode = OfflineMode.full;
          break;
        case NetworkQuality.veryPoor:
        case NetworkQuality.poor:
          newMode = OfflineMode.degraded;
          break;
        case NetworkQuality.fair:
          newMode = OfflineMode.limited;
          break;
        case NetworkQuality.good:
        case NetworkQuality.excellent:
          newMode = OfflineMode.none;
          break;
        case NetworkQuality.unknown:
          newMode = OfflineMode.none;
          break;
      }
    }
    
    if (newMode != _offlineMode) {
      _offlineMode = newMode;
      _offlineModeController.add(_offlineMode);
      debugPrint('Offline mode changed to: $newMode');
    }
  }

  /// Handle connection restoration
  Future<void> _onConnectionRestored() async {
    try {
      // Check network quality immediately
      await _checkNetworkQuality();
      
      // Notify other services about connection restoration
      debugPrint('✅ Connection restored - Quality: $_networkQuality');
    } catch (e) {
      debugPrint('Error handling connection restoration: $e');
    }
  }

  /// Handle connection loss
  Future<void> _onConnectionLost() async {
    try {
      _networkQuality = NetworkQuality.offline;
      _networkQualityController.add(_networkQuality);
      
      debugPrint('❌ Connection lost - Entering offline mode');
    } catch (e) {
      debugPrint('Error handling connection loss: $e');
    }
  }

  /// Force connectivity check
  Future<bool> forceConnectivityCheck() async {
    try {
      debugPrint('🔄 Forcing connectivity check...');
      
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnectivity = connectivityResult != ConnectivityResult.none;
      
      if (hasConnectivity) {
        _isOnline = await _verifyInternetConnectivity();
      } else {
        _isOnline = false;
      }
      
      _connectionStatusController.add(_isOnline);
      _updateOfflineMode();
      
      if (_isOnline) {
        await _checkNetworkQuality();
      }
      
      debugPrint('🔄 Forced check result: ${_isOnline ? 'online' : 'offline'}');
      return _isOnline;
    } catch (e) {
      debugPrint('Error in forced connectivity check: $e');
      return false;
    }
  }

  /// Get detailed connectivity information
  Future<ConnectivityInfo> getConnectivityInfo() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      return ConnectivityInfo(
        isOnline: _isOnline,
        connectivityResult: connectivityResult,
        networkQuality: _networkQuality,
        offlineMode: _offlineMode,
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting connectivity info: $e');
      return ConnectivityInfo(
        isOnline: false,
        connectivityResult: ConnectivityResult.none,
        networkQuality: NetworkQuality.offline,
        offlineMode: OfflineMode.full,
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Check if operation should be allowed based on network conditions
  bool shouldAllowOperation({
    required OperationType operationType,
    bool respectOfflineMode = true,
  }) {
    if (!respectOfflineMode) return true;
    
    switch (operationType) {
      case OperationType.critical:
        // Critical operations allowed in all modes except full offline
        return _offlineMode != OfflineMode.full;
        
      case OperationType.normal:
        // Normal operations allowed only when not in degraded or full offline
        return _offlineMode == OfflineMode.none || _offlineMode == OfflineMode.limited;
        
      case OperationType.lowPriority:
        // Low priority operations only when connection is good
        return _offlineMode == OfflineMode.none;
        
      case OperationType.mediaUpload:
        // Media uploads require good connection
        return _offlineMode == OfflineMode.none && 
               (_networkQuality == NetworkQuality.good || _networkQuality == NetworkQuality.excellent);
    }
  }

  /// Get recommended retry delay based on network conditions
  Duration getRecommendedRetryDelay() {
    switch (_networkQuality) {
      case NetworkQuality.offline:
        return const Duration(minutes: 1);
      case NetworkQuality.veryPoor:
        return const Duration(seconds: 30);
      case NetworkQuality.poor:
        return const Duration(seconds: 15);
      case NetworkQuality.fair:
        return const Duration(seconds: 5);
      case NetworkQuality.good:
      case NetworkQuality.excellent:
        return const Duration(seconds: 2);
      case NetworkQuality.unknown:
        return const Duration(seconds: 5);
    }
  }

  /// Get user-friendly network status message
  String getNetworkStatusMessage() {
    if (!_isOnline) {
      return 'No internet connection';
    }
    
    switch (_networkQuality) {
      case NetworkQuality.excellent:
        return 'Excellent connection';
      case NetworkQuality.good:
        return 'Good connection';
      case NetworkQuality.fair:
        return 'Fair connection';
      case NetworkQuality.poor:
        return 'Poor connection - some features may be limited';
      case NetworkQuality.veryPoor:
        return 'Very poor connection - limited functionality';
      case NetworkQuality.offline:
        return 'No internet connection';
      case Netw  }
}ode)';
ineMfle: $oflity, modworkQua $nete, quality: $isOnlinsOnline:Info(ictivityturn 'Conne re   ) {
ing(tr toS
  Stringerride @ov

 
    };
  }(),so8601Stringecked.toIed': lastChCheck   'last),
   ing(neMode.toStre': offliodofflineM),
      'y.toString(ualit: networkQty'Qualitwork'ne      ),
ing(Result.toStrvityctit': conneesulvityR  'connecti
    Online,Online': is    'isreturn {
  ap() {
    mic> toMring, dynaMap<St

  ked,
  });s.lastChecrequired thie,
    neModd this.offli    require
kQuality,this.networed 
    requirityResult,ivthis.connectrequired ,
    his.isOnline tequired    r{
tivityInfo(

  ConneclastChecked;ateTime nal Dde;
  fi offlineMofflineMode  final OrkQuality;
ty netwoworkQualial Netult;
  finnectivityRes conivityResultctConneal ne;
  finbool isOnliinal yInfo {
  fnectivits Conasl
clation modeormy inftivit/ Connec
}

//ectionod connres go/ Requiad,   /aUploedi me delayed
  Can b   //owPriority,tions
  ldard operatan      // Sormal,    nn
or connectio with po evenst workMual,      // tic
  crionType {num Operatin checks
ek conditionetwor types for ion
/// Operat
}
ne mode    // Offli  
  full,  tyonalicti fun  // Reducedded,  degrabled
  ures disaSome featted,     // ty
  liminctionali // Full fu    e,   de {
  nonlineMo
enum Offde levels mo/// Offline
}

n,nknow
  ut,  excellen,
 good
  fair,poor,
 or,
  yPo  vere,

  offlinuality {workQNetvels
enum  quality le/// Network


  }
}ose();ller.cltroConofflineModeawait _se();
    r.cloletroltyConworkQuali  await _net);
  ler.close(tusControlnectionStat _conwai
    a
    el();tion?.cancitySubscripnnectivt _cowai();
    a?.cancelTimerualityCheck  _q();
  celkTimer?.canhecyCctivitconnenc {
    _se() asyvoid> dispo  Future<
 resourcesDispose

  ///    }
  }on...';
 nectiecking conrn 'Ch      retunknown:
  orkQuality.u