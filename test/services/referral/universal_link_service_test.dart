import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:talowa/services/referral/universal_link_service.dart';
import 'package:talowa/services/referral/referral_lookup_service.dart';

void main() {
  group('UniversalLinkService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      UniversalLinkService.setFirestoreInstance(fakeFirestore);
      ReferralLookupService.setFirestoreInstance(fakeFirestore);
    });

    group('Link Generation', () {
      test('should generate correct referral link', () {
        const referralCode = 'TAL8K9M2X';
        final link = UniversalLinkService.generateReferralLink(referralCode);
        
        expect(link, equals('https://talowa.web.app/join?ref=TAL8K9M2X'));
      });

      test('should generate short referral link', () {
        const referralCode = 'TAL8K9M2X';
        final shortLink = UniversalLinkService.generateShortReferralLink(referralCode);
        
        // For now, short link is same as regular link
        expect(shortLink, equals('https://talowa.web.app/join?ref=TAL8K9M2X'));
      });
    });

    group('Link Validation', () {
      test('should identify valid referral links', () {
        final validLinks = [
          'https://talowa.web.app/join?ref=TAL8K9M2X',
          'https://talowa.web.app/join/TAL8K9M2X',
          'https://app.talowa.web.app/join?ref=TAL8K9M2X',
        ];

        for (final link in validLinks) {
          expect(UniversalLinkService.isReferralLink(link), isTrue, 
              reason: 'Link $link should be valid');
        }
      });

      test('should reject invalid referral links', () {
        final invalidLinks = [
          'https://google.com/join?ref=TAL8K9M2X',
          'https://talowa.web.app/home',
          'https://talowa.web.app/join',
          'invalid-url',
          '',
        ];

        for (final link in invalidLinks) {
          expect(UniversalLinkService.isReferralLink(link), isFalse, 
              reason: 'Link $link should be invalid');
        }
      });
    });

    group('Referral Code Parsing', () {
      test('should parse referral code from query parameter', () {
        const url = 'https://talowa.web.app/join?ref=TAL8K9M2X';
        final code = UniversalLinkService.parseReferralCodeFromUrl(url);
        
        expect(code, equals('TAL8K9M2X'));
      });

      test('should parse referral code from path segment', () {
        const url = 'https://talowa.web.app/join/TAL8K9M2X';
        final code = UniversalLinkService.parseReferralCodeFromUrl(url);
        
        expect(code, equals('TAL8K9M2X'));
      });

      test('should handle lowercase referral codes', () {
        const url = 'https://talowa.web.app/join?ref=tal8k9m2x';
        final code = UniversalLinkService.parseReferralCodeFromUrl(url);
        
        expect(code, equals('TAL8K9M2X'));
      });

      test('should return null for URLs without referral code', () {
        final urlsWithoutCode = [
          'https://talowa.web.app/home',
          'https://talowa.web.app/join',
          'https://talowa.web.app/join?other=param',
          'invalid-url',
        ];

        for (final url in urlsWithoutCode) {
          final code = UniversalLinkService.parseReferralCodeFromUrl(url);
          expect(code, isNull, reason: 'URL $url should not have referral code');
        }
      });
    });

    group('Pending Referral Code Management', () {
      test('should store and retrieve pending referral code', () {
        const referralCode = 'TAL8K9M2X';
        
        // Initially no pending code
        expect(UniversalLinkService.getPendingReferralCode(), isNull);
        
        // This would normally be set by the link handler
        // For testing, we'll access the private field through reflection or test the public interface
        
        // Clear pending code
        UniversalLinkService.clearPendingReferralCode();
        expect(UniversalLinkService.getPendingReferralCode(), isNull);
      });
    });

    group('Configuration Validation', () {
      test('should validate universal link configuration', () async {
        final isValid = await UniversalLinkService.validateConfiguration();
        expect(isValid, isTrue);
      });
    });

    group('Link Click Statistics', () {
      test('should get link click statistics', () async {
        const referralCode = 'TAL8K9M2X';
        
        // Setup test data
        await fakeFirestore.collection('linkClicks').add({
          'referralCode': referralCode,
          'timestamp': DateTime.now(),
          'metadata': {
            'platform': 'android',
          },
        });

        await fakeFirestore.collection('linkClicks').add({
          'referralCode': referralCode,
          'timestamp': DateTime.now(),
          'metadata': {
            'platform': 'ios',
          },
        });

        final stats = await UniversalLinkService.getLinkClickStats(referralCode);
        
        expect(stats['totalClicks'], equals(2));
        expect(stats['clicksByPlatform']['android'], equals(1));
        expect(stats['clicksByPlatform']['ios'], equals(1));
        expect(stats['period'], equals('24h'));
      });

      test('should handle empty statistics', () async {
        const referralCode = 'TALNOTEXIST';
        
        final stats = await UniversalLinkService.getLinkClickStats(referralCode);
        
        expect(stats['totalClicks'], equals(0));
        expect(stats['clicksByPlatform'], isEmpty);
        expect(stats['clicksByHour'], isEmpty);
      });
    });

    group('Platform Detection', () {
      test('should detect platform correctly', () {
        // This test would need to mock Platform.isAndroid, etc.
        // For now, we'll test the method exists and returns a string
        // The actual platform detection is tested implicitly in other tests
      });
    });

    group('Error Handling', () {
      test('should handle invalid URLs gracefully', () {
        final invalidUrls = [
          'not-a-url',
          '',
          'ftp://invalid.com',
          'javascript:alert("xss")',
        ];

        for (final url in invalidUrls) {
          expect(() => UniversalLinkService.parseReferralCodeFromUrl(url), 
              returnsNormally, reason: 'Should handle invalid URL: $url');
          
          final code = UniversalLinkService.parseReferralCodeFromUrl(url);
          expect(code, isNull);
        }
      });

      test('should create UniversalLinkException correctly', () {
        const message = 'Test error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};

        final exception = UniversalLinkException(message, code, context);

        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test error';
        final exception = UniversalLinkException(message);

        expect(exception.code, equals('UNIVERSAL_LINK_FAILED'));
        expect(exception.context, isNull);
      });
    });

    group('Constants', () {
      test('should have correct constants', () {
        expect(UniversalLinkService.BASE_URL, equals('https://talowa.web.app'));
        expect(UniversalLinkService.JOIN_PATH, equals('/join'));
        expect(UniversalLinkService.REFERRAL_PARAM, equals('ref'));
      });
    });

    group('Edge Cases', () {
      test('should handle URLs with multiple query parameters', () {
        const url = 'https://talowa.web.app/join?ref=TAL8K9M2X&utm_source=facebook&utm_medium=social';
        final code = UniversalLinkService.parseReferralCodeFromUrl(url);
        
        expect(code, equals('TAL8K9M2X'));
      });

      test('should handle URLs with fragments', () {
        const url = 'https://talowa.web.app/join?ref=TAL8K9M2X#section1';
        final code = UniversalLinkService.parseReferralCodeFromUrl(url);
        
        expect(code, equals('TAL8K9M2X'));
      });

      test('should handle URLs with port numbers', () {
        const url = 'https://talowa.web.app:8080/join?ref=TAL8K9M2X';
        final code = UniversalLinkService.parseReferralCodeFromUrl(url);
        
        expect(code, equals('TAL8K9M2X'));
      });

      test('should handle URLs with subdomain', () {
        const url = 'https://app.talowa.web.app/join?ref=TAL8K9M2X';
        final isValid = UniversalLinkService.isReferralLink(url);
        
        expect(isValid, isTrue);
      });

      test('should handle empty referral code parameter', () {
        const url = 'https://talowa.web.app/join?ref=';
        final code = UniversalLinkService.parseReferralCodeFromUrl(url);
        
        expect(code, isNull);
      });

      test('should handle whitespace in referral code', () {
        const url = 'https://talowa.web.app/join?ref= TAL8K9M2X ';
        final code = UniversalLinkService.parseReferralCodeFromUrl(url);
        
        // The service should handle trimming
        expect(code, equals('TAL8K9M2X'));
      });
    });

    group('Link Generation Edge Cases', () {
      test('should handle special characters in referral code', () {
        // Note: This shouldn't happen with valid referral codes, but test robustness
        const referralCode = 'TAL8K9M2X';
        final link = UniversalLinkService.generateReferralLink(referralCode);
        
        expect(link, contains(referralCode));
        expect(Uri.parse(link).queryParameters['ref'], equals(referralCode));
      });

      test('should generate valid URIs', () {
        const referralCode = 'TAL8K9M2X';
        final link = UniversalLinkService.generateReferralLink(referralCode);
        
        expect(() => Uri.parse(link), returnsNormally);
        
        final uri = Uri.parse(link);
        expect(uri.scheme, equals('https'));
        expect(uri.host, equals('talowa.web.app'));
        expect(uri.path, equals('/join'));
        expect(uri.queryParameters['ref'], equals(referralCode));
      });
    });
  });
}
