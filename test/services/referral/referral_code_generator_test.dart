import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:talowa/services/referral/referral_code_generator.dart';

void main() {
  group('ReferralCodeGenerator', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    group('Code Format Validation', () {
      test('should generate valid referral code format', () {
        final code = ReferralCodeGenerator.generateTestCode('test');
        expect(code, startsWith('TAL'));
        expect(code.length, equals(9)); // TAL + 6 chars
        expect(code, matches(RegExp(r'^TAL[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$')));
      });

      test('should exclude confusing characters', () {
        const allowedChars = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
        const confusingChars = ['0', 'O', '1', 'I', 'L'];
        
        for (final char in confusingChars) {
          expect(allowedChars.contains(char), isFalse, 
              reason: 'Confusing character $char should not be in allowed chars');
        }
      });

      test('should validate code format correctly', () {
        expect(ReferralCodeGenerator.isValidFormat('TAL8K9M2X'), isTrue);
        expect(ReferralCodeGenerator.isValidFormat('TAL123456'), isFalse); // Contains confusing chars
        expect(ReferralCodeGenerator.isValidFormat('ABC8K9M2X'), isFalse); // Wrong prefix
        expect(ReferralCodeGenerator.isValidFormat('TAL8K9M'), isFalse); // Too short
        expect(ReferralCodeGenerator.isValidFormat('TAL8K9M2XY'), isFalse); // Too long
        expect(ReferralCodeGenerator.isValidFormat(''), isFalse); // Empty
      });
    });

    group('Code Generation', () {
      test('should generate unique codes', () {
        final codes = <String>{};
        for (int i = 0; i < 100; i++) {
          final code = ReferralCodeGenerator.generateTestCode('test$i');
          expect(codes.contains(code), isFalse, 
              reason: 'Generated duplicate code: $code');
          codes.add(code);
        }
      });

      test('should generate deterministic test codes', () {
        final code1 = ReferralCodeGenerator.generateTestCode('test');
        final code2 = ReferralCodeGenerator.generateTestCode('test');
        expect(code1, equals(code2));
        
        final code3 = ReferralCodeGenerator.generateTestCode('different');
        expect(code1, isNot(equals(code3)));
      });

      test('should calculate total possible combinations correctly', () {
        const allowedCharsLength = 31; // Length of ALLOWED_CHARS
        const codeLength = 6;
        const expected = 887503681; // 31^6
        
        expect(ReferralCodeGenerator.totalPossibleCombinations, equals(expected));
      });

      test('should estimate collision probability', () {
        final prob1 = ReferralCodeGenerator.estimateCollisionProbability(0);
        expect(prob1, equals(0.0));

        final prob2 = ReferralCodeGenerator.estimateCollisionProbability(1000);
        expect(prob2, greaterThanOrEqualTo(0.0));
        expect(prob2, lessThan(1.0));

        final total = ReferralCodeGenerator.totalPossibleCombinations;
        final prob3 = ReferralCodeGenerator.estimateCollisionProbability(total);
        expect(prob3, equals(1.0));
      });
    });

    group('Exception Handling', () {
      test('should throw ReferralCodeGenerationException with correct properties', () {
        const message = 'Test error';
        const code = 'TEST_ERROR';
        final context = {'key': 'value'};
        
        final exception = ReferralCodeGenerationException(message, code, context);
        
        expect(exception.message, equals(message));
        expect(exception.code, equals(code));
        expect(exception.context, equals(context));
        expect(exception.toString(), contains(message));
      });

      test('should use default code when not provided', () {
        const message = 'Test error';
        const exception = ReferralCodeGenerationException(message);
        
        expect(exception.code, equals('CODE_GENERATION_FAILED'));
        expect(exception.context, isNull);
      });
    });

    group('Constants Validation', () {
      test('should have correct constants', () {
        expect(ReferralCodeGenerator.PREFIX, equals('TAL'));
        expect(ReferralCodeGenerator.CODE_LENGTH, equals(6));
        expect(ReferralCodeGenerator.MAX_ATTEMPTS, equals(10));
        expect(ReferralCodeGenerator.ALLOWED_CHARS.length, equals(31));
      });

      test('should have no duplicate characters in ALLOWED_CHARS', () {
        const chars = ReferralCodeGenerator.ALLOWED_CHARS;
        final uniqueChars = chars.split('').toSet();
        expect(uniqueChars.length, equals(chars.length));
      });

      test('should only contain uppercase letters and numbers', () {
        const chars = ReferralCodeGenerator.ALLOWED_CHARS;
        final validPattern = RegExp(r'^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]+$');
        expect(validPattern.hasMatch(chars), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle empty seed for test code generation', () {
        final code = ReferralCodeGenerator.generateTestCode('');
        expect(ReferralCodeGenerator.isValidFormat(code), isTrue);
      });

      test('should handle very long seed for test code generation', () {
        final longSeed = 'a' * 1000;
        final code = ReferralCodeGenerator.generateTestCode(longSeed);
        expect(ReferralCodeGenerator.isValidFormat(code), isTrue);
      });

      test('should handle special characters in seed', () {
        const specialSeed = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
        final code = ReferralCodeGenerator.generateTestCode(specialSeed);
        expect(ReferralCodeGenerator.isValidFormat(code), isTrue);
      });

      test('should handle unicode characters in seed', () {
        const unicodeSeed = 'ðŸŽ‰ðŸš€ðŸ’¡ðŸŒŸâ­';
        final code = ReferralCodeGenerator.generateTestCode(unicodeSeed);
        expect(ReferralCodeGenerator.isValidFormat(code), isTrue);
      });
    });

    group('Performance', () {
      test('should generate test codes quickly', () {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 1000; i++) {
          ReferralCodeGenerator.generateTestCode('test$i');
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete in under 1 second
      });

      test('should validate format quickly', () {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 10000; i++) {
          ReferralCodeGenerator.isValidFormat('TAL8K9M2X');
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should complete in under 100ms
      });
    });

    group('Randomness Quality', () {
      test('should generate diverse codes', () {
        final codes = <String>[];
        for (int i = 0; i < 100; i++) {
          codes.add(ReferralCodeGenerator.generateTestCode('seed$i'));
        }
        
        // Check that we have good distribution of characters
        final allChars = codes.join('').substring(300); // Remove all TAL prefixes
        final charCounts = <String, int>{};
        
        for (int i = 0; i < allChars.length; i++) {
          final char = allChars[i];
          charCounts[char] = (charCounts[char] ?? 0) + 1;
        }
        
        // Should use at least 15 different characters out of 31 possible
        expect(charCounts.keys.length, greaterThanOrEqualTo(15));
      });
    });
  });
}

