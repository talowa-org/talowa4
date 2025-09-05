import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/emergency_service.dart';

class _FakeMessaging implements FirebaseMessaging {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Report incident stores document', () async {
    final fs = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
    final svc = EmergencyService.forTest(firestore: fs, auth: auth, messaging: _FakeMessaging());

    final id = await svc.reportIncident(
      type: EmergencyType.landGrabbing,
      description: 'test incident',
      isAnonymous: false,
    );
    expect(id, isNotNull);
    final snap = await fs.collection('emergency_incidents').doc(id).get();
    expect(snap.exists, true);
  });
}


