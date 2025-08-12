import 'package:flutter_test/flutter_test.dart';
import 'package:talowa/services/ai_assistant_service.dart';

void main() {
  test('Intent analysis basic cases', () async {
    final svc = AIAssistantService();
    await svc.initialize();

    final r1 = await svc.processQuery('Open land records');
    expect(r1.actions.where((a) => a.type == AIActionType.navigate).isNotEmpty, true);

    final r2 = await svc.processQuery('This is an emergency');
    expect(r2.actions.any((a) => a.type == AIActionType.call || a.type == AIActionType.navigate), true);
  });
}

