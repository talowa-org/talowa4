// TALOWA Fix Suggestion Service
// Provides detailed fix suggestions with file:function references

import 'validation_framework.dart';

/// Fix suggestion service with detailed file:function references
class FixSuggestionService {
  
  /// Generate comprehensive fix suggestions for validation failures
  static Map<String, FixSuggestion> generateFixSuggestions(ValidationReport report) {
    final suggestions = <String, FixSuggestion>{};
    
    for (final entry in report.failedTests) {
      final testName = entry.key;
      final result = entry.value;
      
      final suggestion = _generateFixSuggestionForTest(testName, result);
      if (suggestion != null) {
        suggestions[testName] = suggestion;
      }
    }
    
    return suggestions;
  }

  /// Generate fix suggestion for specific test
  static FixSuggestion? _generateFixSuggestionForTest(String testName, ValidationResult result) {
    switch (testName) {
      case 'Admin Bootstrap':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.critical,
          category: FixCategory.bootstrap,
          description: 'Admin user (TALADMIN) not found or improperly configured',
          rootCause: 'Missing admin bootstrap initialization',
          impact: 'Orphaned users cannot be assigned to fallback admin',
          fixSteps: [
            FixStep(
              description: 'Create admin user in user_registry collection',
              fileReference: 'lib/services/bootstrap_service.dart',
              functionReference: 'createAdminUserRegistry',
              codeExample: '''
Future<void> createAdminUserRegistry() async {
  await FirebaseFirestore.instance
    .collection('user_registry')
    .doc('+917981828388')
    .set({
      'uid': 'admin_uid',
      'email': '+917981828388@talowa.app',
      'phoneNumber': '+917981828388',
      'referralCode': 'TALADMIN',
      'role': 'national_leadership',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
}''',
            ),
            FixStep(
              description: 'Create admin user profile in users collection',
              fileReference: 'lib/services/bootstrap_service.dart',
              functionReference: 'createAdminUserProfile',
              codeExample: '''
Future<void> createAdminUserProfile(String adminUid) async {
  await FirebaseFirestore.instance
    .collection('users')
    .doc(adminUid)
    .set({
      'fullName': 'TALOWA Admin',
      'email': '+917981828388@talowa.app',
      'phoneNumber': '+917981828388',
      'referralCode': 'TALADMIN',
      'role': 'national_leadership',
      'status': 'active',
      'phoneVerified': true,
      'profileCompleted': true,
      'membershipPaid': true,
      // ... other required fields
    });
}''',
            ),
            FixStep(
              description: 'Create TALADMIN referral code mapping',
              fileReference: 'lib/services/referral/referral_code_generator.dart',
              functionReference: 'createAdminReferralCode',
              codeExample: '''
Future<void> createAdminReferralCode(String adminUid) async {
  await FirebaseFirestore.instance
    .collection('referralCodes')
    .doc('TALADMIN')
    .set({
      'code': 'TALADMIN',
      'ownerId': adminUid,
      'isActive': true,
      'usageCount': 0,
      'maxUsage': 999999, // Unlimited
      'createdAt': FieldValue.serverTimestamp(),
    });
}''',
            ),
          ],
          verificationSteps: [
            'Run AdminBootstrapValidator.verifyAdminBootstrap()',
            'Check user_registry/+917981828388 exists',
            'Check users/{adminUid} exists with correct fields',
            'Check referralCodes/TALADMIN exists and is active',
          ],
          automationAvailable: true,
        );

      case 'Test Case A':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.high,
          category: FixCategory.navigation,
          description: 'Top-level navigation buttons not working or missing',
          rootCause: 'Welcome screen configuration or navigation setup issue',
          impact: 'Users cannot access login or registration flows',
          fixSteps: [
            FixStep(
              description: 'Verify WelcomeScreen widget implementation',
              fileReference: 'lib/screens/auth/welcome_screen.dart',
              functionReference: 'build',
              codeExample: '''
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        // Welcome content
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          child: Text('Login'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: Text('Register'),
        ),
      ],
    ),
  );
}''',
            ),
            FixStep(
              description: 'Check navigation routes configuration',
              fileReference: 'lib/main.dart',
              functionReference: 'MaterialApp.routes',
              codeExample: '''
MaterialApp(
  routes: {
    '/': (context) => WelcomeScreen(),
    '/login': (context) => NewLoginScreen(),
    '/register': (context) => RealUserRegistrationScreen(),
    // ... other routes
  },
)''',
            ),
          ],
          verificationSteps: [
            'Run NavigationValidator.validateTopLevelNavigation()',
            'Test Login button navigation manually',
            'Test Register button navigation manually',
          ],
          automationAvailable: false,
        );

      case 'Test Case B1':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.high,
          category: FixCategory.authentication,
          description: 'OTP verification not working properly',
          rootCause: 'OTP service configuration or Firebase Auth setup issue',
          impact: 'New users cannot complete phone verification',
          fixSteps: [
            FixStep(
              description: 'Check OTP service configuration',
              fileReference: 'lib/services/verification_service.dart',
              functionReference: 'sendOTP',
              codeExample: '''
Future<OTPResult> sendOTP(String phoneNumber) async {
  try {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {
        // Auto-verification completed
      },
      verificationFailed: (FirebaseAuthException e) {
        // Handle verification failure
      },
      codeSent: (String verificationId, int? resendToken) {
        // Store verificationId for later use
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Handle timeout
      },
    );
    return OTPResult.success();
  } catch (e) {
    return OTPResult.error(e.toString());
  }
}''',
            ),
            FixStep(
              description: 'Verify Firebase Auth configuration',
              fileReference: 'lib/firebase_options.dart',
              functionReference: 'DefaultFirebaseOptions.currentPlatform',
              codeExample: '''
// Ensure Firebase is properly initialized
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);''',
            ),
          ],
          verificationSteps: [
            'Run OTPValidator.validateOTPVerification()',
            'Test OTP send with real phone number',
            'Test OTP verification with received code',
          ],
          automationAvailable: false,
        );

      case 'Test Case B2':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.critical,
          category: FixCategory.registration,
          description: 'Registration form not creating proper user profile or referral code shows "Loading"',
          rootCause: 'User profile creation or referral code generation timing issue',
          impact: 'New users have incomplete profiles or invalid referral codes',
          fixSteps: [
            FixStep(
              description: 'Fix user profile creation timing',
              fileReference: 'lib/services/auth_service.dart',
              functionReference: 'registerUser',
              codeExample: '''
Future<AuthResult> registerUser({
  required String phoneNumber,
  required String pin,
  required String fullName,
  required Address address,
}) async {
  try {
    // 1. Create Firebase Auth user first
    final userCredential = await _createFirebaseUser(phoneNumber, pin);
    final uid = userCredential.user!.uid;
    
    // 2. Generate referral code BEFORE creating profile
    final referralCode = await ReferralCodeGenerator.generateUniqueCode();
    
    // 3. Create complete user profile
    await _createUserProfile(uid, {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'address': address.toMap(),
      'referralCode': referralCode, // Use generated code, not "Loading"
      'status': 'active',
      'phoneVerified': true,
      'profileCompleted': true,
      'membershipPaid': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return AuthResult.success(user: user);
  } catch (e) {
    return AuthResult.error(e.toString());
  }
}''',
            ),
            FixStep(
              description: 'Ensure referral code generation is synchronous',
              fileReference: 'lib/services/referral/referral_code_generator.dart',
              functionReference: 'generateUniqueCode',
              codeExample: '''
Future<String> generateUniqueCode() async {
  int attempts = 0;
  while (attempts < 10) {
    final code = 'TAL' + _generateCrockfordBase32(6);
    
    // Check if code is unique
    final exists = await FirebaseFirestore.instance
      .collection('referralCodes')
      .doc(code)
      .get()
      .then((doc) => doc.exists);
    
    if (!exists) {
      // Reserve the code immediately
      await FirebaseFirestore.instance
        .collection('referralCodes')
        .doc(code)
        .set({
          'code': code,
          'reserved': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      
      return code;
    }
    
    attempts++;
  }
  
  throw Exception('Failed to generate unique referral code after 10 attempts');
}''',
            ),
          ],
          verificationSteps: [
            'Run RegistrationFormValidator.validateRegistrationForm()',
            'Check user document has referralCode field with TAL prefix',
            'Verify referralCode is not "Loading" or empty',
            'Test complete registration flow end-to-end',
          ],
          automationAvailable: true,
        );

      case 'Test Case B3':
      case 'Test Case B4':
      case 'Test Case B5':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.high,
          category: FixCategory.payment,
          description: 'Payment flow not working correctly - users blocked or status incorrect',
          rootCause: 'Payment integration service not handling optional payment correctly',
          impact: 'Users cannot access app features or payment status is incorrect',
          fixSteps: [
            FixStep(
              description: 'Fix payment optional logic',
              fileReference: 'lib/services/referral/payment_integration_service.dart',
              functionReference: 'processMembershipFee',
              codeExample: '''
Future<PaymentResult> processMembershipFee(String userId, PaymentData paymentData) async {
  try {
    // Process payment
    final paymentResult = await _processPayment(paymentData);
    
    if (paymentResult.success) {
      // Payment successful - update profile
      await _updateUserAfterPayment(userId, paymentResult);
    } else {
      // Payment failed - user STILL gets full access
      debugPrint('Payment failed but user retains full access');
    }
    
    // IMPORTANT: User always has active status regardless of payment
    await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .update({
        'status': 'active', // Always active
        'membershipPaid': paymentResult.success,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    
    return PaymentResult.success(); // Always return success for access
  } catch (e) {
    // Even on error, ensure user has access
    await _ensureUserAccess(userId);
    return PaymentResult.success();
  }
}''',
            ),
            FixStep(
              description: 'Ensure user access regardless of payment',
              fileReference: 'lib/services/auth_service.dart',
              functionReference: 'checkUserAccess',
              codeExample: '''
Future<bool> checkUserAccess(String userId) async {
  final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
  
  if (!userDoc.exists) return false;
  
  final userData = userDoc.data()!;
  
  // Access is based on status, NOT payment
  return userData['status'] == 'active';
}''',
            ),
          ],
          verificationSteps: [
            'Run PaymentFlowValidator.validatePaymentFlow()',
            'Test user access without payment',
            'Test payment success updates profile correctly',
            'Test payment failure maintains active status',
          ],
          automationAvailable: true,
        );

      case 'Test Case C':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.medium,
          category: FixCategory.authentication,
          description: 'Existing user login with email alias format not working',
          rootCause: 'Login service not handling email alias format correctly',
          impact: 'Existing users cannot log in with phone@talowa.com format',
          fixSteps: [
            FixStep(
              description: 'Fix email alias login handling',
              fileReference: 'lib/services/auth_service.dart',
              functionReference: 'loginUser',
              codeExample: '''
Future<AuthResult> loginUser({
  required String phoneOrEmail,
  required String pin,
}) async {
  try {
    String phoneNumber;
    
    // Handle email alias format
    if (phoneOrEmail.contains('@talowa.com') || phoneOrEmail.contains('@talowa.app')) {
      phoneNumber = phoneOrEmail.split('@')[0];
    } else {
      phoneNumber = phoneOrEmail;
    }
    
    // Normalize phone number
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+91' + phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    }
    
    // Authenticate with Firebase
    final credential = PhoneAuthProvider.credential(
      verificationId: await _getStoredVerificationId(phoneNumber),
      smsCode: pin, // Using PIN as SMS code for existing users
    );
    
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    
    return AuthResult.success(user: userCredential.user);
  } catch (e) {
    return AuthResult.error(e.toString());
  }
}''',
            ),
          ],
          verificationSteps: [
            'Run ExistingUserLoginValidator.validateExistingUserLogin()',
            'Test login with +919876543210@talowa.com format',
            'Test login with regular phone number format',
          ],
          automationAvailable: false,
        );

      case 'Test Case D':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.medium,
          category: FixCategory.deepLink,
          description: 'Deep link referral auto-fill not working',
          rootCause: 'Deep link handler not parsing referral codes correctly',
          impact: 'Referral links do not auto-fill registration form',
          fixSteps: [
            FixStep(
              description: 'Implement deep link handling',
              fileReference: 'lib/services/referral/universal_link_service.dart',
              functionReference: 'handleReferralLink',
              codeExample: '''
Future<ReferralLinkResult> handleReferralLink(String url) async {
  try {
    final uri = Uri.parse(url);
    String? referralCode;
    
    // Handle ?ref= format
    if (uri.queryParameters.containsKey('ref')) {
      referralCode = uri.queryParameters['ref'];
    }
    // Handle /join/CODE format
    else if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
      referralCode = uri.pathSegments[1];
    }
    
    // Validate referral code
    if (referralCode != null && referralCode.isNotEmpty) {
      final isValid = await _validateReferralCode(referralCode);
      if (isValid) {
        // Store for auto-fill
        await _storePendingReferralCode(referralCode);
        return ReferralLinkResult.success(referralCode);
      }
    }
    
    // Fallback to TALADMIN
    await _storePendingReferralCode('TALADMIN');
    return ReferralLinkResult.fallback('TALADMIN');
  } catch (e) {
    // Always fallback to TALADMIN on error
    await _storePendingReferralCode('TALADMIN');
    return ReferralLinkResult.fallback('TALADMIN');
  }
}''',
            ),
          ],
          verificationSteps: [
            'Run DeepLinkValidator.validateDeepLinkAutoFill()',
            'Test ?ref=TAL123456 URL format',
            'Test /join/TAL123456 path format',
            'Test fallback to TALADMIN for invalid refs',
          ],
          automationAvailable: false,
        );

      case 'Test Case E':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.high,
          category: FixCategory.referralPolicy,
          description: 'Referral codes not following TAL prefix policy',
          rootCause: 'Referral code generator not enforcing TAL prefix requirement',
          impact: 'Inconsistent referral code format across the system',
          fixSteps: [
            FixStep(
              description: 'Enforce TAL prefix in code generation',
              fileReference: 'lib/services/referral/referral_code_generator.dart',
              functionReference: 'generateUniqueCode',
              codeExample: '''
Future<String> generateUniqueCode() async {
  // Always use TAL prefix
  const prefix = 'TAL';
  
  // Generate 6-character Crockford base32 suffix
  final suffix = _generateCrockfordBase32(6);
  
  final code = prefix + suffix;
  
  // Validate format before returning
  if (!_validateCodeFormat(code)) {
    throw Exception('Generated code does not meet policy requirements');
  }
  
  return code;
}

bool _validateCodeFormat(String code) {
  // Must start with TAL
  if (!code.startsWith('TAL')) return false;
  
  // Must be exactly 9 characters (TAL + 6)
  if (code.length != 9) return false;
  
  // Suffix must be valid Crockford base32
  final suffix = code.substring(3);
  final validChars = RegExp(r'^[A-Z2-7]+\$');
  return validChars.hasMatch(suffix);
}''',
            ),
          ],
          verificationSteps: [
            'Run ReferralCodePolicyValidator.validateReferralCodePolicy()',
            'Generate multiple codes and verify TAL prefix',
            'Check existing codes in database for compliance',
          ],
          automationAvailable: true,
        );

      case 'Test Case F':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.medium,
          category: FixCategory.realtime,
          description: 'Network statistics not updating in real-time',
          rootCause: 'Network screen using mocked data instead of Firestore streams',
          impact: 'Users do not see real-time updates of their network growth',
          fixSteps: [
            FixStep(
              description: 'Implement Firestore streams for network data',
              fileReference: 'lib/screens/network/network_screen.dart',
              functionReference: 'build',
              codeExample: '''
Widget build(BuildContext context) {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
      .collection('users')
      .doc(currentUserId)
      .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator();
      
      final userData = snapshot.data!.data() as Map<String, dynamic>;
      final directReferrals = userData['directReferrals'] ?? 0;
      final totalTeamSize = userData['totalTeamSize'] ?? 0;
      
      return NetworkStatsCard(
        directReferrals: directReferrals,
        totalTeamSize: totalTeamSize,
      );
    },
  );
}''',
            ),
            FixStep(
              description: 'Remove mock data usage',
              fileReference: 'lib/services/referral/referral_statistics_service.dart',
              functionReference: 'getNetworkStats',
              codeExample: '''
Stream<NetworkStats> getNetworkStats(String userId) {
  // Use real Firestore stream, not mock data
  return FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .snapshots()
    .map((doc) {
      final data = doc.data() ?? {};
      return NetworkStats(
        directReferrals: data['directReferrals'] ?? 0,
        totalTeamSize: data['totalTeamSize'] ?? 0,
        // ... other stats
      );
    });
}''',
            ),
          ],
          verificationSteps: [
            'Run NetworkValidator.validateRealTimeNetworkUpdates()',
            'Add test referral and verify immediate update',
            'Check network screen shows real data, not mocks',
          ],
          automationAvailable: false,
        );

      case 'Test Case G':
        return FixSuggestion(
          testName: testName,
          priority: FixPriority.critical,
          category: FixCategory.security,
          description: 'Security rules not properly enforced',
          rootCause: 'Firestore security rules allow unauthorized writes',
          impact: 'Users can manipulate protected fields like referral counts',
          fixSteps: [
            FixStep(
              description: 'Update Firestore security rules',
              fileReference: 'firestore.rules',
              functionReference: 'users collection rules',
              codeExample: '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && request.auth.uid == userId
        && !('referredBy' in request.resource.data.diff(resource.data).affectedKeys())
        && !('referralChain' in request.resource.data.diff(resource.data).affectedKeys())
        && !('directReferrals' in request.resource.data.diff(resource.data).affectedKeys())
        && !('totalTeamSize' in request.resource.data.diff(resource.data).affectedKeys())
        && !('role' in request.resource.data.diff(resource.data).affectedKeys())
        && !('status' in request.resource.data.diff(resource.data).affectedKeys());
    }
  }
}''',
            ),
          ],
          verificationSteps: [
            'Run SecurityValidator.validateSecurityRules()',
            'Test unauthorized write attempts fail',
            'Test authorized reads succeed',
          ],
          automationAvailable: false,
        );

      default:
        return null;
    }
  }

  /// Generate fix suggestions report
  static String generateFixSuggestionsReport(ValidationReport report) {
    final suggestions = generateFixSuggestions(report);
    
    if (suggestions.isEmpty) {
      return 'No fix suggestions available - all tests passed or no automated fixes available.';
    }
    
    final buffer = StringBuffer();
    
    buffer.writeln('# TALOWA Validation Suite - Detailed Fix Suggestions');
    buffer.writeln();
    buffer.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
    buffer.writeln('**Failed Tests**: ${suggestions.length}');
    buffer.writeln();
    
    // Priority summary
    final criticalCount = suggestions.values.where((s) => s.priority == FixPriority.critical).length;
    final highCount = suggestions.values.where((s) => s.priority == FixPriority.high).length;
    final mediumCount = suggestions.values.where((s) => s.priority == FixPriority.medium).length;
    
    buffer.writeln('## Priority Summary');
    buffer.writeln();
    buffer.writeln('| Priority | Count | Action Required |');
    buffer.writeln('|----------|-------|-----------------|');
    buffer.writeln('| 🔴 Critical | $criticalCount | Fix immediately before production |');
    buffer.writeln('| 🟠 High | $highCount | Fix before next release |');
    buffer.writeln('| 🟡 Medium | $mediumCount | Fix when possible |');
    buffer.writeln();
    
    // Detailed suggestions
    int suggestionNumber = 1;
    for (final suggestion in suggestions.values) {
      buffer.writeln('## $suggestionNumber. ${suggestion.testName}');
      buffer.writeln();
      
      final priorityIcon = suggestion.priority == FixPriority.critical ? '🔴' :
                          suggestion.priority == FixPriority.high ? '🟠' : '🟡';
      
      buffer.writeln('**Priority**: $priorityIcon ${suggestion.priority.toString().toUpperCase()}');
      buffer.writeln('**Category**: ${suggestion.category.toString().split('.').last.toUpperCase()}');
      buffer.writeln('**Automation Available**: ${suggestion.automationAvailable ? '✅ Yes' : '❌ No'}');
      buffer.writeln();
      
      buffer.writeln('### Problem Description');
      buffer.writeln(suggestion.description);
      buffer.writeln();
      
      buffer.writeln('### Root Cause');
      buffer.writeln(suggestion.rootCause);
      buffer.writeln();
      
      buffer.writeln('### Impact');
      buffer.writeln(suggestion.impact);
      buffer.writeln();
      
      buffer.writeln('### Fix Steps');
      buffer.writeln();
      
      for (int i = 0; i < suggestion.fixSteps.length; i++) {
        final step = suggestion.fixSteps[i];
        buffer.writeln('#### Step ${i + 1}: ${step.description}');
        buffer.writeln();
        buffer.writeln('**File**: `${step.fileReference}`');
        buffer.writeln('**Function**: `${step.functionReference}`');
        buffer.writeln();
        buffer.writeln('**Implementation**:');
        buffer.writeln('```dart');
        buffer.writeln(step.codeExample);
        buffer.writeln('```');
        buffer.writeln();
      }
      
      buffer.writeln('### Verification Steps');
      buffer.writeln();
      for (int i = 0; i < suggestion.verificationSteps.length; i++) {
        buffer.writeln('${i + 1}. ${suggestion.verificationSteps[i]}');
      }
      buffer.writeln();
      
      buffer.writeln('---');
      buffer.writeln();
      
      suggestionNumber++;
    }
    
    buffer.writeln('## Implementation Checklist');
    buffer.writeln();
    
    for (final suggestion in suggestions.values) {
      final priorityIcon = suggestion.priority == FixPriority.critical ? '🔴' :
                          suggestion.priority == FixPriority.high ? '🟠' : '🟡';
      buffer.writeln('- [ ] $priorityIcon ${suggestion.testName}: ${suggestion.description}');
    }
    
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('*After implementing fixes, re-run the validation suite to verify resolution*');
    
    return buffer.toString();
  }
}

/// Fix suggestion data structure
class FixSuggestion {
  final String testName;
  final FixPriority priority;
  final FixCategory category;
  final String description;
  final String rootCause;
  final String impact;
  final List<FixStep> fixSteps;
  final List<String> verificationSteps;
  final bool automationAvailable;

  FixSuggestion({
    required this.testName,
    required this.priority,
    required this.category,
    required this.description,
    required this.rootCause,
    required this.impact,
    required this.fixSteps,
    required this.verificationSteps,
    required this.automationAvailable,
  });
}

/// Individual fix step
class FixStep {
  final String description;
  final String fileReference;
  final String functionReference;
  final String codeExample;

  FixStep({
    required this.description,
    required this.fileReference,
    required this.functionReference,
    required this.codeExample,
  });
}

/// Fix priority levels
enum FixPriority {
  critical,
  high,
  medium,
  low,
}

/// Fix categories
enum FixCategory {
  bootstrap,
  navigation,
  authentication,
  registration,
  payment,
  deepLink,
  referralPolicy,
  realtime,
  security,
}