import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/land_records_service.dart';

class _FakeStorage implements FirebaseStorage {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Create/Update/Delete land record with nested mapping', () async {
    final fs = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1', phoneNumber: '9999999999'));
    final service = LandRecordsService.forTest(firestore: fs, auth: auth, storage: _FakeStorage());

    final id = await service.createLandRecord(
      surveyNumber: '123', village: 'V', mandal: 'M', district: 'D',
      area: 1.5, areaUnit: 'acres', landType: LandType.agricultural, pattaStatus: PattaStatus.pending,
      description: 'desc',
    );
    expect(id, isNotNull);

    final doc = await fs.collection('land_records').doc(id).get();
    final data = doc.data()!;
    expect(data['location']['village'], 'V');
    expect(data['unit'], 'acres');

    final ok = await service.updateLandRecord(recordId: id!, area: 2.0, village: 'V2');
    expect(ok, true);
    final updated = (await fs.collection('land_records').doc(id).get()).data()!;
    expect(updated['area'], 2.0);
    expect(updated['location']['village'], 'V2');

    final del = await service.deleteLandRecord(id);
    expect(del, true);
  });
}


