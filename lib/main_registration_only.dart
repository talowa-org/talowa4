import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/real_user_registration_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('TALOWA Registration Test - Web Only');
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

  debugPrint('🚀 Starting TALOWA Registration Test...');

  runApp(const TalowaRegistrationTestApp());
}

class TalowaRegistrationTestApp extends StatelessWidget {
  const TalowaRegistrationTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TALOWA Registration Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TestRegistrationWrapper(),
    );
  }
}

class TestRegistrationWrapper extends StatelessWidget {
  const TestRegistrationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TALOWA Registration Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TALOWA Registration Test',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Testing registration functionality',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 40),
            Expanded(
              child: RealUserRegistrationScreen(),
            ),
          ],
        ),
      ),
    );
  }
}
