import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/screens/network_screen.dart';
import '../lib/services/auth_service.dart';

void main() {
  testWidgets('Back navigation preserves session', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: NetworkScreen()));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    // Assert user is still authenticated
    expect(AuthService.currentUser != null, true);
  });
}
