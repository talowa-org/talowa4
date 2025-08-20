import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/new_login_screen.dart';
import 'screens/auth/real_user_registration_screen.dart';
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
import 'services/messaging/talowa_messaging_integration.dart';
import 'services/notifications/notification_service.dart';
import 'providers/localization_provider.dart';
import 'generated/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  // Initialize performance monitoring
  PerformanceMonitor.logMemoryUsage('app_startup');

  // Fix user roles and populate missing data collections (runs in background)
  // Note: This will run after user authentication in the app
  DataPopulationService.populateIfNeeded();

  // Bootstrap admin user and migrate legacy data
  BootstrapService.bootstrap();

  // Initialize messaging integration system
  // try {
  //   await TalowaMessagingIntegration().initialize();
  // } catch (e) {
  //   debugPrint('Failed to initialize messaging integration: $e');
  // }

  // Initialize notification system
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize notification system: $e');
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
        '/login': (context) => const NewLoginScreen(),
        '/register': (context) => const RealUserRegistrationScreen(),
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
          return MaterialPageRoute(builder: (_) => LandRecordDetailScreen(recordId: id));
        }
        if (settings.name == '/land/edit') {
          final initial = settings.arguments as dynamic;
          return MaterialPageRoute(builder: (_) => LandRecordFormScreen(initial: initial));
        }
        return null;
      },
          );
        },
      ),
    );
  }
}
