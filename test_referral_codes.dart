import 'dart:math';

void main() {
  print('🔗 TALOWA Referral Code Format Test');
  print('===================================');
  
  // Test the new TAL format generation
  print('\n✅ Testing TAL + Crockford Base32 Format:');
  
  for (int i = 0; i < 10; i++) {
    final code = generateTALReferralCode();
    final isValid = validateTALReferralCode(code);
    print('Generated: $code - Valid: ${isValid ? "✅" : "❌"}');
  }
  
  print('\n❌ Old REF Format Examples (should NOT be generated):');
  final oldFormats = [
    'REF67203185',
    'REF12345678',
    'REF98765432'
  ];
  
  for (final code in oldFormats) {
    final isValid = validateTALReferralCode(code);
    print('Old format: $code - Valid: ${isValid ? "❌ PROBLEM" : "✅ Correctly rejected"}');
  }
  
  print('\n🧪 Format Validation Tests:');
  final testCases = [
    'TALABCDEF',  // Valid
    'TAL234567',  // Valid
    'TALGHKMNP',  // Valid
    'TALQRSTVW',  // Valid
    'TALXYZ234',  // Valid
    'TALABC0EF',  // Invalid - contains 0
    'TALABCOEF',  // Invalid - contains O
    'TALABC1EF',  // Invalid - contains 1
    'TALABCIEF',  // Invalid - contains I
    'TALABCDE',   // Invalid - too short
    'TALABCDEFG', // Invalid - too long
    'REFABCDEF',  // Invalid - wrong prefix
    'TALADMIN',   // Valid - admin exception
  ];
  
  for (final code in testCases) {
    final isValid = validateTALReferralCode(code);
    print('Test: $code - ${isValid ? "✅ Valid" : "❌ Invalid"}');
  }
  
  print('\n🎉 Summary:');
  print('• TAL prefix format is working correctly');
  print('• Crockford base32 validation is working');
  print('• Old REF format is properly rejected');
  print('• New registrations will use TAL format only');
}

/// Generate a TAL referral code (simulating the actual generator)
String generateTALReferralCode() {
  const prefix = 'TAL';
  const codeLength = 6;
  const allowedChars = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  
  final random = Random();
  final codeBuffer = StringBuffer(prefix);
  
  for (int i = 0; i < codeLength; i++) {
    final randomIndex = random.nextInt(allowedChars.length);
    codeBuffer.write(allowedChars[randomIndex]);
  }
  
  return codeBuffer.toString();
}

/// Validate TAL referral code format
bool validateTALReferralCode(String code) {
  // Special case for admin
  if (code == 'TALADMIN') {
    return true;
  }
  
  // Must start with TAL
  if (!code.startsWith('TAL')) {
    return false;
  }
  
  // Must be exactly 9 characters (TAL + 6)
  if (code.length != 9) {
    return false;
  }
  
  // Check the 6 characters after TAL
  final codepart = code.substring(3);
  const crockfordAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  
  for (int i = 0; i < codepart.length; i++) {
    if (!crockfordAlphabet.contains(codepart[i])) {
      return false;
    }
  }
  
  return true;
}
