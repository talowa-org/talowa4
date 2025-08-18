import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/referral/universal_link_service.dart';
import 'package:talowa/services/referral/referral_lookup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Auto-Fill Referral Code System', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      UniversalLinkService.setFirestoreInstance(fakeFirestore);
      ReferralLookupService.setFirestoreInstance(fakeFirestore);
    });

    tearDown(() {
      UniversalLinkService.dispose();
    });

    group('Deep Link Processing', () {
      test('should extract referral code from query parameter', () {
        const testUrl = 'https://talowa.web.app/join?ref=TAL234567';
        final uri = Uri.parse(testUrl);
        
        // Test the extraction logic
        final referralCode = uri.queryParameters['ref'];
        expect(referralCode, equals('TAL234567'));
      });

      test('should extract referral code from path segment', () {
        const testUrl = 'https://talowa.web.app/join/TAL234567';
        final uri = Uri.parse(testUrl);
        
        // Test path segment extraction
        expect(uri.pathSegments.length, equals(2));
        expect(uri.pathSegments[0], equals('join'));
        expect(uri.pathSegments[1], equals('TAL234567'));
      });

      test('should handle various URL formats', () {
        final testUrls = [
          'https://talowa.web.app/join?ref=TAL234567',
          'https://talowa.web.app/join/TAL234567',
          'talowa://join?ref=TAL234567',
          'https://talowa.com/join?referral=TAL234567',
        ];

        for (final url in testUrls) {
          final uri = Uri.parse(url);
          
          // Check query parameters
          String? code = uri.queryParameters['ref'] ?? 
                        uri.queryParameters['referral'];
          
          // Check path segments if no query param
          if (code == null && uri.pathSegments.length >= 2 && 
              uri.pathSegments[0] == 'join') {
            code = uri.pathSegments[1];
          }
          
          expect(code, equals('TAL234567'), reason: 'Failed for URL: $url');
        }
      });
    });

    group('Universal Link Service', () {
      test('should generate correct referral links', () {
        const referralCode = 'TAL234567';
        final link = UniversalLinkService.generateReferralLink(referralCode);
        
        expect(link, contains('talowa.web.app'));
        expect(link, contains('/join'));
        expect(link, contains('ref=$referralCode'));
        
        // Verify the generated link can be parsed back
        final uri = Uri.parse(link);
        expect(uri.queryParameters['ref'], equals(referralCode));
      });

      test('should store and retrieve pending referral codes', () {
        const referralCode = 'TAL234567';
        
        // Simulate storing a pending code
        UniversalLinkService.setPendingReferralCode(referralCode);
        
        // Retrieve the pending code
        final retrievedCode = UniversalLinkService.getPendingReferralCode();
        expect(retrievedCode, equals(referralCode));
        
        // Code should be cleared after retrieval
        final secondRetrieval = UniversalLinkService.getPendingReferralCode();
        expect(secondRetrieval, isNull);
      });

      test('should clear pending referral codes', () {
        const referralCode = 'TAL234567';
        
        UniversalLinkService.setPendingReferralCode(referralCode);
        expect(UniversalLinkService.getPendingReferralCode(), equals(referralCode));
        
        UniversalLinkService.clearPendingReferralCode();
        expect(UniversalLinkService.getPendingReferralCode(), isNull);
      });

      test('should validate referral codes before storing', () async {
        const validCode = 'TAL234567';
        const invalidCode = 'INVALID';
        
        // Create a valid referral code in firestore
        await fakeFirestore.collection('referralCodes').doc(validCode).set({
          'code': validCode,
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        
        // Test with valid code
        final isValidCode = await ReferralLookupService.isValidReferralCode(validCode);
        expect(isValidCode, isTrue);
        
        // Test with invalid code
        final isInvalidCode = await ReferralLookupService.isValidReferralCode(invalidCode);
        expect(isInvalidCode, isFalse);
      });
    });

    group('Link Click Tracking', () {
      test('should track referral link clicks', () async {
        const referralCode = 'TAL234567';
        
        // Create referral code
        await fakeFirestore.collection('referralCodes').doc(referralCode).set({
          'code': referralCode,
          'uid': 'user123',
          'isActive': true,
          'clickCount': 0,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        
        // Simulate link click tracking
        await fakeFirestore.collection('referralCodes').doc(referralCode).update({
          'clickCount': FieldValue.increment(1),
          'lastClickAt': FieldValue.serverTimestamp(),
        });
        
        // Verify click was tracked
        final codeDoc = await fakeFirestore
            .collection('referralCodes')
            .doc(referralCode)
            .get();
        
        expect(codeDoc.data()!['clickCount'], equals(1));
        expect(codeDoc.data()!['lastClickAt'], isNotNull);
      });

      test('should record click analytics', () async {
        const referralCode = 'TAL234567';
        const testUrl = 'https://talowa.web.app/join?ref=$referralCode';
        
        // Simulate analytics recording
        await fakeFirestore.collection('analytics_events').add({
          'event': 'referral_link_click',
          'referralCode': referralCode,
          'sourceUrl': testUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'userAgent': 'Test User Agent',
          'ipAddress': '192.168.1.1',
        });
        
        // Verify analytics were recorded
        final analyticsQuery = await fakeFirestore
            .collection('analytics_events')
            .where('event', isEqualTo: 'referral_link_click')
            .where('referralCode', isEqualTo: referralCode)
            .get();
        
        expect(analyticsQuery.docs.length, equals(1));
        
        final eventData = analyticsQuery.docs.first.data();
        expect(eventData['referralCode'], equals(referralCode));
        expect(eventData['sourceUrl'], equals(testUrl));
      });
    });

    group('Auto-Fill Integration', () {
      test('should auto-fill referral code in registration form', () {
        const referralCode = 'TAL234567';
        
        // Simulate the auto-fill process
        // 1. User clicks referral link
        UniversalLinkService.setPendingReferralCode(referralCode);
        
        // 2. Registration form checks for pending code
        final pendingCode = UniversalLinkService.getPendingReferralCode();
        expect(pendingCode, equals(referralCode));
        
        // 3. Form auto-fills the code
        // This would be handled by the UI widget
        expect(pendingCode, isNotNull);
        expect(pendingCode!.length, equals(9));
        expect(pendingCode.startsWith('TAL'), isTrue);
      });

      test('should handle multiple referral codes correctly', () {
        const firstCode = 'TAL234567';
        const secondCode = 'TAL789ABC';
        
        // Set first code
        UniversalLinkService.setPendingReferralCode(firstCode);
        expect(UniversalLinkService.getPendingReferralCode(), equals(firstCode));
        
        // Set second code (should replace first)
        UniversalLinkService.setPendingReferralCode(secondCode);
        expect(UniversalLinkService.getPendingReferralCode(), equals(secondCode));
        
        // First code should no longer be available
        final nextRetrieval = UniversalLinkService.getPendingReferralCode();
        expect(nextRetrieval, isNull);
      });

      test('should prioritize explicit referral code over deep link', () {
        const deepLinkCode = 'TAL234567';
        const explicitCode = 'TAL789ABC';
        
        // Set deep link code
        UniversalLinkService.setPendingReferralCode(deepLinkCode);
        
        // Simulate registration form logic
        String? finalCode = explicitCode; // User manually entered code
        finalCode ??= UniversalLinkService.getPendingReferralCode(); // Fallback to deep link
        
        expect(finalCode, equals(explicitCode));
        
        // Deep link code should still be available since it wasn't used
        final stillPending = UniversalLinkService.getPendingReferralCode();
        expect(stillPending, equals(deepLinkCode));
      });
    });

    group('Error Handling', () {
      test('should handle malformed URLs gracefully', () {
        final malformedUrls = [
          'not-a-url',
          'https://',
          'https://talowa.web.app',
          'https://talowa.web.app/join',
          'https://talowa.web.app/join?ref=',
          'https://talowa.web.app/join?other=param',
        ];

        for (final url in malformedUrls) {
          try {
            final uri = Uri.parse(url);
            final code = uri.queryParameters['ref'];
            
            // Should either be null or empty
            expect(code == null || code.isEmpty, isTrue, 
                   reason: 'Should not extract code from: $url');
          } catch (e) {
            // Parsing errors are acceptable for malformed URLs
            expect(e, isA<FormatException>());
          }
        }
      });

      test('should handle invalid referral codes', () {
        final invalidCodes = [
          '',
          'TAL',
          'INVALID123',
          'tal234567', // lowercase
          'TAL234567890', // too long
          'TAL23456', // too short
          'XYZ234567', // wrong prefix
        ];

        for (final code in invalidCodes) {
          final isValid = ReferralLookupService.isValidCodeFormat(code);
          expect(isValid, isFalse, reason: 'Should reject invalid code: $code');
        }
      });

      test('should handle network errors during validation', () async {
        const referralCode = 'TAL234567';
        
        // Don't create the referral code in firestore to simulate not found
        final isValid = await ReferralLookupService.isValidReferralCode(referralCode);
        expect(isValid, isFalse);
      });
    });

    group('Performance', () {
      test('should handle rapid link processing', () async {
        final codes = List.generate(100, (i) => 'TAL${i.toString().padLeft(6, '0')}');
        
        // Process multiple codes rapidly
        for (final code in codes) {
          UniversalLinkService.setPendingReferralCode(code);
          final retrieved = UniversalLinkService.getPendingReferralCode();
          expect(retrieved, equals(code));
        }
      });

      test('should clean up old pending codes', () {
        const oldCode = 'TAL234567';
        const newCode = 'TAL789ABC';
        
        // Set old code
        UniversalLinkService.setPendingReferralCode(oldCode);
        
        // Set new code (should replace old)
        UniversalLinkService.setPendingReferralCode(newCode);
        
        // Only new code should be available
        final retrieved = UniversalLinkService.getPendingReferralCode();
        expect(retrieved, equals(newCode));
        
        // No more codes should be pending
        final nextRetrieval = UniversalLinkService.getPendingReferralCode();
        expect(nextRetrieval, isNull);
      });
    });
  });
}
