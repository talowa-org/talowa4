import 'package:cloud_functions/cloud_functions.dart';

class Backend {
  final _cf = FirebaseFunctions.instance;

  Future<void> createUserRegistry({
    required String e164,
    required String fullName,
    required String aliasEmail,
    required String pinHashHex,
    required String state,
    required String district,
    required String mandal,
    required String village,
    String? referralCode,
    bool simulatePayment = true,
    String useCollection = 'user_registry', // or 'registry' or 'phones'
  }) async {
    final callable = _cf.httpsCallable('createUserRegistry');
    await callable.call({
      'e164': e164,
      'fullName': fullName,
      'aliasEmail': aliasEmail,
      'pinHashHex': pinHashHex,
      'state': state,
      'district': district,
      'mandal': mandal,
      'village': village,
      'referralCode': referralCode,
      'simulatePayment': simulatePayment,
      'useCollection': useCollection,
    });
  }

  Future<bool> checkPhoneExists(String e164) async {
    final callable = _cf.httpsCallable('checkPhone');
    final res = await callable.call({'e164': e164});
    return (res.data as Map)['exists'] == true;
  }

  // Legacy method for backward compatibility
  Future<void> registerUserProfile({
    required String e164,
    required String fullName,
    required String aliasEmail,
    required String pinHashHex,
    required String state,
    required String district,
    required String mandal,
    required String village,
    String? referralCode,
    bool simulatePayment = true,
  }) async {
    return createUserRegistry(
      e164: e164,
      fullName: fullName,
      aliasEmail: aliasEmail,
      pinHashHex: pinHashHex,
      state: state,
      district: district,
      mandal: mandal,
      village: village,
      referralCode: referralCode,
      simulatePayment: simulatePayment,
      useCollection: 'user_registry',
    );
  }
}
