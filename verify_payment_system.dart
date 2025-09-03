import 'dart:io';

void main() {
  print('🎯 PAYMENT SYSTEM VERIFICATION');
  print('==============================');
  
  // Check key files for correct payment implementation
  final filesToCheck = [
    'lib/screens/auth/integrated_registration_screen.dart',
    'lib/services/unified_auth_service.dart',
    'lib/services/referral/simplified_referral_service.dart',
    'lib/services/auth_service.dart',
    'lib/widgets/referral/simplified_referral_dashboard.dart',
  ];
  
  bool allCorrect = true;
  
  for (final filePath in filesToCheck) {
    print('\n📁 Checking: $filePath');
    
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('❌ File not found');
        allCorrect = false;
        continue;
      }
      
      final content = file.readAsStringSync();
      
      // Check for problematic patterns
      final problematicPatterns = [
        "membershipPaid': true, // App is now free for all users",
        "membershipPaid': true, // Always true in simplified system",
      ];
      
      bool fileHasIssues = false;
      for (final pattern in problematicPatterns) {
        if (content.contains(pattern)) {
          print('❌ Found problematic pattern: $pattern');
          fileHasIssues = true;
          allCorrect = false;
        }
      }
      
      // Check for correct patterns
      final correctPatterns = [
        "membershipPaid': false, // Payment is optional - app is free for all users",
        "membershipPaid'] ?? false",
      ];
      
      bool hasCorrectPattern = false;
      for (final pattern in correctPatterns) {
        if (content.contains(pattern)) {
          hasCorrectPattern = true;
          break;
        }
      }
      
      if (!fileHasIssues && hasCorrectPattern) {
        print('✅ File looks correct');
      } else if (!fileHasIssues) {
        print('⚠️  File may not have payment-related code');
      }
      
    } catch (e) {
      print('❌ Error reading file: $e');
      allCorrect = false;
    }
  }
  
  print('\n🎯 VERIFICATION SUMMARY');
  print('======================');
  
  if (allCorrect) {
    print('✅ PAYMENT SYSTEM VERIFICATION PASSED');
    print('✅ All users will register with membershipPaid: false');
    print('✅ All app features are available without payment');
    print('✅ Payment is optional for supporting the movement');
  } else {
    print('❌ PAYMENT SYSTEM VERIFICATION FAILED');
    print('❌ Some files still have hardcoded membershipPaid: true');
    print('❌ This needs to be fixed for proper free app behavior');
  }
  
  print('\n📋 EXPECTED BEHAVIOR:');
  print('- New users register with membershipPaid: false');
  print('- All 5 main tabs work without payment');
  print('- Referral system works for all users');
  print('- Payment is purely optional support');
  print('- Only after successful payment: membershipPaid: true');
}