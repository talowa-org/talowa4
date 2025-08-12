import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/widgets/ai_assistant/ai_assistant_widget.dart';

void main() {
  testWidgets('AI Assistant renders welcome and input', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AIAssistantWidget())));

    expect(find.textContaining('TALOWA AI Assistant'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('Suggestion chips appear after init (may be empty)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AIAssistantWidget())));
    await tester.pumpAndSettle();

    // Either suggestions list or welcome screen
    expect(find.byType(ActionChip), findsAny);
  });

  testWidgets('Typing sends a message and shows it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AIAssistantWidget())));

    final input = find.byType(TextField).last; // input box
    await tester.enterText(input, 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(find.text('hello'), findsWidgets);
  });
}

