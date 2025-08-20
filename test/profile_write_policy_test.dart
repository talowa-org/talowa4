import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/services/auth_service.dart';

void main() {
  test('Minimal profile write succeeds', () async {
    // Use Firebase emulator
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);

    final result = await AuthService.registerUser(
      phoneNumber: '+919999999999',
      pin: '123456',
      fullName: 'Test User',
      address: Address(state: 'TS', district: 'Hyd', mandal: 'A', villageCity: 'B'),
    );
    expect(result.success, true);
    expect(result.user?.fullName, 'Test User');
  });
}
