import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:talowa/screens/land_records/land_records_list_screen.dart';
import 'package:talowa/services/land_records_service.dart';
import 'package:talowa/models/land_record_model.dart';

class _FakeService extends LandRecordsService {
  _FakeService() : super._internal();
  @override
  Stream<List<LandRecordModel>> getUserLandRecords() => Stream.value([]);
}

void main() {
  testWidgets('Land Records list empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandRecordsListScreen()));
    await tester.pump();
    expect(find.textContaining('No land records'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}

