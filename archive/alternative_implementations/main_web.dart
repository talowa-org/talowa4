import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
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
  
  debugPrint('ðŸŒ Starting TALOWA Web App (Firebase disabled for compatibility)');
  
  // Initialize performance monitoring (works without Firebase)
  PerformanceMonitor.logMemoryUsage('app_startup');

  runApp(const TalowaWebApp());
}

class TalowaWebApp extends StatelessWidget {
  const TalowaWebApp({super.key});

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
