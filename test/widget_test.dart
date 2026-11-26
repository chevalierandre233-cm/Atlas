
import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_personnel/main.dart';

void main() {
  testWidgets('ATLAS affiche son interface', (WidgetTester tester) async {
    await tester.pumpWidget(const AtlasApp());

    expect(find.text('A T L A S'), findsOneWidget);
    expect(
      find.text('Bonjour, je suis Atlas.'),
      findsOneWidget,
    );
    expect(
      find.text('Comment puis-je t’aider aujourd’hui ?'),
      findsOneWidget,
    );
  });
}
