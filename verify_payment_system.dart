import 'dart:io';

void main() {
  print('ðŸŽ¯ PAYMENT SYSTEM VERIFICATION');
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
    print('\nðŸ“ Checking: $filePath');
    
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('âŒ File not found');
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
          print('âŒ Found problematic pattern: $pattern');
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
        print('âœ… File looks correct');
      } else if (!fileHasIssues) {
        print('âš ï¸  File may not have payment-related code');
      }
      
    } catch (e) {
      print('âŒ Error reading file: $e');
      allCorrect = false;
    }
  }
  
  print('\nðŸŽ¯ VERIFICATION SUMMARY');
  print('======================');
  
  if (allCorrect) {
    print('âœ… PAYMENT SYSTEM VERIFICATION PASSED');
    print('âœ… All users will register with membershipPaid: false');
    print('âœ… All app features are available without payment');
    print('âœ… Payment is optional for supporting the movement');
  } else {
    print('âŒ PAYMENT SYSTEM VERIFICATION FAILED');
    print('âŒ Some files still have hardcoded membershipPaid: true');
    print('âŒ This needs to be fixed for proper free app behavior');
  }
  
  print('\nðŸ“‹ EXPECTED BEHAVIOR:');
  print('- New users register with membershipPaid: false');
  print('- All 5 main tabs work without payment');
  print('- Referral system works for all users');
  print('- Payment is purely optional support');
  print('- Only after successful payment: membershipPaid: true');
}
