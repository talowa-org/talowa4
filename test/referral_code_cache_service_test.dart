import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/referral_code_cache_service.dart';

void main() {
  test('Referral code cache fallback works', () async {
    await ReferralCodeCacheService.initializeWithCode('testuid', 'TAL123456');
    expect(ReferralCodeCacheService.currentCode.startsWith('TAL'), true);
  });
  test('Referral code renders after sign-in', () async {
    await ReferralCodeCacheService.initializeWithCode('testuid', 'TAL654321');
    expect(ReferralCodeCacheService.currentCode, 'TAL654321');
  });
}

