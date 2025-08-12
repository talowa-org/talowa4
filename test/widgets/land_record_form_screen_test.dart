import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/screens/land_records/land_record_form_screen.dart';

void main() {
  testWidgets('Form validation prevents empty submit', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandRecordFormScreen()));

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Required'), findsWidgets);
  });
}

