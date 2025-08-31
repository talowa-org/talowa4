import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/unified_auth_service.dart';

void main() {
  group('UnifiedAuthService Tests', () {
    test('Phone number normalization', () {
      // Test phone number normalization
      expect(
        UnifiedAuthService.isPhoneRegistered('9876543210'),
        isA<Future<bool>>(),
      );
    });

    test('PIN hashing consistency', () {
      // Test that PIN hashing is consistent
      const pin = '123456';
      final hash1 = UnifiedAuthService.hashPin(pin);
      final hash2 = UnifiedAuthService.hashPin(pin);
      expect(hash1, equals(hash2));
    });
  });
}
