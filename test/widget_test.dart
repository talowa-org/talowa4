import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/main.dart';

void main() {
  testWidgets('TALOWA app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TalowaApp());

    // Verify that the app loads with TALOWA branding
    expect(find.text('TALOWA'), findsOneWidget);
  });
}
