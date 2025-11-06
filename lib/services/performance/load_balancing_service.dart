// lib/services/performance/load_balancing_service.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Advanced Load Balancing Service for 10M DAU Support
class LoadBalancingService {
  static final LoadBalancingService _instance = LoadBalancingService._internal();
  factory LoadBalancingService() => _instance;
  LoadBalancingService._internal();

  // Load Balancing Configuration
  static const int maxConcurrentRequests = 100;
  static const int maxQueueSize = 1000;
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration healthCheckInterval = Duration(minutes: 1);

  // Request Queue Management
  final List<PendingRequest> _requestQueue = [];
  final Set<String> _activeRequests = {};
  int _currentLoad = 0;
  
  // Server Health Tracking
  final Map<String, ServerHealth> _serverHealth = {};
  final List<String> _availableServers = [];
  Timer? _healthCheckTimer;
  
  // Load Distribution
  final Map<String, int> _serverLoads = {};
  final Map<String, DateTime> _lastRequestTime = {};
  
  // Circuit Breaker
  final Map<String, CircuitBreaker> _circuitBreakers = {};
  
  // Performance Metrics
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  int _queuedRequests = 0;
  double _averageResponseTime = 0.0;

  /// Initialize load balancing service
  Future<void> initialize() async {
    await _initializeServers();
    await _startHealthChecking();
    await _startLoadMonitoring();
    
    if (kDebugMode) {
      print('✅ Load Balancing Service initialized');
    }
  }

  /// Initialize available servers
  Future<void> _initializeServers() async {
    // Initialize Firebase regions/endpoints
    _availableServers.addAll([
      'us-central1',
      'us-east1',
      'europe-west1',
      'asia-southeast1',
    ]);
    
    // Initialize server health
    for (final server in _availableServers) {
      _serverHealth[server] = ServerHealth(
        serverId: server,
        isHealthy: true,
        responseTime: 0,
        errorRate: 0.0,
        lastCheck: DateTime.now(),
      );
      
      _serverLoads[server] = 0;
      _circuitBreakers[server] = CircuitBreaker(serverId: server);
    }
  }

  /// Execute request with load balancing
  Future<T> executeBalancedRequest<T>({
    required String requestId,
    required Future<T> Function(String serverId) requestExecutor,
    RequestPriority priority = RequestPriority.normal,
    int maxRetries = 3,
  }) async {
    _totalRequests++;
    
    // Check if we're at capacity
    if (_currentLoad >= maxConcurrentRequests) {
      if (_requestQueue.length >= maxQueueSize) {
        _failedRequests++;
        throw LoadBalancingException('Request queue is full');
      }
      
      // Queue the request
      return await _queueRequest<T>(
        requestId: requestId,
        requestExecutor: requestExecutor,
        priority: priority,
        maxRetries: maxRetries,
      );
    }
    
    // Execute immediately
    return await _executeRequest<T>(
      requestId: requestId,
      requestExecutor: requestExecutor,
      maxRetries: maxRetries,
    );
  }

  /// Queue request for later execution
  Future<T> _queueRequest<T>({
    required String requestId,
    required Future<T> Function(String serverId) requestExecutor,
    required RequestPriority priority,
    required int maxRetries,
  }) async {
    final completer = Completer<T>();
    final request = PendingRequest<T>(
      id: requestId,
      executor: requestExecutor,
      completer: completer,
      priority: priority,
      maxRetries: maxRetries,
      queuedAt: DateTime.now(),
    );
    
    // Insert based on priority
    _insertByPriority(request);
    _queuedRequests++;
    
    if (kDebugMode) {
      print('📋 Queued request: $requestId (priority: $priority)');
    }
    
    return completer.future;
  }

  /// Insert request in queue based on priority
  void _insertByPriority<T>(PendingRequest<T> request) {
    int insertIndex = _requestQueue.length;
    
    for (int i = 0; i < _requestQueue.length; i++) {
      if (request.priority.index > _requestQueue[i].priority.index) {
        insertIndex = i;
        break;
      }
    }
    
    _requestQueue.insert(insertIndex, request);
  }

  /// Execute request with server selection
  Future<T> _executeRequest<T>({
    required String requestId,
    required Future<T> Function(String serverId) requestExecutor,
    required int maxRetries,
  }) async {
    final startTime = DateTime.now();
    _currentLoad++;
    _activeRequests.add(requestId);
    
    try {
      // Select best server
      final serverId = _selectBestServer();
      if (serverId == null) {
        throw LoadBalancingException('No healthy servers available');
      }
      
      // Check circuit breaker
      final circuitBreaker = _circuitBreakers[serverId]!;
      if (!circuitBreaker.canExecute()) {
        throw LoadBalancingException('Circuit breaker open for server: $serverId');
      }
      
      // Execute request
      final result = await requestExecutor(serverId).timeout(requestTimeout);
      
      // Update metrics
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      _updateServerMetrics(serverId, true, responseTime);
      _updateCircuitBreaker(serverId, true);
      
      _successfulRequests++;
      _updateAverageResponseTime(responseTime.toDouble());
      
      return result;
    } catch (e) {
      _failedRequests++;
      
      // Retry logic
      if (maxRetries > 0) {
        if (kDebugMode) {
          print('🔄 Retrying request: $requestId ($maxRetries retries left)');
        }
        
        return await _executeRequest<T>(
          requestId: requestId,
          requestExecutor: requestExecutor,
          maxRetries: maxRetries - 1,
        );
      }
      
      rethrow;
    } finally {
      _currentLoad--;
      _activeRequests.remove(requestId);
      
      // Process next queued request
      _processNextQueuedRequest();
    }
  }

  /// Select best server based on load and health
  String? _selectBestServer() {
    final healthyServers = _availableServers.where((serverId) {
      final health = _serverHealth[serverId];
      final circuitBreaker = _circuitBreakers[serverId];
      return health?.isHealthy == true && circuitBreaker?.canExecute() == true;
    }).toList();
    
    if (healthyServers.isEmpty) {
      return null;
    }
    
    // Use weighted round-robin based on server load and response time
    String bestServer = healthyServers.first;
    double bestScore = double.infinity;
    
    for (final serverId in healthyServers) {
      final load = _serverLoads[serverId] ?? 0;
      final health = _serverHealth[serverId]!;
      
      // Calculate server score (lower is better)
      double score = load.toDouble() + (health.responseTime / 100.0);
      
      // Add penalty for recent errors
      score += health.errorRate * 10;
      
      if (score < bestScore) {
        bestScore = score;
        bestServer = serverId;
      }
    }
    
    // Update server load
    _serverLoads[bestServer] = (_serverLoads[bestServer] ?? 0) + 1;
    _lastRequestTime[bestServer] = DateTime.now();
    
    return bestServer;
  }

  /// Update server metrics
  void _updateServerMetrics(String serverId, bool success, int responseTime) {
    final health = _serverHealth[serverId];
    if (health != null) {
      health.responseTime = (health.responseTime + responseTime) ~/ 2;
      
      if (success) {
        health.errorRate = health.errorRate * 0.9; // Decay error rate
      } else {
        health.errorRate = (health.errorRate + 0.1).clamp(0.0, 1.0);
      }
      
      health.lastCheck = DateTime.now();
    }
    
    // Decrease server load
    _serverLoads[serverId] = ((_serverLoads[serverId] ?? 1) - 1).clamp(0, maxConcurrentRequests);
  }

  /// Update circuit breaker state
  void _updateCircuitBreaker(String serverId, bool success) {
    final circuitBreaker = _circuitBreakers[serverId];
    if (circuitBreaker != null) {
      if (success) {
        circuitBreaker.recordSuccess();
      } else {
        circuitBreaker.recordFailure();
      }
    }
  }

  /// Process next queued request
  void _processNextQueuedRequest() {
    if (_requestQueue.isNotEmpty && _currentLoad < maxConcurrentRequests) {
      final request = _requestQueue.removeAt(0);
      _queuedRequests--;
      
      // Execute the queued request
      _executeRequest(
        requestId: request.id,
        requestExecutor: request.executor,
        maxRetries: request.maxRetries,
      ).then((result) {
        request.completer.complete(result);
      }).catchError((error) {
        request.completer.completeError(error);
      });
    }
  }

  /// Start health checking
  Future<void> _startHealthChecking() async {
    _healthCheckTimer = Timer.periodic(healthCheckInterval, (timer) {
      _performHealthChecks();
    });
  }

  /// Perform health checks on all servers
  void _performHealthChecks() async {
    for (final serverId in _availableServers) {
      await _checkServerHealth(serverId);
    }
  }

  /// Check individual server health
  Future<void> _checkServerHealth(String serverId) async {
    try {
      final startTime = DateTime.now();
      
      // Perform a lightweight health check (e.g., ping Firebase)
      await FirebaseFirestore.instance.collection('health_check').limit(1).get();
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      final health = _serverHealth[serverId]!;
      health.isHealthy = true;
      health.responseTime = responseTime;
      health.lastCheck = DateTime.now();
      
      // Reset circuit breaker if server is healthy
      _circuitBreakers[serverId]?.reset();
      
    } catch (e) {
      final health = _serverHealth[serverId]!;
      health.isHealthy = false;
      health.errorRate = (health.errorRate + 0.2).clamp(0.0, 1.0);
      health.lastCheck = DateTime.now();
      
      if (kDebugMode) {
        print('❌ Health check failed for server: $serverId');
      }
    }
  }

  /// Start load monitoring
  Future<void> _startLoadMonitoring() async {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _logLoadMetrics();
    });
  }

  /// Log load balancing metrics
  void _logLoadMetrics() {
    if (kDebugMode) {
      final successRate = _totalRequests > 0 
          ? (_successfulRequests / _totalRequests * 100) 
          : 0;
      
      print('⚖️ Load Balancing Metrics:');
      print('   Current Load: $_currentLoad/$maxConcurrentRequests');
      print('   Queue Size: ${_requestQueue.length}/$maxQueueSize');
      print('   Success Rate: ${successRate.toStringAsFixed(1)}%');
      print('   Avg Response Time: ${_averageResponseTime.toStringAsFixed(0)}ms');
      print('   Active Requests: ${_activeRequests.length}');
    }
  }

  /// Update average response time
  void _updateAverageResponseTime(double responseTime) {
    if (_averageResponseTime == 0) {
      _averageResponseTime = responseTime;
    } else {
      _averageResponseTime = (_averageResponseTime + responseTime) / 2;
    }
  }

  /// Get load balancing statistics
  Map<String, dynamic> getLoadBalancingStats() {message';
}Exception: $oadBalancingg() => 'LtoStrin
  String @override;
  
  e)sagmesion(this.ingExceptlance;
  LoadBassagl String me
  finaxception {ents Etion implemncingExcepoadBala
class Lxceptionncing ed balaoa
/// Ln,
}

  halfOpe
  open,losed,e {
  catuitBreakerSts
enum Circer statercuit break

/// Cil;
  }
}reTime = nul   lastFailu.closed;
 eakerState = CircuitBr;
    statent = 0ailureCou  f  et() {
 void res}
  }

 n;
    opereakerState. CircuitBtate =) {
      sldshofailureThret >= ilureCoun if (fa
      ();
 me.now DateTieTime =stFailur    lant++;
  failureCou
  () {ailureecordF
  void r }
sed;
 cloerState.tBreake = Circuiatst = 0;
    untilureCo{
    fass() ceSucoid record
  }

  v true;turnre
    n stateope  // Half-
    
  
    } false;return }
      true;
     rn        retuOpen;
 halfkerState.CircuitBrea state =     ) {
   eoutTime!) > timstFailurelance(fereifw().dteTime.no  Da& 
        me != null &stFailureTi      if (lae.open) {
atkerStBreaCircuitstate ==   if (}
    
    true;
  turn  {
      ree.closed)tBreakerStat== Circuite if (sta() {
     canExecute
  boolrverId});
ired this.sereaker({requ
  CircuitButes: 1);
uration(mint = Dion timeouconst Durattatic   sold = 5;
reThresh failuconst inttic   
  sta.closed;
tatecuitBreakerSCir state = StateBreakeruitirce;
  CeTimFailurme? lasteTi= 0;
  DatCount t failure  inrId;
serveg rin
  final Ster {ircuitBreak Casstion
clentalemr imp breakeuitCirc// 
}

/}
      };),
601String(eck.toIso8tChasheck': ltC
      'lasate,ate': errorRorR
      'errnseTime,me': respo'responseTi   thy,
   y': isHeal  'isHealth
    serverId,serverId': {
      'eturn 
    r{ic> toMap()  dynamMap<String,
  });
k,
  his.lastChec required tte,
   Raerrored this.   requirTime,
 nse this.respored
    requithy,s.isHealhiuired t    reqverId,
his.serequired t  ralth({
  ServerHe;

  ck lastCheeTimeate;
  De errorRate;
  doubleTim responsthy;
  intisHealbool Id;
  vering serinal Str{
  flth ea ServerHdel
classh moerver healt S
}

///l,riticagh,
  c hi
 ormal,  n
  low,
{ty tPrioriRequesevels
enum  priority lequest/ R});
}

//ueuedAt,
  red this.q
    requitries,this.maxReequired ty,
    ris.prioriuired th
    reqcompleter,red this.equi   rcutor,
 ed this.exe  requir  d,
 this.i  requiredequest({
    PendingRt;

e queuedAl DateTims;
  finat maxRetrie ininal  fy;
ity prioritestPrior  final Requ
ompleter;> ceter<Tal Complinecutor;
  f exverId)String serFunction(Future<T>   final g id;
rinnal StT> {
  fidingRequest< Penel
classmodst reque/// Pending }


ar();
  }cleBreakers.it   _circuear();
 rverLoads.cl  _seclear();
  th._serverHeal
    ar();sts.cle_activeReque);
    clear(ueue.estQqu   re
 cel();canr?.CheckTime
    _healthse() {oid dispoervice
  ving sbalanc load  /// Dispose
 
  }
   };oMap())),
 v.t(k,  MapEntryk, v) =>.map((erHealthervh': _sltHea     'server.length,
 Requestsctive': _atsReques   'activeseTime,
   erageRespon': _avimeponseTeRes'averag,
      ccessRatete': su 'successRaests,
     failedRequ': _edRequests     'failests,
 ssfulRequces': _sucquestssfulRe'succests,
      Requests': _totaltalReque      'to
ueSize,Que max':xQueueSize
      'maength,questQueue.l: _reize'ueS    'queuests,
  RequrrentxConcmaequests': xConcurrentR
      'maLoad,rrentcuoad': _rentL'cur
      return {
    
          : 0;   100) 
ests *lRequta _tolRequests /successfu   ? (_  ts > 0 
   equestalRssRate = _toal succein
    f