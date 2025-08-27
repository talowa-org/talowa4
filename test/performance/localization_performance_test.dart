import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:talowa/services/localization_service.dart';
import 'package:talowa/services/localization_performance_monitor.dart';

void main() {
  group('Localization Performance Tests', () {
    late LocalizationService localizationService;
    late LocalizationPerformanceMonitor performanceMonitor;

    setUp(() {
      localizationService = LocalizationService();
      performanceMonitor = LocalizationPerformanceMonitor();
    });

    tearDown(() {
      performanceMonitor.clearMeasurements();
    });

    testWidgets('Language switching performance benchmark', (tester) async {
      await localizationService.initialize();
      
      final benchmark = await performanceMonitor.benchmarkLanguageSwitching(
        switchFunction: () async {
          await localizationService.changeLanguage(const Locale('hi', 'IN'));
          await tester.pump();
          await localizationService.changeLanguage(const Locale('te', 'IN'));
          await tester.pump();
          await localizationService.changeLanguage(const Locale('en', 'US'));
          await tester.pump();
        },
        iterations: 10,
      );

      print('Language Switching Benchmark Results:');
      print('Average: ${benchmark['average_ms']}ms');
      print('Min: ${benchmark['min_ms']}ms');
      print('Max: ${benchmark['max_ms']}ms');
      print('Median: ${benchmark['median_ms']}ms');

      // Performance assertions
      expect(benchmark['average_ms'], lessThan(100), 
          reason: 'Language switching should be under 100ms on average');
      expect(benchmark['max_ms'], lessThan(200), 
          reason: 'Maximum language switching time should be under 200ms');
    });

    test('Startup time benchmark with different languages', () async {
      final benchmark = await performanceMonitor.benchmarkStartupTime(
        initFunction: (languageCode) async {
          final locale = Locale(languageCode, 'IN');
          await localizationService.changeLanguage(locale);
        },
        languageCodes: ['en', 'hi', 'te'],
      );

      print('Startup Time Benchmark Results:');
      for (final entry in benchmark.entries) {
        final languageCode = entry.key;
        final stats = entry.value;
        print('$languageCode: Average ${stats['average_ms']}ms, '
              'Min ${stats['min_ms']}ms, Max ${stats['max_ms']}ms');
        
        // Performance assertions for each language
        expect(stats['average_ms'], lessThan(50), 
            reason: 'Startup with $languageCode should be under 50ms');
      }
    });

    test('Memory usage during language operations', () async {
      await localizationService.initialize();
      
      // Record initial memory state
      final initialStats = localizationService.getMemoryStats();
      expect(initialStats['cachedLanguages'], equals(0));
      
      // Preload all languages and measure memory
      for (final locale in LocalizationService.supportedLocales) {
        performanceMonitor.startMeasurement('preload_${locale.languageCode}');
        await localizationService.preloadLanguage(locale);
        performanceMonitor.endMeasurement('preload_${locale.languageCode}');
      }
      
      final afterPreloadStats = localizationService.getMemoryStats();
      expect(afterPreloadStats['preloadedLanguages'], 
          equals(LocalizationService.supportedLocales.length));
      
      // Test memory cleanup
      // Note: In a real test, you would measure actual memory usage
      final performanceStats = performanceMonitor.getPerformanceStats();
      print('Performance Stats: $performanceStats');
      
      // Verify preloading performance
      for (final locale in LocalizationService.supportedLocales) {
        final preloadKey = 'preload_${locale.languageCode}';
        final avgDuration = performanceMonitor.getAverageDuration(preloadKey);
        if (avgDuration != null) {
          expect(avgDuration.inMilliseconds, lessThan(30), 
              reason: 'Language preloading should be under 30ms');
        }
      }
    });

    test('Concurrent language switching stress test', () async {
      await localizationService.initialize();
      
      final futures = <Future>[];
      const locales = LocalizationService.supportedLocales;
      
      // Create multiple concurrent language switches
      for (int i = 0; i < 20; i++) {
        final locale = locales[i % locales.length];
        futures.add(localizationService.changeLanguage(locale));
      }
      
      performanceMonitor.startMeasurement('concurrent_switches');
      await Future.wait(futures);
      performanceMonitor.endMeasurement('concurrent_switches');
      
      final duration = performanceMonitor.getAverageDuration('concurrent_switches');
      expect(duration?.inMilliseconds, lessThan(500), 
          reason: 'Concurrent language switches should complete under 500ms');
    });

    test('Language resource caching efficiency', () async {
      await localizationService.initialize();
      
      // First load - should be slower (cache miss)
      performanceMonitor.startMeasurement('first_load_hi');
      await localizationService.changeLanguage(const Locale('hi', 'IN'));
      performanceMonitor.endMeasurement('first_load_hi');
      
      // Second load - should be faster (cache hit)
      performanceMonitor.startMeasurement('second_load_hi');
      await localizationService.changeLanguage(const Locale('en', 'US'));
      await localizationService.changeLanguage(const Locale('hi', 'IN'));
      performanceMonitor.endMeasurement('second_load_hi');
      
      final firstLoad = performanceMonitor.getAverageDuration('first_load_hi');
      final secondLoad = performanceMonitor.getAverageDuration('second_load_hi');
      
      if (firstLoad != null && secondLoad != null) {
        print('First load: ${firstLoad.inMilliseconds}ms');
        print('Second load: ${secondLoad.inMilliseconds}ms');
        
        // Second load should be faster due to caching
        expect(secondLoad.inMilliseconds, lessThanOrEqualTo(firstLoad.inMilliseconds),
            reason: 'Cached language loading should be faster or equal');
      }
    });

    test('Performance regression detection', () async {
      await localizationService.initialize();
      
      // Baseline performance measurements
      final baselineBenchmark = await performanceMonitor.benchmarkLanguageSwitching(
        switchFunction: () async {
          await localizationService.changeLanguage(const Locale('hi', 'IN'));
          await localizationService.changeLanguage(const Locale('en', 'US'));
        },
        iterations: 5,
      );
      
      // Performance thresholds (adjust based on your requirements)
      const maxAverageMs = 50.0;
      const maxMedianMs = 40.0;
      
      expect(baselineBenchmark['average_ms'], lessThan(maxAverageMs),
          reason: 'Average language switching time regression detected');
      expect(baselineBenchmark['median_ms'], lessThan(maxMedianMs),
          reason: 'Median language switching time regression detected');
      
      print('Performance baseline established:');
      print('Average: ${baselineBenchmark['average_ms']}ms (threshold: ${maxAverageMs}ms)');
      print('Median: ${baselineBenchmark['median_ms']}ms (threshold: ${maxMedianMs}ms)');
    });
  });
}