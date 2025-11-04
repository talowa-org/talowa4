import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'performance_test_framework.dart';

/// Load Test Runner for Talowa Performance Testing
/// Executes various load testing scenarios
void main() {
  group('Talowa Performance Load Tests', () {
    late PerformanceTestFramework framework;
    
    setUp(() {
      framework = PerformanceTestFramework();
    });
    
    testWidgets('Light Load Test - 1K Users', (WidgetTester tester) async {
      print('🧪 Running Light Load Test (1,000 users)');
      
      final scenarios = [
        TestScenario(type: ScenarioType.loadFeed, weight: 0.4),
        TestScenario(type: ScenarioType.scrollFeed, weight: 0.3),
        TestScenario(type: ScenarioType.createPost, weight: 0.2),
        TestScenario(type: ScenarioType.searchContent, weight: 0.1),
      ];
      
      final results = await framework.runLoadTest(
        concurrentUsers: 1000,
        testDuration: Duration(minutes: 5),
        scenarios: scenarios,
      );
      
      print(results.generateReport());
      
      // Assertions for light load
      expect(results.errorCounts.values.fold(0, (sum, count) => sum + count), 
             lessThan(10), reason: 'Too many errors in light load test');
      
      // Response time should be reasonable
      results.responseTimeMetrics.forEach((operation, stats) {
        expect(stats.p95, lessThan(2000), 
               reason: '$operation P95 response time too high: ${stats.p95}ms');
      });
    });
    
    testWidgets('Medium Load Test - 10K Users', (WidgetTester tester) async {
      print('🧪 Running Medium Load Test (10,000 users)');
      
      final scenarios = [
        TestScenario(type: ScenarioType.loadFeed, weight: 0.35),
        TestScenario(type: ScenarioType.scrollFeed, weight: 0.25),
        TestScenario(type: ScenarioType.createPost, weight: 0.15),
        TestScenario(type: ScenarioType.uploadMedia, weight: 0.15),
        TestScenario(type: ScenarioType.searchContent, weight: 0.1),
      ];
      
      final results = await framework.runLoadTest(
        concurrentUsers: 10000,
        testDuration: Duration(minutes: 10),
        scenarios: scenarios,
      );
      
      print(results.generateReport());
      
      // Assertions for medium load
      expect(results.errorCounts.values.fold(0, (sum, count) => sum + count), 
             lessThan(100), reason: 'Too many errors in medium load test');
      
      // Response time should still be acceptable
      results.responseTimeMetrics.forEach((operation, stats) {
        expect(stats.p95, lessThan(5000), 
               reason: '$operation P95 response time too high: ${stats.p95}ms');
      });
    });
    
    testWidgets('Heavy Load Test - 100K Users', (WidgetTester tester) async {
      print('🧪 Running Heavy Load Test (100,000 users)');
      
      final scenarios = [
        TestScenario(type: ScenarioType.loadFeed, weight: 0.3),
        TestScenario(type: ScenarioType.scrollFeed, weight: 0.3),
        TestScenario(type: ScenarioType.createPost, weight: 0.2),
        TestScenario(type: ScenarioType.uploadMedia, weight: 0.1),
        TestScenario(type: ScenarioType.searchContent, weight: 0.1),
      ];
      
      final results = await framework.runLoadTest(
        concurrentUsers: 100000,
        testDuration: Duration(minutes: 15),
        scenarios: scenarios,
      );
      
      print(results.generateReport());
      
      // Assertions for heavy load
      expect(results.errorCounts.values.fold(0, (sum, count) => sum + count), 
             lessThan(1000), reason: 'Too many errors in heavy load test');
      
      // Response time degradation is expected but should be bounded
      results.responseTimeMetrics.forEach((operation, stats) {
        expect(stats.p95, lessThan(10000), 
               reason: '$operation P95 response time too high: ${stats.p95}ms');
      });
    });
    
    testWidgets('Extreme Load Test - 1M Users', (WidgetTester tester) async {
      print('🧪 Running Extreme Load Test (1,000,000 users)');
      
      final scenarios = [
        TestScenario(type: ScenarioType.loadFeed, weight: 0.4),
        TestScenario(type: ScenarioType.scrollFeed, weight: 0.4),
        TestScenario(type: ScenarioType.createPost, weight: 0.1),
        TestScenario(type: ScenarioType.uploadMedia, weight: 0.05),
        TestScenario(type: ScenarioType.searchContent, weight: 0.05),
      ];
      
      final results = await framework.runLoadTest(
        concurrentUsers: 1000000,
        testDuration: Duration(minutes: 20),
        scenarios: scenarios,
      );
      
      print(results.generateReport());
      
      // Assertions for extreme load - more lenient
      final totalErrors = results.errorCounts.values.fold(0, (sum, count) => sum + count);
      final errorRate = totalErrors / results.concurrentUsers;
      expect(errorRate, lessThan(0.05), 
             reason: 'Error rate too high: ${(errorRate * 100).toStringAsFixed(2)}%');
      
      // System should still be responsive, though slower
      results.responseTimeMetrics.forEach((operation, stats) {
        expect(stats.p95, lessThan(30000), 
               reason: '$operation P95 response time too high: ${stats.p95}ms');
      });
    });
    
    testWidgets('Ultimate Load Test - 10M Users', (WidgetTester tester) async {
      print('🧪 Running Ultimate Load Test (10,000,000 users)');
      print('⚠️  This test simulates the maximum expected load');
      
      final scenarios = [
        TestScenario(type: ScenarioType.loadFeed, weight: 0.5),
        TestScenario(type: ScenarioType.scrollFeed, weight: 0.4),
        TestScenario(type: ScenarioType.createPost, weight: 0.05),
        TestScenario(type: ScenarioType.uploadMedia, weight: 0.03),
        TestScenario(type: ScenarioType.searchContent, weight: 0.02),
      ];
      
      final results = await framework.runLoadTest(
        concurrentUsers: 10000000,
        testDuration: Duration(minutes: 30),
        scenarios: scenarios,
      );
      
      print(results.generateReport());
      
      // Save results to file for analysis
      await _saveResultsToFile(results, '10M_users_load_test');
      
      // Assertions for ultimate load - focus on system stability
      final totalErrors = results.errorCounts.values.fold(0, (sum, count) => sum + count);
      final errorRate = totalErrors / results.concurrentUsers;
      expect(errorRate, lessThan(0.1), 
             reason: 'Error rate too high for 10M users: ${(errorRate * 100).toStringAsFixed(2)}%');
      
      // System should remain functional even under extreme load
      results.responseTimeMetrics.forEach((operation, stats) {
        expect(stats.p99, lessThan(60000), 
               reason: '$operation P99 response time too high: ${stats.p99}ms');
      });
      
      // Throughput should be reasonable
      results.throughputMetrics.forEach((operation, throughput) {
        expect(throughput, greaterThan(0.1), 
               reason: '$operation throughput too low: $throughput ops/sec');
      });
    });
    
    testWidgets('Memory Usage Analysis', (WidgetTester tester) async {
      print('🧪 Running Memory Usage Analysis');
      
      final memoryResults = await framework.analyzeMemoryUsage();
      
      print('💾 Memory Usage Results:');
      print('  Heap Usage: ${memoryResults.heapUsage} MB');
      print('  Cache Size: ${memoryResults.cacheSize} MB');
      print('  Image Cache: ${memoryResults.imageCache} MB');
      print('  Total Memory: ${memoryResults.totalMemory} MB');
      
      // Memory usage assertions
      expect(memoryResults.totalMemory, lessThan(500), 
             reason: 'Total memory usage too high');
      expect(memoryResults.heapUsage, lessThan(200), 
             reason: 'Heap usage too high');
      expect(memoryResults.imageCache, lessThan(100), 
             reason: 'Image cache too large');
    });
    
    testWidgets('Network Performance Analysis', (WidgetTester tester) async {
      print('🧪 Running Network Performance Analysis');
      
      final networkResults = await framework.analyzeNetworkPerformance();
      
      print('🌐 Network Performance Results:');
      print('  Average Latency: ${networkResults.averageLatency} ms');
      print('  Bandwidth: ${networkResults.bandwidth} Mbps');
      print('  Packet Loss: ${(networkResults.packetLoss * 100).toStringAsFixed(2)}%');
      print('  Connection Errors: ${networkResults.connectionErrors}');
      
      // Network performance assertions
      expect(networkResults.averageLatency, lessThan(500), 
             reason: 'Network latency too high');
      expect(networkResults.packetLoss, lessThan(0.05), 
             reason: 'Packet loss too high');
      expect(networkResults.connectionErrors, lessThan(10), 
             reason: 'Too many connection errors');
    });
  });
}

/// Saves test results to a file for further analysis
Future<void> _saveResultsToFile(PerformanceTestResults results, String testName) async {
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final fileName = 'performance_results_${testName}_$timestamp.txt';
  final file = File('test/performance/results/$fileName');
  
  // Create directory if it doesn't exist
  await file.parent.create(recursive: true);
  
  // Write results to file
  await file.writeAsString(results.generateReport());
  
  print('📄 Results saved to: ${file.path}');
}