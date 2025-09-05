import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  test('Allowed client payload passes', () async {
    final doc = FirebaseFirestore.instance.collection('users').doc('testuid');
    await doc.set({
      'fullName': 'Test',
      'phone': '+919999999999',
      'profileCompleted': true,
      'phoneVerified': true,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'device': {'platform': 'android', 'appVersion': '1.0.0'},
    });
    final data = await doc.get();
    expect(data.exists, true);
  });

  test('Server-only field is denied', () async {
    final doc = FirebaseFirestore.instance.collection('users').doc('testuid');
    try {
      await doc.set({'referralCode': 'TAL123456'});
      fail('Should not allow server-only field');
    } catch (e) {
      expect(e.toString(), contains('permission-denied'));
    }
  });
}

