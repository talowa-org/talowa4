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
import 'services/performance_monitor.dart';
// import 'services/localization_service.dart';
// import 'services/rtl_support_service.dart';
// import 'services/messaging/message_translation_service.dart';
// import 'services/messaging/voice_transcription_service.dart';
import 'services/data_population_service.dart';
import 'services/remote_config_service.dart';
import 'services/bootstrap_service.dart';
import 'services/notifications/notification_service.dart';
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
  debugPrint('✅ Firebase initialized successfully');

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
    debugPrint('⚠️ Bootstrap failed, but app will continue: $e');
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
      debugPrint('Failed to initialize notification system: $e');
    }
  }

  runApp(const TalowaApp());
}

class TalowaApp extends StatelessWidget {
  const TalowaApp({super.key});

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
              '/login': (context) => const LoginScreen(),
              '/mobile-entry': (context) => const MobileEntryScreen(),
              '/register': (context) => const IntegratedRegistrationScreen(),
              '/main': (context) => const MainNavigationScreen(),
              '/ai-test': (context) => const AITestScreen(),
              // Land records
              '/land/records': (context) => const LandRecordsListScreen(),
              '/land/add': (context) => const LandRecordFormScreen(),
            },
            // onGenerateRoute for dynamic detail/edit routes
            onGenerateRoute: (settings) {
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
