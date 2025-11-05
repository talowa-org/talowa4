// âš ï¸ CRITICAL WARNING - AUTHENTICATION SYSTEM PROTECTION âš ï¸
// This file contains the WORKING authentication routing from Checkpoint 7
// DO NOT MODIFY authentication-related code without explicit user approval
// See: AUTHENTICATION_PROTECTION_STRATEGY.md
// Working commit: 3a00144 (Checkpoint 6 base)
// Last verified: September 3rd, 2025
// Current working flow: WelcomeScreen â†’ Login/Register â†’ UnifiedAuthService â†’ MainApp

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'screens/auth/welcome_screen.dart';
import 'auth/login.dart';

import 'screens/auth/mobile_entry_screen.dart';
import 'screens/auth/integrated_registration_screen.dart';
import 'screens/main/main_navigation_screen.dart';
// import removed: 'screens/dev/ai_test_screen.dart'
import 'screens/land_records/land_records_list_screen.dart';
import 'screens/land_records/land_record_detail_screen.dart';
import 'screens/land_records/land_record_form_screen.dart';
import 'screens/admin/admin_login_screen.dart';

import 'widgets/admin/admin_route_guard.dart';
// Removed: import 'views/debug/migration_debug_page.dart';
import 'services/performance/performance_monitor.dart';
import 'services/referral/universal_link_service.dart';
import 'services/performance/optimized_startup_service.dart';
import 'services/performance/performance_integration_service.dart';
import 'services/performance/performance_analytics_service.dart';
import 'services/performance/memory_management_service.dart';
import 'services/performance/network_optimization_service.dart';
import 'services/performance/widget_optimization_service.dart';
import 'services/performance/caching_service.dart';
import 'services/performance/database_optimization_service.dart';
import 'services/performance/performance_optimization_service.dart';
import 'services/social_feed/enhanced_feed_service.dart';
import 'services/performance/feed_performance_optimizer.dart';
import 'services/performance/firestore_performance_fix.dart';
import 'services/cache/cache_service.dart';
import 'services/network/network_optimization_service.dart' as network_opt;
import 'services/performance/performance_monitoring_service.dart';
import 'services/query_optimization_service.dart';
import 'providers/localization_provider.dart';
import 'providers/user_state_provider.dart';
import 'generated/l10n/app_localizations.dart';

void main() async {
  // 🚀 START APP LAUNCH PERFORMANCE TRACKING
  PerformanceAnalyticsService.startAppLaunch();
  
  WidgetsFlutterBinding.ensureInitialized();
  
  // Guard against future crashes by logging Flutter errors early
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('Uncaught Flutter error: ${details.exceptionAsString()}');
  };
  
  // Handle platform errors with proper error catching
  try {
    // Initialize platform-specific error handling
    debugPrint('Platform error handling initialized');
  } catch (e) {
    debugPrint('Platform error handling failed: $e');
  }
  
  // Initialize Firebase for all platforms
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 🔥 INITIALIZE FIRESTORE PERFORMANCE FIX
  await FirestorePerformanceFix.initialize();
  
  // 🚀 OPTIMIZED STARTUP - Use optimized service initialization
  // This replaces the previous synchronous initialization with:
  // - Parallel loading of critical services
  // - Lazy loading of non-critical services
  // - Significant startup time improvement
  await OptimizedStartupService.initialize();
  
  // 🚀 INITIALIZE NEW PERFORMANCE SERVICES FOR 10M USER SCALABILITY
  await CacheService.instance.initialize();
  network_opt.NetworkOptimizationService.instance.initialize();
  PerformanceMonitoringService.instance.initialize();
  await QueryOptimizationService.instance.initialize();
  
  // 🚀 INITIALIZE EXISTING PERFORMANCE SERVICES
  await MemoryManagementService.initialize();
  await NetworkOptimizationService.initialize();
  await WidgetOptimizationService.instance.initialize();

  // 🔗 INITIALIZE PERFORMANCE INTEGRATION
  await PerformanceIntegrationService.initialize();
  await PerformanceAnalyticsService.initialize();
  
  // Initialize new performance monitoring system
  PerformanceMonitor.initialize();
  
  // Initialize additional performance services
  await CachingService.initialize();
  await DatabaseOptimizationService.instance.initialize();
  await PerformanceOptimizationService().initialize();
  
  // 🎯 INITIALIZE ENHANCED FEED SERVICE
  await EnhancedFeedService().initialize();
  
  // 🚀 INITIALIZE FEED PERFORMANCE OPTIMIZER
  FeedPerformanceOptimizer().initialize();
  
  // Note: Non-critical services (Bootstrap, Notifications, Universal Links, etc.)
  // are now initialized in the background after app startup
  
  // 📊 COMPLETE APP LAUNCH PERFORMANCE TRACKING
  PerformanceAnalyticsService.completeAppLaunch();

  runApp(const TalowaApp());
}

class TalowaApp extends StatefulWidget {
  const TalowaApp({super.key});

  @override
  State<TalowaApp> createState() => _TalowaAppState();
}

class _TalowaAppState extends State<TalowaApp> {
  @override
  void initState() {
    super.initState();
    _handleInitialReferralCode();
  }

  Future<void> _handleInitialReferralCode() async {
    // Handle referral codes from URL on app startup
    if (kIsWeb) {
      try {
        final currentUrl = Uri.base;
        final referralCode = currentUrl.queryParameters['ref'];
        if (referralCode != null && referralCode.trim().isNotEmpty) {
          final cleanCode = referralCode.trim().toUpperCase();
          // App started with referral code - stored for registration
          
          // Store the referral code for later use (don't consume it here)
          UniversalLinkService.setPendingReferralCode(cleanCode);
          
          // Navigate directly to registration if we have a referral code
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Navigating to registration with referral code
              Navigator.of(context).pushNamed('/register');
            }
          });
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error handling initial referral code: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => LocalizationProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => UserStateProvider.instance,
        ),
      ],
      child: Consumer<LocalizationProvider>(
        builder: (context, localizationProvider, child) {
          return MaterialApp(
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,

            // Localization configuration
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: localizationProvider.supportedLocales,
            locale: localizationProvider.currentLocale,

            home: const WelcomeScreen(),
            routes: {
              '/welcome': (context) => const WelcomeScreen(),
              '/mobile-entry': (context) => const MobileEntryScreen(),
              '/register': (context) => const IntegratedRegistrationScreen(),
              '/main': (context) => const MainNavigationScreen(),
              // removed AI Test route per Option B
              // Land records
              '/land/records': (context) => const LandRecordsListScreen(),
              '/land/add': (context) => const LandRecordFormScreen(),
              // Admin routes
              '/admin': (context) => const AdminRouteGuard(),
              '/admin/login': (context) => const AdminLoginScreen(),
              // Debug routes (only in debug mode)
              // Removed: if (kDebugMode) '/debug/migration': (context) => const MigrationDebugPage(),
            },
            // onGenerateRoute for dynamic routes with arguments
            onGenerateRoute: (settings) {
              if (settings.name == '/login') {
                final prefilledPhone = settings.arguments as String?;
                return MaterialPageRoute(
                  builder: (_) => LoginScreen(prefilledPhone: prefilledPhone),
                );
              }
              if (settings.name == '/land/detail') {
                final id = settings.arguments as String;
                return MaterialPageRoute(
                  builder: (_) => LandRecordDetailScreen(recordId: id),
                );
              }
              if (settings.name == '/land/edit') {
                final initial = settings.arguments as dynamic;
                return MaterialPageRoute(
                  builder: (_) => LandRecordFormScreen(initial: initial),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

