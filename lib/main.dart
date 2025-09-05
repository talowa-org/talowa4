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
import 'screens/dev/ai_test_screen.dart';
import 'screens/land_records/land_records_list_screen.dart';
import 'screens/land_records/land_record_detail_screen.dart';
import 'screens/land_records/land_record_form_screen.dart';
import 'screens/admin/admin_login_screen.dart';

import 'widgets/admin/admin_route_guard.dart';
import 'views/debug/migration_debug_page.dart';
import 'services/performance_monitor.dart';
// import 'services/localization_service.dart';
// import 'services/rtl_support_service.dart';
// import 'services/messaging/message_translation_service.dart';
// import 'services/messaging/voice_transcription_service.dart';
import 'services/data_population_service.dart';
import 'services/remote_config_service.dart';
import 'services/bootstrap_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/referral/universal_link_service.dart';
import 'providers/localization_provider.dart';
import 'generated/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Guard against future crashes by logging Flutter errors early
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('Uncaught Flutter error: ${details.exceptionAsString()}');
  };
  
  // Initialize Firebase for all platforms
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase initialized successfully



  // Initialize localization service
  // await LocalizationService.initialize();

  // Initialize RTL support service
  // await RTLSupportService.initialize();

  // Initialize message translation service
  // await MessageTranslationService.initialize();

  // Initialize voice transcription service
  // await VoiceTranscriptionService.initialize();

  // Initialize Remote Config (feature flags)
  await RemoteConfigService.init();

  // Fix user roles and populate missing data collections (runs in background)
  // Note: This will run after user authentication in the app
  DataPopulationService.populateIfNeeded();

  // Bootstrap admin user and migrate legacy data
  try {
    await BootstrapService.bootstrap();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Bootstrap failed, but app will continue: $e');
    }
    // Don't let bootstrap failures prevent app startup
  }

  // Initialize performance monitoring (works without Firebase)
  PerformanceMonitor.logMemoryUsage('app_startup');

  // Initialize messaging integration system
  // try {
  //   await TalowaMessagingIntegration().initialize();
  // } catch (e) {
  //   debugPrint('Failed to initialize messaging integration: $e');
  // }

  // Initialize notification system (skip on web to avoid console errors)
  if (!kIsWeb) {
    try {
      await NotificationService.initialize();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize notification system: $e');
      }
    }
  }

  // Initialize Universal Link Service for referral code handling
  try {
    await UniversalLinkService.initialize();
    // Universal Link Service initialized
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Failed to initialize Universal Link Service: $e');
    }
  }

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
              '/ai-test': (context) => const AITestScreen(),
              // Land records
              '/land/records': (context) => const LandRecordsListScreen(),
              '/land/add': (context) => const LandRecordFormScreen(),
              // Admin routes
              '/admin': (context) => const AdminRouteGuard(),
              '/admin/login': (context) => const AdminLoginScreen(),
              // Debug routes (only in debug mode)
              if (kDebugMode) '/debug/migration': (context) => const MigrationDebugPage(),
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

