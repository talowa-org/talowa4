import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talowa/services/referral/referral_lookup_service.dart';

void main() {
  group('ReferralLookupService', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      ReferralLookupService.setFirestoreInstance(fakeFirestore);
    });

    group('Code Format Validation', () {
      test('should validate correct referral code format', () {
        expect(ReferralLookupService.isValidCodeFormat('TAL8K9M2X'), isTrue);
      });

      test('should reject invalid referral code formats', () {
        expect(ReferralLookupService.isValidCodeFormat('ABC8K9M2X'), isFalse); // Wrong prefix
        expect(ReferralLookupService.isValidCodeFormat('TAL123456'), isFalse); // Contains confusing chars
        expect(ReferralLookupService.isValidCodeFormat('TAL8K9M'), isFalse); // Too short
        expect(ReferralLookupService.isValidCodeFormat('TAL8K9M2XY'), isFalse); // Too long
        expect(ReferralLookupService.isValidCodeFormat(''), isFalse); // Empty
        expect(ReferralLookupService.isValidCodeFormat('tal8k9m2x'), isFalse); // Lowercase
      });
    });

    group('Referral Code Lookup', () {
      test('should return null for non-existent referral code', () async {
        final result = await ReferralLookupService.getReferralCodeLookup('TALNOTEXIST');
        expect(result, isNull);
      });

      test('should return ReferralCodeLookup for existing code', () async {
        // Setup test data
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 5,
          'conversionCount': 2,
        });

        final result = await ReferralLookupService.getReferralCodeLookup('TAL8K9M2X');
        
        expect(result, isNotNull);
        expect(result!.code, equals('TAL8K9M2X'));
        expect(result.uid, equals('user123'));
        expect(result.isActive, isTrue);
        expect(result.clickCount, equals(5));
        expect(result.conversionCount, equals(2));
      });
    });

    group('Referral Code Validation', () {
      test('should validate active referral code with user', () async {
        // Setup test data
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        await fakeFirestore.collection('users').doc('user123').set({
          'fullName': 'Test User',
          'isActive': true,
          'referralCode': 'TAL8K9M2X',
        });

        final result = await ReferralLookupService.validateReferralCode('TAL8K9M2X');
        
        expect(result, isNotNull);
        expect(result!['uid'], equals('user123'));
        expect(result['referralCode'], equals('TAL8K9M2X'));
        expect(result['userData']['fullName'], equals('Test User'));
      });

      test('should throw exception for invalid format', () async {
        expect(
          () => ReferralLookupService.validateReferralCode('INVALID'),
          throwsA(isA<InvalidReferralCodeException>()),
        );
      });

      test('should throw exception for non-existent code', () async {
        expect(
          () => ReferralLookupService.validateReferralCode('TALNOTEXIST'),
          throwsA(isA<InvalidReferralCodeException>()),
        );
      });

      test('should throw exception for inactive code', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': false,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        expect(
          () => ReferralLookupService.validateReferralCode('TAL8K9M2X'),
          throwsA(isA<InvalidReferralCodeException>()),
        );
      });

      test('should throw exception for unassigned code', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': null,
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        expect(
          () => ReferralLookupService.validateReferralCode('TAL8K9M2X'),
          throwsA(isA<InvalidReferralCodeException>()),
        );
      });

      test('should throw exception for inactive user', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        await fakeFirestore.collection('users').doc('user123').set({
          'fullName': 'Test User',
          'isActive': false,
          'referralCode': 'TAL8K9M2X',
        });

        expect(
          () => ReferralLookupService.validateReferralCode('TAL8K9M2X'),
          throwsA(isA<InvalidReferralCodeException>()),
        );
      });
    });

    group('User ID Lookup', () {
      test('should return user ID for valid referral code', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        final userId = await ReferralLookupService.getUserIdByReferralCode('TAL8K9M2X');
        expect(userId, equals('user123'));
      });

      test('should return null for invalid referral code', () async {
        final userId = await ReferralLookupService.getUserIdByReferralCode('TALNOTEXIST');
        expect(userId, isNull);
      });
    });

    group('Code Assignment', () {
      test('should assign referral code to user', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': null,
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        await ReferralLookupService.assignReferralCodeToUser('TAL8K9M2X', 'user123');

        final doc = await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').get();
        expect(doc.data()!['uid'], equals('user123'));
        expect(doc.data()!['assignedAt'], isNotNull);
      });
    });

    group('Click and Conversion Tracking', () {
      test('should increment click count', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 5,
          'conversionCount': 0,
        });

        await ReferralLookupService.incrementClickCount('TAL8K9M2X');

        final doc = await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').get();
        expect(doc.data()!['clickCount'], equals(6));
        expect(doc.data()!['lastClickAt'], isNotNull);
      });

      test('should increment conversion count', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 5,
          'conversionCount': 2,
        });

        await ReferralLookupService.incrementConversionCount('TAL8K9M2X');

        final doc = await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').get();
        expect(doc.data()!['conversionCount'], equals(3));
        expect(doc.data()!['lastConversionAt'], isNotNull);
      });

      test('should log click events with metadata', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        final metadata = {
          'userAgent': 'Mozilla/5.0...',
          'ipAddress': '192.168.1.1',
          'platform': 'web',
        };

        await ReferralLookupService.incrementClickCount('TAL8K9M2X', metadata: metadata);

        final clickDocs = await fakeFirestore.collection('referralClicks').get();
        expect(clickDocs.docs.length, equals(1));
        expect(clickDocs.docs.first.data()['referralCode'], equals('TAL8K9M2X'));
        expect(clickDocs.docs.first.data()['metadata'], equals(metadata));
      });
    });

    group('Code Deactivation', () {
      test('should deactivate referral code', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        await ReferralLookupService.deactivateReferralCode('TAL8K9M2X', 'User requested');

        final doc = await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').get();
        expect(doc.data()!['isActive'], isFalse);
        expect(doc.data()!['deactivatedAt'], isNotNull);
        expect(doc.data()!['deactivationReason'], equals('User requested'));
      });
    });

    group('Statistics', () {
      test('should return statistics for existing code', () async {
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 10,
          'conversionCount': 3,
        });

        final stats = await ReferralLookupService.getReferralStatistics('TAL8K9M2X');
        
        expect(stats['exists'], isTrue);
        expect(stats['clicks'], equals(10));
        expect(stats['conversions'], equals(3));
        expect(stats['conversionRate'], equals(0.3));
        expect(stats['isActive'], isTrue);
        expect(stats['userId'], equals('user123'));
      });

      test('should return default statistics for non-existent code', () async {
        final stats = await ReferralLookupService.getReferralStatistics('TALNOTEXIST');
        
        expect(stats['exists'], isFalse);
        expect(stats['clicks'], equals(0));
        expect(stats['conversions'], equals(0));
        expect(stats['conversionRate'], equals(0.0));
      });
    });

    group('Batch Operations', () {
      test('should batch validate multiple referral codes', () async {
        // Setup test data
        await fakeFirestore.collection('referralCodes').doc('TAL8K9M2X').set({
          'code': 'TAL8K9M2X',
          'uid': 'user123',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        await fakeFirestore.collection('referralCodes').doc('TAL7H8N3Y').set({
          'code': 'TAL7H8N3Y',
          'uid': 'user456',
          'isActive': false,
          'createdAt': Timestamp.now(),
          'clickCount': 0,
          'conversionCount': 0,
        });

        final codes = ['TAL8K9M2X', 'TAL7H8N3Y', 'TALNOTEXIST'];
        final results = await ReferralLookupService.batchValidateReferralCodes(codes);
        
        expect(results['TAL8K9M2X'], isTrue);
        expect(results['TAL7H8N3Y'], isFalse); // Inactive
        expect(results['TALNOTEXIST'], isFalse); // Non-existent
      });
    });

    group('Exception Handling', () {
      test('should create InvalidReferralCodeException with correct properties', () {
        const message = 'Test error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};
        
        final exception = InvalidReferralCodeException(message, code, context);
        
        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test error';
        const exception = InvalidReferralCodeException(message);
        
        expect(exception.code, equals('INVALID_REFERRAL_CODE'));
        expect(exception.context, isNull);
      });
    });
  });
}
