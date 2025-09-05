import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_utils/firebase_test_init.dart';

import 'package:talowa/services/ai_assistant_service.dart';

void main() {
  test('Intent analysis basic cases', () async {
    await ensureFirebaseInitialized();
    final fs = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u1'));
    final svc = AIAssistantService.forTest(
      firestore: fs,
      auth: auth,
    );
    await svc.initialize();

    final r1 = await svc.processQuery('Show land records');
    expect(r1.actions.where((a) => a.type == AIActionType.navigate).isNotEmpty, true);

    final r2 = await svc.processQuery('This is an emergency');
    expect(r2.actions.any((a) => a.type == AIActionType.call || a.type == AIActionType.navigate), true);
  });
}


