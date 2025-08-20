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
import 'providers/localization_provider.dart';
import 'generated/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('TALOWA Web App Starting...');
  debugPrint('Platform: ${kIsWeb ? "Web" : "Mobile"}');
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully for web');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    // Continue without Firebase - app should still work for basic functionality
  }

  // Skip all background services on web to prevent permission errors
  debugPrint('🌐 Web platform detected - skipping background services');
  debugPrint('📱 Background services (data population, admin bootstrap, etc.) are disabled on web');
  debugPrint('🚀 Starting TALOWA web app...');

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