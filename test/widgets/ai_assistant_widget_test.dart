import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/widgets/ai_assistant/ai_assistant_widget.dart';
import '../test_utils/firebase_test_init.dart';

void main() {
  testWidgets('AI Assistant renders welcome and input', (tester) async {
    await ensureFirebaseInitialized();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AIAssistantWidget())));

    expect(find.textContaining('TALOWA AI Assistant'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  }, skip: true);

  testWidgets('Suggestion chips appear after init (may be empty)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AIAssistantWidget())));
    await tester.pumpAndSettle();

    // Either suggestions list or welcome screen
    expect(find.byType(ActionChip), findsAny);
  }, skip: true);

  testWidgets('Typing sends a message and shows it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AIAssistantWidget())));

    final input = find.byKey(const Key('ai_input_field'));
    await tester.enterText(input, 'hello');
    await tester.tap(find.byKey(const Key('ai_send_btn')));
    await tester.pump();

    expect(find.text('hello'), findsWidgets);
  }, skip: true);
}

