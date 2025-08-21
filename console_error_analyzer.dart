import 'dart:io';

void main() async {
  print('🔍 TALOWA Console Error Analysis & Referral System Debug');
  print('======================================================');
  
  // Step 1: Analyze current codebase for potential console error sources
  print('\n📋 Step 1: Analyzing Codebase for Error Sources');
  await _analyzeCodebaseErrors();
  
  // Step 2: Check referral system components
  print('\n🔗 Step 2: Referral System Component Analysis');
  await _analyzeReferralSystem();
  
  // Step 3: Check Firebase integration issues
  print('\n🔥 Step 3: Firebase Integration Analysis');
  await _analyzeFirebaseIntegration();
  
  // Step 4: Check null safety and type issues
  print('\n🛡️ Step 4: Null Safety & Type Issues');
  await _analyzeNullSafetyIssues();
  
  // Step 5: Check import and dependency issues
  print('\n📦 Step 5: Import & Dependency Analysis');
  await _analyzeImportIssues();
  
  print('\n🎯 NEXT STEPS:');
  print('1. Please share the console error image/screenshot');
  print('2. I will analyze the specific errors shown');
  print('3. Apply targeted fixes for each error');
  print('4. Test the complete referral system flow');
  print('5. Ensure long-term stability');
}

Future<void> _analyzeCodebaseErrors() async {
  final criticalFiles = [
    'lib/main_fixed.dart',
    'lib/services/auth_service.dart',
    'lib/services/referral/referral_code_generator.dart',
    'lib/screens/auth/real_user_registration_screen.dart',
    'web/index.html'
  ];
  
  for (final filePath in criticalFiles) {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        
        // Check for common error patterns
        final errorPatterns = [
          'null check operator used on a null value',
          'AppLocalizations.of(context)!',
          'Navigator.of(context)!',
          'Theme.of(context)!',
          'MediaQuery.of(context)!',
          'Scaffold.of(context)!',
          'FormState.validate()!',
          'TextEditingController()!',
        ];
        
        bool hasIssues = false;
        for (final pattern in errorPatterns) {
          if (content.contains(pattern)) {
            if (!hasIssues) {
              print('⚠️  $filePath:');
              hasIssues = true;
            }
            print('  - Potential null safety issue: $pattern');
          }
        }
        
        if (!hasIssues) {
          print('✅ $filePath: No obvious error patterns');
        }
      } else {
        print('❌ $filePath: File not found');
      }
    } catch (e) {
      print('❌ $filePath: Analysis failed - $e');
    }
  }
}

Future<void> _analyzeReferralSystem() async {
  print('  🔍 Checking referral system components...');
  
  final referralFiles = [
    'lib/services/referral/referral_code_generator.dart',
    'lib/services/referral/referral_lookup_service.dart',
    'lib/services/referral_code_cache_service.dart',
    'lib/services/auth_service.dart'
  ];
  
  for (final filePath in referralFiles) {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        
        // Check for referral-specific issues
        if (filePath.contains('referral_code_generator')) {
          if (content.contains('generateUniqueCode') && 
              content.contains('TAL') && 
              content.contains('23456789ABCDEFGHJKMNPQRSTUVWXYZ')) {
            print('  ✅ ReferralCodeGenerator: Format and generation OK');
          } else {
            print('  ❌ ReferralCodeGenerator: Format or generation issues');
          }
        }
        
        if (filePath.contains('auth_service')) {
          if (content.contains('referralCode = await ReferralCodeGenerator.generateUniqueCode()')) {
            print('  ✅ AuthService: ReferralCode generation integrated');
          } else {
            print('  ❌ AuthService: ReferralCode generation not integrated');
          }
        }
        
      } else {
        print('  ❌ $filePath: Missing referral component');
      }
    } catch (e) {
      print('  ❌ $filePath: Analysis failed - $e');
    }
  }
}

Future<void> _analyzeFirebaseIntegration() async {
  print('  🔍 Checking Firebase integration...');
  
  try {
    // Check web/index.html for Firebase config
    final indexFile = File('web/index.html');
    if (await indexFile.exists()) {
      final content = await indexFile.readAsString();
      
      if (content.contains('firebase.initializeApp(firebaseConfig)')) {
        print('  ✅ Firebase initialization found in index.html');
      } else {
        print('  ❌ Firebase initialization missing in index.html');
      }
      
      if (content.contains('apiKey:') && content.contains('authDomain:')) {
        print('  ✅ Firebase config present');
      } else {
        print('  ❌ Firebase config incomplete');
      }
    }
    
    // Check main.dart for Firebase initialization
    final mainFile = File('lib/main_fixed.dart');
    if (await mainFile.exists()) {
      final content = await mainFile.readAsString();
      
      if (content.contains('Firebase.initializeApp')) {
        print('  ✅ Firebase initialization in main.dart');
      } else {
        print('  ❌ Firebase initialization missing in main.dart');
      }
    }
    
  } catch (e) {
    print('  ❌ Firebase analysis failed: $e');
  }
}

Future<void> _analyzeNullSafetyIssues() async {
  print('  🔍 Checking null safety patterns...');
  
  final files = [
    'lib/screens/auth/real_user_registration_screen.dart',
    'lib/services/auth_service.dart'
  ];
  
  for (final filePath in files) {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        
        // Count null assertion operators
        final nullAssertions = '!'.allMatches(content).length;
        final nullChecks = '?'.allMatches(content).length;
        
        print('  📊 $filePath:');
        print('    - Null assertions (!): $nullAssertions');
        print('    - Null checks (?): $nullChecks');
        
        if (nullAssertions > nullChecks * 2) {
          print('    ⚠️  High null assertion ratio - potential runtime errors');
        } else {
          print('    ✅ Reasonable null safety pattern');
        }
      }
    } catch (e) {
      print('  ❌ $filePath: Null safety analysis failed - $e');
    }
  }
}

Future<void> _analyzeImportIssues() async {
  print('  🔍 Checking import and dependency issues...');
  
  try {
    final pubspecFile = File('pubspec.yaml');
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      
      final requiredDeps = [
        'firebase_core',
        'firebase_auth',
        'cloud_firestore',
        'flutter_localizations'
      ];
      
      for (final dep in requiredDeps) {
        if (content.contains(dep)) {
          print('  ✅ $dep: Present in pubspec.yaml');
        } else {
          print('  ❌ $dep: Missing from pubspec.yaml');
        }
      }
    }
    
    // Check for circular imports or missing imports
    final authService = File('lib/services/auth_service.dart');
    if (await authService.exists()) {
      final content = await authService.readAsString();
      
      if (content.contains('import \'referral/referral_code_generator.dart\'')) {
        print('  ✅ ReferralCodeGenerator import present');
      } else {
        print('  ❌ ReferralCodeGenerator import missing');
      }
    }
    
  } catch (e) {
    print('  ❌ Import analysis failed: $e');
  }
}
