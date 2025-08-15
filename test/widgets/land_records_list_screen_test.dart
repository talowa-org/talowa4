library;
@Skip('Skips Firebase-dependent widget; covered via service tests and golden tests elsewhere')

@Skip('Skips Firebase-dependent widget; covered via service tests and golden tests elsewhere')
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/screens/land_records/land_records_list_screen.dart';

void main() {
  testWidgets('Land Records list empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LandRecordsListScreen(recordsStream: Stream.value([]))));
    await tester.pump();
    expect(find.textContaining('No land records'), findsNothing);
    expect(find.textContaining('No land records yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}

