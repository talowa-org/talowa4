import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/screens/land_records/land_record_form_screen.dart';
import '../test_utils/firebase_test_init.dart';

void main() {
  testWidgets('Form validation prevents empty submit', (tester) async {
    await ensureFirebaseInitialized();
    await tester.pumpWidget(const MaterialApp(home: LandRecordFormScreen()));
    await tester.pump();

    // Button may be localized; tap by icon
    await tester.tap(find.byIcon(Icons.save));
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
  }, skip: true);
}


