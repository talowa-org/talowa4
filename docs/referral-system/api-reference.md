# Referral System API Reference

## Overview

This document provides comprehensive API documentation for all referral system services. Each service is designed to handle specific aspects of the referral system functionality.

## Table of Contents

1. [ReferralCodeGenerator](#referralcodegenerator)
2. [ReferralTrackingService](#referraltrackingservice)
3. [ReferralLookupService](#referrallookupservice)
4. [PaymentIntegrationService](#paymentintegrationservice)
5. [TeamManagementService](#teammanagementservice)
6. [CommissionCalculationService](#commissioncalculationservice)
7. [RoleProgressionService](#roleprogressionservice)
8. [FraudPreventionService](#fraudpreventionservice)
9. [QRCodeService](#qrcodeservice)
10. [AnalyticsReportingService](#analyticsreportingservice)
11. [NotificationCommunicationService](#notificationcommunicationservice)
12. [RecognitionRetentionService](#recognitionretentionservice)
13. [MonitoringService](#monitoringservice)
14. [UniversalLinkService](#universallinkservice)
15. [UserRegistrationService](#userregistrationservice)

## ReferralCodeGenerator

Generates unique, secure referral codes for users.

### Methods

#### `generateUniqueCode()`

Generates a unique 9-character referral code.

```dart
static Future<String> generateUniqueCode()
```

**Returns:** `Future<String>` - A unique referral code (e.g., "TAL2B3C4D")

**Throws:** `ReferralCodeException` if generation fails

**Example:**
```dart
try {
  String code = await ReferralCodeGenerator.generateUniqueCode();
  print('Generated code: $code');
} catch (e) {
  print('Error generating code: $e');
}
```

#### `isValidFormat(String code)`

Validates the format of a referral code.

```dart
static bool isValidFormat(String code)
```

**Parameters:**
- `code` (String): The referral code to validate

**Returns:** `bool` - True if the code format is valid

**Example:**
```dart
bool isValid = ReferralCodeGenerator.isValidFormat('TAL2B3C4D');
print('Code is valid: $isValid');
```

## ReferralTrackingService

Manages referral relationships and tracking.

### Methods

#### `recordReferralRelationship()`

Records a new referral relationship between users.

```dart
static Future<void> recordReferralRelationship({
  required String newUserId,
  required String referralCode,
})
```

**Parameters:**
- `newUserId` (String): ID of the new user being referred
- `referralCode` (String): Referral code used for registration

**Throws:** `ReferralTrackingException` if recording fails

**Example:**
```dart
await ReferralTrackingService.recordReferralRelationship(
  newUserId: 'user123',
  referralCode: 'TAL2B3C4D',
);
```

#### `getUserReferralStats(String userId)`

Retrieves referral statistics for a user.

```dart
static Future<Map<String, dynamic>> getUserReferralStats(String userId)
```

**Parameters:**
- `userId` (String): ID of the user

**Returns:** `Future<Map<String, dynamic>>` - User's referral statistics

**Example:**
```dart
Map<String, dynamic> stats = await ReferralTrackingService.getUserReferralStats('user123');
print('Direct referrals: ${stats['directReferrals']}');
print('Team size: ${stats['teamSize']}');
```

## ReferralLookupService

Validates and looks up referral codes.

### Methods

#### `validateReferralCode(String code)`

Validates a referral code and returns associated user data.

```dart
static Future<Map<String, dynamic>?> validateReferralCode(String code)
```

**Parameters:**
- `code` (String): Referral code to validate

**Returns:** `Future<Map<String, dynamic>?>` - User data if valid, null if invalid

**Throws:** `InvalidReferralCodeException` if code is invalid

**Example:**
```dart
try {
  Map<String, dynamic>? userData = await ReferralLookupService.validateReferralCode('TAL2B3C4D');
  if (userData != null) {
    print('Valid code for user: ${userData['fullName']}');
  }
} catch (e) {
  print('Invalid referral code: $e');
}
```

#### `incrementClickCount(String code)`

Increments the click count for a referral code.

```dart
static Future<void> incrementClickCount(String code)
```

**Parameters:**
- `code` (String): Referral code

**Example:**
```dart
await ReferralLookupService.incrementClickCount('TAL2B3C4D');
```

## PaymentIntegrationService

Handles payment processing and user activation.

### Methods

#### `manualPaymentActivation()`

Manually activates a user after payment confirmation.

```dart
static Future<Map<String, dynamic>> manualPaymentActivation({
  required String userId,
  required String paymentId,
  required double amount,
  required String currency,
})
```

**Parameters:**
- `userId` (String): ID of the user
- `paymentId` (String): Payment transaction ID
- `amount` (double): Payment amount
- `currency` (String): Payment currency

**Returns:** `Future<Map<String, dynamic>>` - Activation result

**Example:**
```dart
Map<String, dynamic> result = await PaymentIntegrationService.manualPaymentActivation(
  userId: 'user123',
  paymentId: 'payment456',
  amount: 99.99,
  currency: 'USD',
);
print('Activation successful: ${result['success']}');
```

## TeamManagementService

Manages team structures and statistics.

### Methods

#### `updateTeamStatistics(String userId)`

Updates team statistics for a user and their upline.

```dart
static Future<void> updateTeamStatistics(String userId)
```

**Parameters:**
- `userId` (String): ID of the user

**Example:**
```dart
await TeamManagementService.updateTeamStatistics('user123');
```

#### `getTeamHierarchy(String userId)`

Retrieves the team hierarchy for a user.

```dart
static Future<Map<String, dynamic>> getTeamHierarchy(String userId)
```

**Parameters:**
- `userId` (String): ID of the user

**Returns:** `Future<Map<String, dynamic>>` - Team hierarchy data

**Example:**
```dart
Map<String, dynamic> hierarchy = await TeamManagementService.getTeamHierarchy('user123');
print('Team members: ${hierarchy['members'].length}');
```

## CommissionCalculationService

Calculates and distributes commissions.

### Methods

#### `calculateCommissions(String newUserId)`

Calculates commissions for a new user activation.

```dart
static Future<Map<String, dynamic>> calculateCommissions(String newUserId)
```

**Parameters:**
- `newUserId` (String): ID of the newly activated user

**Returns:** `Future<Map<String, dynamic>>` - Commission calculation results

**Example:**
```dart
Map<String, dynamic> commissions = await CommissionCalculationService.calculateCommissions('user123');
print('Total commissions: ${commissions['totalAmount']}');
```

## RoleProgressionService

Manages user role progression and requirements.

### Methods

#### `checkAndUpdateRole(String userId)`

Checks if a user qualifies for role progression and updates accordingly.

```dart
static Future<void> checkAndUpdateRole(String userId)
```

**Parameters:**
- `userId` (String): ID of the user

**Example:**
```dart
await RoleProgressionService.checkAndUpdateRole('user123');
```

#### `getRoleRequirements(String role)`

Gets the requirements for a specific role.

```dart
static Map<String, dynamic> getRoleRequirements(String role)
```

**Parameters:**
- `role` (String): Role name

**Returns:** `Map<String, dynamic>` - Role requirements

**Example:**
```dart
Map<String, dynamic> requirements = RoleProgressionService.getRoleRequirements('team_leader');
print('Required referrals: ${requirements['directReferrals']}');
```

## FraudPreventionService

Prevents fraud and abuse in the referral system.

### Methods

#### `validateReferralAttempt()`

Validates a referral attempt for potential fraud.

```dart
static Future<Map<String, dynamic>> validateReferralAttempt({
  required String newUserId,
  required String referralCode,
  String? ipAddress,
  String? deviceId,
})
```

**Parameters:**
- `newUserId` (String): ID of the new user
- `referralCode` (String): Referral code being used
- `ipAddress` (String?): IP address of the request
- `deviceId` (String?): Device ID of the request

**Returns:** `Future<Map<String, dynamic>>` - Validation result

**Example:**
```dart
Map<String, dynamic> validation = await FraudPreventionService.validateReferralAttempt(
  newUserId: 'user123',
  referralCode: 'TAL2B3C4D',
  ipAddress: '192.168.1.1',
);
print('Is valid: ${validation['isValid']}');
```

## QRCodeService

Generates and manages QR codes for referral sharing.

### Methods

#### `generateReferralQRCode()`

Generates a QR code for a referral code.

```dart
static Future<Uint8List> generateReferralQRCode({
  required String referralCode,
  required String userId,
  int size = 200,
})
```

**Parameters:**
- `referralCode` (String): Referral code
- `userId` (String): User ID
- `size` (int): QR code size in pixels

**Returns:** `Future<Uint8List>` - QR code image data

**Example:**
```dart
Uint8List qrCodeData = await QRCodeService.generateReferralQRCode(
  referralCode: 'TAL2B3C4D',
  userId: 'user123',
  size: 300,
);
```

## AnalyticsReportingService

Provides analytics and reporting functionality.

### Methods

#### `generateConversionReport()`

Generates a conversion rate report.

```dart
static Future<Map<String, dynamic>> generateConversionReport({
  DateTime? startDate,
  DateTime? endDate,
  String? userId,
})
```

**Parameters:**
- `startDate` (DateTime?): Report start date
- `endDate` (DateTime?): Report end date
- `userId` (String?): Specific user ID

**Returns:** `Future<Map<String, dynamic>>` - Conversion report data

**Example:**
```dart
Map<String, dynamic> report = await AnalyticsReportingService.generateConversionReport(
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);
print('Conversion rate: ${report['conversionRate']}%');
```

## NotificationCommunicationService

Handles notifications and communications.

### Methods

#### `sendReferralNotification()`

Sends a referral-related notification.

```dart
static Future<void> sendReferralNotification({
  required String userId,
  required String type,
  required Map<String, dynamic> data,
})
```

**Parameters:**
- `userId` (String): Recipient user ID
- `type` (String): Notification type
- `data` (Map<String, dynamic>): Notification data

**Example:**
```dart
await NotificationCommunicationService.sendReferralNotification(
  userId: 'user123',
  type: 'new_referral',
  data: {'referredUserName': 'John Doe'},
);
```

## RecognitionRetentionService

Manages achievements and recognition.

### Methods

#### `checkAndAwardAchievements(String userId)`

Checks for and awards new achievements to a user.

```dart
static Future<List<Map<String, dynamic>>> checkAndAwardAchievements(String userId)
```

**Parameters:**
- `userId` (String): User ID

**Returns:** `Future<List<Map<String, dynamic>>>` - List of new achievements

**Example:**
```dart
List<Map<String, dynamic>> achievements = await RecognitionRetentionService.checkAndAwardAchievements('user123');
print('New achievements: ${achievements.length}');
```

## MonitoringService

Monitors system health and errors.

### Methods

#### `startOperation()`

Starts monitoring an operation.

```dart
static void startOperation(String operationId, String operation, String userId)
```

**Parameters:**
- `operationId` (String): Unique operation ID
- `operation` (String): Operation name
- `userId` (String): User ID

**Example:**
```dart
MonitoringService.startOperation('op123', 'referral_code_generation', 'user123');
```

#### `endOperation()`

Ends monitoring an operation and records metrics.

```dart
static Future<void> endOperation(
  String operationId,
  String operation,
  String userId, {
  bool success = true,
  String? errorMessage,
  Map<String, dynamic>? metadata,
})
```

**Parameters:**
- `operationId` (String): Operation ID
- `operation` (String): Operation name
- `userId` (String): User ID
- `success` (bool): Whether operation succeeded
- `errorMessage` (String?): Error message if failed
- `metadata` (Map<String, dynamic>?): Additional metadata

**Example:**
```dart
await MonitoringService.endOperation(
  'op123',
  'referral_code_generation',
  'user123',
  success: true,
  metadata: {'codeLength': 9},
);
```

#### `logError()`

Logs an error event.

```dart
static Future<void> logError(
  String message, {
  required String operation,
  required String userId,
  String? errorType,
  String? stackTrace,
  Map<String, dynamic>? context,
  MonitoringLevel level = MonitoringLevel.error,
})
```

**Parameters:**
- `message` (String): Error message
- `operation` (String): Operation name
- `userId` (String): User ID
- `errorType` (String?): Error type
- `stackTrace` (String?): Stack trace
- `context` (Map<String, dynamic>?): Error context
- `level` (MonitoringLevel): Error severity level

**Example:**
```dart
await MonitoringService.logError(
  'Database connection failed',
  operation: 'user_lookup',
  userId: 'user123',
  errorType: 'DatabaseError',
  level: MonitoringLevel.error,
);
```

## UniversalLinkService

Handles deep links and auto-fills referral codes.

### Methods

#### `generateReferralLink(String referralCode)`

Generates a universal link for a referral code.

```dart
static String generateReferralLink(String referralCode)
```

**Parameters:**
- `referralCode` (String): The referral code to include in the link

**Returns:** `String` - Universal link URL

**Example:**
```dart
String link = UniversalLinkService.generateReferralLink('TAL234567');
print('Share this link: $link');
// Output: https://talowa.web.app/join?ref=TAL234567
```

#### `getPendingReferralCode()`

Gets the pending referral code from a deep link (one-time use).

```dart
static String? getPendingReferralCode()
```

**Returns:** `String?` - Pending referral code or null if none

**Example:**
```dart
String? pendingCode = UniversalLinkService.getPendingReferralCode();
if (pendingCode != null) {
  print('Auto-filling referral code: $pendingCode');
  referralCodeController.text = pendingCode;
}
```

#### `clearPendingReferralCode()`

Clears any pending referral code.

```dart
static void clearPendingReferralCode()
```

**Example:**
```dart
UniversalLinkService.clearPendingReferralCode();
```

#### `testReferralLink(String link)`

Tests a referral link for development purposes.

```dart
static Future<void> testReferralLink(String link)
```

**Parameters:**
- `link` (String): The referral link to test

**Example:**
```dart
await UniversalLinkService.testReferralLink('https://talowa.web.app/join?ref=TAL234567');
```

## UserRegistrationService

Handles user registration with auto-fill support.

### Methods

#### `createUserProfile()`

Creates a user profile with auto-fill referral code support.

```dart
static Future<Map<String, dynamic>> createUserProfile({
  required String userId,
  required String fullName,
  required String email,
  String? phone,
  String? providedReferralCode,
  Map<String, dynamic>? additionalData,
})
```

**Parameters:**
- `userId` (String): Unique user ID
- `fullName` (String): User's full name
- `email` (String): User's email address
- `phone` (String?): User's phone number
- `providedReferralCode` (String?): Manually provided referral code
- `additionalData` (Map<String, dynamic>?): Additional user data

**Returns:** `Future<Map<String, dynamic>>` - Registration result

**Example:**
```dart
// Auto-fill will check for pending referral code if none provided
Map<String, dynamic> result = await UserRegistrationService.createUserProfile(
  userId: 'user123',
  fullName: 'John Doe',
  email: 'john@example.com',
  providedReferralCode: null, // Will auto-fill from deep link
);
```

#### `activateUserAfterPayment()`

Activates user after payment and binds referral relationships.

```dart
static Future<Map<String, dynamic>> activateUserAfterPayment({
  required String userId,
  required String paymentId,
  required double amount,
  required String currency,
  Map<String, dynamic>? paymentMetadata,
})
```

**Parameters:**
- `userId` (String): User ID to activate
- `paymentId` (String): Payment transaction ID
- `amount` (double): Payment amount
- `currency` (String): Payment currency
- `paymentMetadata` (Map<String, dynamic>?): Additional payment data

**Returns:** `Future<Map<String, dynamic>>` - Activation result

**Example:**
```dart
Map<String, dynamic> result = await UserRegistrationService.activateUserAfterPayment(
  userId: 'user123',
  paymentId: 'payment456',
  amount: 99.99,
  currency: 'USD',
);
```

## Error Handling

All services implement comprehensive error handling with custom exception types:

- `ReferralCodeException` - Referral code generation errors
- `ReferralTrackingException` - Referral tracking errors
- `InvalidReferralCodeException` - Invalid referral code errors
- `PaymentIntegrationException` - Payment processing errors
- `TeamManagementException` - Team management errors
- `CommissionCalculationException` - Commission calculation errors
- `RoleProgressionException` - Role progression errors
- `FraudPreventionException` - Fraud prevention errors
- `QRCodeException` - QR code generation errors
- `AnalyticsException` - Analytics and reporting errors
- `NotificationException` - Notification delivery errors
- `RecognitionException` - Recognition and achievement errors
- `MonitoringException` - Monitoring and logging errors

Each exception includes:
- Descriptive error message
- Error code for programmatic handling
- Context data for debugging
- Stack trace information

## Rate Limiting

Several services implement rate limiting to prevent abuse:

- Referral code generation: 10 codes per hour per user
- Referral attempts: 5 attempts per hour per IP
- QR code generation: 20 codes per hour per user
- Notification sending: 100 notifications per hour per user

## Testing

All services include comprehensive test suites covering:

- Unit tests for individual methods
- Integration tests for service interactions
- Performance tests for scalability
- Security tests for fraud prevention
- Error handling tests for edge cases

Run tests with:
```bash
flutter test test/services/referral/
```
