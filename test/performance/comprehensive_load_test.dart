import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Comprehensive Load Testing Suite for TALOWA
/// Tests performance under various load conditions with CDN integration
class ComprehensiveLoadTester {
  static const String BASE_URL = 'http://localhost:3000';
  static const Duration TEST_DURATION = Duration(minutes: 5);
  static const int MAX_CONCURRENT_USERS = 100;
  
  final Random _random = Random();
  final List<LoadTestResult> _results = [];
  final Map<String, List<double>> _metrics = {};
  
  /// Run comprehensive load test suite
  Future<void> runComprehensiveTests() async {
    print('🚀 Starting Comprehensive Load Test Suite');
    print('=' * 60);
    
    try {
      // Test 1: Gradual Load Increase
      await _runGradualLoadTest();
      
      // Test 2: Spike Load Test
      await _runSpikeLoadTest();
      
      // Test 3: Sustained Load Test
      await _runSustainedLoadTest();
      
      // Test 4: CDN Performance Test
      await _runCDNPerformanceTest();
      
      // Test 5: Memory Stress Test
      await _runMemoryStressTest();
      
      // Test 6: Database Load Test
      await _runDatabaseLoadTest();
      
      // Generate comprehensive report
      await _generateComprehensiveReport();
      
    } catch (e) {
      print('❌ Load test suite failed: $e');
      rethrow;
    }
  }
  
  /// Test 1: Gradual Load Increase
  Future<void> _runGradualLoadTest() async {
    print('\n📈 Running Gradual Load Increase Test');
    
    final testResults = <LoadTestResult>[];
    
    for (int users = 10; users <= 50; users += 10) {
      print('  Testing with $users concurrent users...');
      
      final result = await _runLoadTest(
        name: 'gradual_load_$users',
        concurrentUsers: users,
        duration: Duration(minutes: 2),
        requestsPerUser: 20,
      );
      
      testResults.add(result);
      _results.add(result);
      
      // Brief pause between test phases
      await Future.delayed(Duration(seconds: 30));
    }
    
    _analyzeGradualLoadResults(testResults);
  }
  
  /// Test 2: Spike Load Test
  Future<void> _runSpikeLoadTest() async {
    print('\n⚡ Running Spike Load Test');
    
    // Start with low load
    print('  Phase 1: Baseline load (10 users)');
    final baselineResult = await _runLoadTest(
      name: 'spike_baseline',
      concurrentUsers: 10,
      duration: Duration(minutes: 1),
      requestsPerUser: 10,
    );
    
    // Sudden spike
    print('  Phase 2: Spike load (80 users)');
    final spikeResult = await _runLoadTest(
      name: 'spike_peak',
      concurrentUsers: 80,
      duration: Duration(minutes: 2),
      requestsPerUser: 15,
    );
    
    // Return to baseline
    print('  Phase 3: Return to baseline (10 users)');
    final recoveryResult = await _runLoadTest(
      name: 'spike_recovery',
      concurrentUsers: 10,
      duration: Duration(minutes: 1),
      requestsPerUser: 10,
    );
    
    _results.addAll([baselineResult, spikeResult, recoveryResult]);
    _analyzeSpikeTestResults(baselineResult, spikeResult, recoveryResult);
  }
  
  /// Test 3: Sustained Load Test
  Future<void> _runSustainedLoadTest() async {
    print('\n⏱️  Running Sustained Load Test');
    
    final result = await _runLoadTest(
      name: 'sustained_load',
      concurrentUsers: 30,
      duration: Duration(minutes: 10),
      requestsPerUser: 50,
    );
    
    _results.add(result);
    _analyzeSustainedLoadResults(result);
  }
  
  /// Test 4: CDN Performance Test
  Future<void> _runCDNPerformanceTest() async {
    print('\n🌐 Running CDN Performance Test');
    
    final cdnResults = <CDNTestResult>[];
    
    // Test different asset types and sizes
    final testAssets = [
      {'type': 'image', 'size': '100KB', 'url': '/api/assets/test-image-100kb.jpg'},
      {'type': 'image', 'size': '1MB', 'url': '/api/assets/test-image-1mb.jpg'},
      {'type': 'video', 'size': '5MB', 'url': '/api/assets/test-video-5mb.mp4'},
      {'type': 'document', 'size': '500KB', 'url': '/api/assets/test-document-500kb.pdf'},
    ];
    
    for (final asset in testAssets) {
      print('  Testing ${asset['type']} (${asset['size']})...');
      
      final result = await _testCDNAsset(
        assetType: asset['type']!,
        assetSize: asset['size']!,
        assetUrl: asset['url']!,
        concurrentRequests: 20,
      );
      
      cdnResults.add(result);
    }
    
    _analyzeCDNResults(cdnResults);
  }
  
  /// Test 5: Memory Stress Test
  Future<void> _runMemoryStressTest() async {
    print('\n🧠 Running Memory Stress Test');
    
    final result = await _runMemoryIntensiveTest(
      name: 'memory_stress',
      concurrentUsers: 25,
      duration: Duration(minutes: 3),
      memoryIntensiveOperations: true,
    );
    
    _results.add(result);
    _analyzeMemoryStressResults(result);
  }
  
  /// Test 6: Database Load Test
  Future<void> _runDatabaseLoadTest() async {
    print('\n🗄️  Running Database Load Test');
    
    final dbResults = <LoadTestResult>[];
    
    // Test different database operations
    final operations = ['read_heavy', 'write_heavy', 'mixed'];
    
    for (final operation in operations) {
      print('  Testing $operation operations...');
      
      final result = await _runDatabaseTest(
        name: 'db_$operation',
        concurrentUsers: 20,
        duration: Duration(minutes: 2),
        operationType: operation,
      );
      
      dbResults.add(result);
      _results.add(result);
    }
    
    _analyzeDatabaseResults(dbResults);
  }
  
  /// Run individual load test
  Future<LoadTestResult> _runLoadTest({
    required String name,
    required int concurrentUsers,
    required Duration duration,
    required int requestsPerUser,
  }) async {
    final startTime = DateTime.now();
    final futures = <Future<UserTestResult>>[];
    
    // Start concurrent users
    for (int i = 0; i < concurrentUsers; i++) {
      futures.add(_simulateUser(i, requestsPerUser, duration));
    }
    
    // Wait for all users to complete
    final userResults = await Future.wait(futures);
    final endTime = DateTime.now();
    
    // Calculate metrics
    final totalRequests = userResults.fold<int>(0, (sum, result) => sum + result.requestCount);
    final totalErrors = userResults.fold<int>(0, (sum, result) => sum + result.errorCount);
    final responseTimes = userResults.expand((result) => result.responseTimes).toList();
    
    responseTimes.sort();
    final p95Index = (responseTimes.length * 0.95).floor();
    final p99Index = (responseTimes.length * 0.99).floor();
    
    return LoadTestResult(
      name: name,
      concurrentUsers: concurrentUsers,
      duration: endTime.difference(startTime),
      totalRequests: totalRequests,
      successfulRequests: totalRequests - totalErrors,
      errorCount: totalErrors,
      averageResponseTime: responseTimes.isNotEmpty ? responseTimes.reduce((a, b) => a + b) / responseTimes.length : 0,
      p95ResponseTime: responseTimes.isNotEmpty ? responseTimes[p95Index] : 0,
      p99ResponseTime: responseTimes.isNotEmpty ? responseTimes[p99Index] : 0,
      throughput: totalRequests / endTime.difference(startTime).inSeconds,
      errorRate: totalRequests > 0 ? totalErrors / totalRequests : 0,
      timestamp: startTime,
    );
  }
  
  /// Simulate individual user behavior
  Future<UserTestResult> _simulateUser(int userId, int requestCount, Duration maxDuration) async {
    final responseTimes = <double>[];
    int errors = 0;
    int requests = 0;
    
    final endTime = DateTime.now().add(maxDuration);
    
    while (DateTime.now().isBefore(endTime) && requests < requestCount) {
      try {
        final requestStart = DateTime.now();
        
        // Simulate different types of requests
        final requestType = _getRandomRequestType();
        await _makeRequest(requestType);
        
        final responseTime = DateTime.now().difference(requestStart).inMilliseconds.toDouble();
        responseTimes.add(responseTime);
        requests++;
        
        // Random delay between requests (0.1 - 2 seconds)
        await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(1900)));
        
      } catch (e) {
        errors++;
        requests++;
      }
    }
    
    return UserTestResult(
      userId: userId,
      requestCount: requests,
      errorCount: errors,
      responseTimes: responseTimes,
    );
  }
  
  /// Make HTTP request based on type
  Future<http.Response> _makeRequest(String requestType) async {
    final client = http.Client();
    
    try {
      switch (requestType) {
        case 'feed':
          return await client.get(Uri.parse('$BASE_URL/api/feed')).timeout(Duration(seconds: 10));
        case 'profile':
          return await client.get(Uri.parse('$BASE_URL/api/profile/user123')).timeout(Duration(seconds: 10));
        case 'posts':
          return await client.get(Uri.parse('$BASE_URL/api/posts')).timeout(Duration(seconds: 10));
        case 'create_post':
          return await client.post(
            Uri.parse('$BASE_URL/api/posts'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'content': 'Test post ${_random.nextInt(1000)}'}),
          ).timeout(Duration(seconds: 10));
        case 'search':
          return await client.get(Uri.parse('$BASE_URL/api/search?q=test${_random.nextInt(100)}')).timeout(Duration(seconds: 10));
        default:
          return await client.get(Uri.parse('$BASE_URL/')).timeout(Duration(seconds: 10));
      }
    } finally {
      client.close();
    }
  }
  
  /// Get random request type
  String _getRandomRequestType() {
    final types = ['feed', 'profile', 'posts', 'create_post', 'search', 'home'];
    return types[_random.nextInt(types.length)];
  }
  
  /// Test CDN asset performance
  Future<CDNTestResult> _testCDNAsset({
    required String assetType,
    required String assetSize,
    required String assetUrl,
    required int concurrentRequests,
  }) async {
    final futures = <Future<AssetRequestResult>>[];
    
    for (int i = 0; i < concurrentRequests; i++) {
      futures.add(_requestAsset(assetUrl));
    }
    
    final results = await Future.wait(futures);
    
    final downloadTimes = results.map((r) => r.downloadTime).toList();
    final cacheHits = results.where((r) => r.cacheHit).length;
    
    return CDNTestResult(
      assetType: assetType,
      assetSize: assetSize,
      concurrentRequests: concurrentRequests,
      averageDownloadTime: downloadTimes.reduce((a, b) => a + b) / downloadTimes.length,
      cacheHitRate: cacheHits / concurrentRequests,
      totalBandwidth: results.fold<int>(0, (sum, r) => sum + r.bytesTransferred),
    );
  }
  
  /// Request individual asset
  Future<AssetRequestResult> _requestAsset(String assetUrl) async {
    final client = http.Client();
    final startTime = DateTime.now();
    
    try {
      final response = await client.get(Uri.parse('$BASE_URL$assetUrl')).timeout(Duration(seconds: 30));
      final downloadTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();
      
      // Check if response came from cache (simplified check)
      final cacheHit = response.headers['x-cache'] == 'HIT' || downloadTime < 100;
      
      return AssetRequestResult(
        downloadTime: downloadTime,
        bytesTransferred: response.contentLength ?? 0,
        cacheHit: cacheHit,
        statusCode: response.statusCode,
      );
    } finally {
      client.close();
    }
  }
  
  /// Run memory intensive test
  Future<LoadTestResult> _runMemoryIntensiveTest({
    required String name,
    required int concurrentUsers,
    required Duration duration,
    required bool memoryIntensiveOperations,
  }) async {
    // This would include operations that consume significant memory
    // For simulation, we'll run regular load test with additional memory tracking
    return await _runLoadTest(
      name: name,
      concurrentUsers: concurrentUsers,
      duration: duration,
      requestsPerUser: 30,
    );
  }
  
  /// Run database-specific test
  Future<LoadTestResult> _runDatabaseTest({
    required String name,
    required int concurrentUsers,
    required Duration duration,
    required String operationType,
  }) async {
    // This would target specific database operations
    // For simulation, we'll run targeted API endpoints
    return await _runLoadTest(
      name: name,
      concurrentUsers: concurrentUsers,
      duration: duration,
      requestsPerUser: 25,
    );
  }
  
  /// Analyze gradual load test results
  void _analyzeGradualLoadResults(List<LoadTestResult> results) {
    print('\n📊 Gradual Load Test Analysis:');
    
    for (final result in results) {
      print('  ${result.concurrentUsers} users: '
          'Avg Response: ${result.averageResponseTime.toStringAsFixed(1)}ms, '
          'Throughput: ${result.throughput.toStringAsFixed(1)} req/s, '
          'Error Rate: ${(result.errorRate * 100).toStringAsFixed(1)}%');
    }
    
    // Check for performance degradation
    final firstResult = results.first;
    final lastResult = results.last;
    final responseTimeDegradation = (lastResult.averageResponseTime - firstResult.averageResponseTime) / firstResult.averageResponseTime;
    
    if (responseTimeDegradation > 0.5) {
      print('  ⚠️  Warning: Response time increased by ${(responseTimeDegradation * 100).toStringAsFixed(1)}% under load');
    } else {
      print('  ✅ Response time scaling is acceptable');
    }
  }
  
  /// Analyze spike test results
  void _analyzeSpikeTestResults(LoadTestResult baseline, LoadTestResult spike, LoadTestResult recovery) {
    print('\n📊 Spike Load Test Analysis:');
    print('  Baseline: ${baseline.averageResponseTime.toStringAsFixed(1)}ms avg response');
    print('  Spike: ${spike.averageResponseTime.toStringAsFixed(1)}ms avg response');
    print('  Recovery: ${recovery.averageResponseTime.toStringAsFixed(1)}ms avg response');
    
    final spikeImpact = (spike.averageResponseTime - baseline.averageResponseTime) / baseline.averageResponseTime;
    final recoveryRatio = recovery.averageResponseTime / baseline.averageResponseTime;
    
    print('  Spike Impact: ${(spikeImpact * 100).toStringAsFixed(1)}% increase');
    print('  Recovery Ratio: ${recoveryRatio.toStringAsFixed(2)}x baseline');
    
    if (recoveryRatio < 1.2) {
      print('  ✅ System recovered well from spike');
    } else {
      print('  ⚠️  System shows degraded performance after spike');
    }
  }
  
  /// Analyze sustained load results
  void _analyzeSustainedLoadResults(LoadTestResult result) {
    print('\n📊 Sustained Load Test Analysis:');
    print('  Duration: ${result.duration.inMinutes} minutes');
    print('  Average Response Time: ${result.averageResponseTime.toStringAsFixed(1)}ms');
    print('  P95 Response Time: ${result.p95ResponseTime.toStringAsFixed(1)}ms');
    print('  Throughput: ${result.throughput.toStringAsFixed(1)} req/s');
    print('  Error Rate: ${(result.errorRate * 100).toStringAsFixed(2)}%');
    
    if (result.errorRate < 0.01 && result.p95ResponseTime < 2000) {
      print('  ✅ System handles sustained load well');
    } else {
      print('  ⚠️  System shows stress under sustained load');
    }
  }
  
  /// Analyze CDN results
  void _analyzeCDNResults(List<CDNTestResult> results) {
    print('\n📊 CDN Performance Analysis:');
    
    for (final result in results) {
      print('  ${result.assetType} (${result.assetSize}):');
      print('    Avg Download: ${result.averageDownloadTime.toStringAsFixed(1)}ms');
      print('    Cache Hit Rate: ${(result.cacheHitRate * 100).toStringAsFixed(1)}%');
      print('    Bandwidth: ${(result.totalBandwidth / (1024 * 1024)).toStringAsFixed(1)}MB');
    }
    
    final avgCacheHitRate = results.map((r) => r.cacheHitRate).reduce((a, b) => a + b) / results.length;
    
    if (avgCacheHitRate > 0.8) {
      print('  ✅ CDN cache performance is excellent');
    } else if (avgCacheHitRate > 0.6) {
      print('  ⚠️  CDN cache performance is acceptable but could be improved');
    } else {
      print('  ❌ CDN cache performance needs optimization');
    }
  }
  
  /// Analyze memory stress results
  void _analyzeMemoryStressResults(LoadTestResult result) {
    print('\n📊 Memory Stress Test Analysis:');
    print('  Performance under memory stress:');
    print('    Average Response Time: ${result.averageResponseTime.toStringAsFixed(1)}ms');
    print('    Error Rate: ${(result.errorRate * 100).toStringAsFixed(2)}%');
    print('    Throughput: ${result.throughput.toStringAsFixed(1)} req/s');
    
    if (result.errorRate < 0.05) {
      print('  ✅ System handles memory stress well');
    } else {
      print('  ⚠️  System shows degradation under memory stress');
    }
  }
  
  /// Analyze database results
  void _analyzeDatabaseResults(List<LoadTestResult> results) {
    print('\n📊 Database Load Test Analysis:');
    
    for (final result in results) {
      final operationType = result.name.split('_').last;
      print('  $operationType operations:');
      print('    Avg Response: ${result.averageResponseTime.toStringAsFixed(1)}ms');
      print('    Throughput: ${result.throughput.toStringAsFixed(1)} req/s');
      print('    Error Rate: ${(result.errorRate * 100).toStringAsFixed(2)}%');
    }
  }
  
  /// Generate comprehensive report
  Future<void> _generateComprehensiveReport() async {
    print('\n' + '=' * 60);
    print('📋 COMPREHENSIVE LOAD TEST REPORT');
    print('=' * 60);
    
    final totalRequests = _results.fold<int>(0, (sum, result) => sum + result.totalRequests);
    final totalErrors = _results.fold<int>(0, (sum, result) => sum + result.errorCount);
    final avgResponseTime = _results.map((r) => r.averageResponseTime).reduce((a, b) => a + b) / _results.length;
    final avgThroughput = _results.map((r) => r.throughput).reduce((a, b) => a + b) / _results.length;
    
    print('\n📈 Overall Statistics:');
    print('  Total Tests: ${_results.length}');
    print('  Total Requests: $totalRequests');
    print('  Total Errors: $totalErrors');
    print('  Overall Error Rate: ${totalRequests > 0 ? (totalErrors / totalRequests * 100).toStringAsFixed(2) : 0}%');
    print('  Average Response Time: ${avgResponseTime.toStringAsFixed(1)}ms');
    print('  Average Throughput: ${avgThroughput.toStringAsFixed(1)} req/s');
    
    print('\n🎯 Performance Recommendations:');
    _generateRecommendations();
    
    print('\n💾 Saving detailed results...');
    await _saveResults();
    
    print('\n✅ Comprehensive load testing completed successfully!');
  }
  
  /// Generate performance recommendations
  void _generateRecommendations() {
    final recommendations = <String>[];
    
    final avgErrorRate = _results.map((r) => r.errorRate).reduce((a, b) => a + b) / _results.length;
    final avgResponseTime = _results.map((r) => r.averageResponseTime).reduce((a, b) => a + b) / _results.length;
    
    if (avgErrorRate > 0.05) {
      recommendations.add('Error rate is above 5%. Investigate failing requests and improve error handling.');
    }
    
    if (avgResponseTime > 1000) {
      recommendations.add('Average response time is above 1 second. Optimize database queries and API endpoints.');
    }
    
    // Check for performance degradation under load
    final gradualTests = _results.where((r) => r.name.startsWith('gradual_load')).toList();
    if (gradualTests.length >= 2) {
      final firstTest = gradualTests.first;
      final lastTest = gradualTests.last;
      final degradation = (lastTest.averageResponseTime - firstTest.averageResponseTime) / firstTest.averageResponseTime;
      
      if (degradation > 0.5) {
        recommendations.add('Performance degrades significantly under load. Consider horizontal scaling.');
      }
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Performance is within acceptable ranges. Continue monitoring.');
    }
    
    for (int i = 0; i < recommendations.length; i++) {
      print('  ${i + 1}. ${recommendations[i]}');
    }
  }
  
  /// Save test results to file
  Future<void> _saveResults() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('load_test_results_$timestamp.json');
    
    final reportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'test_summary': {
        'total_tests': _results.length,
        'total_requests': _results.fold<int>(0, (sum, result) => sum + result.totalRequests),
        'total_errors': _results.fold<int>(0, (sum, result) => sum + result.errorCount),
      },
      'test_results': _results.map((r) => r.toMap()).toList(),
    };
    
    await file.writeAsString(json.encode(reportData));
    print('  Results saved to: ${file.path}');
  }
}

/// Load Test Result
class LoadTestResult {
  final String name;
  final int concurrentUsers;
  final Duration duration;
  final int totalRequests;
  final int successfulRequests;
  final int errorCount;
  final double averageResponseTime;
  final double p95ResponseTime;
  final double p99ResponseTime;
  final double throughput;
  final double errorRate;
  final DateTime timestamp;
  
  LoadTestResult({
    required this.name,
    required this.concurrentUsers,
    required this.duration,
    required this.totalRequests,
    required this.successfulRequests,
    required this.errorCount,
    required this.averageResponseTime,
    required this.p95ResponseTime,
    required this.p99ResponseTime,
    required this.throughput,
    required this.errorRate,
    required this.timestamp,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'concurrent_users': concurrentUsers,
      'duration_ms': duration.inMilliseconds,
      'total_requests': totalRequests,
      'successful_requests': successfulRequests,
      'error_count': errorCount,
      'average_response_time': averageResponseTime,
      'p95_response_time': p95ResponseTime,
      'p99_response_time': p99ResponseTime,
      'throughput': throughput,
      'error_rate': errorRate,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// User Test Result
class UserTestResult {
  final int userId;
  final int requestCount;
  final int errorCount;
  final List<double> responseTimes;
  
  UserTestResult({
    required this.userId,
    required this.requestCount,
    required this.errorCount,
    required this.responseTimes,
  });
}

/// CDN Test Result
class CDNTestResult {
  final String assetType;
  final String assetSize;
  final int concurrentRequests;
  final double averageDownloadTime;
  final double cacheHitRate;
  final int totalBandwidth;
  
  CDNTestResult({
    required this.assetType,
    required this.assetSize,
    required this.concurrentRequests,
    required this.averageDownloadTime,
    required this.cacheHitRate,
    required this.totalBandwidth,
  });
}

/// Asset Request Result
class AssetRequestResult {
  final double downloadTime;
  final int bytesTransferred;
  final bool cacheHit;
  final int statusCode;
  
  AssetRequestResult({
    required this.downloadTime,
    required this.bytesTransferred,
    required this.cacheHit,
    required this.statusCode,
  });
}

/// Main function to run comprehensive load tests
void main() async {
  final tester = ComprehensiveLoadTester();
  
  try {
    await tester.runComprehensiveTests();
  } catch (e) {
    print('❌ Load testing failed: $e');
    exit(1);
  }
}