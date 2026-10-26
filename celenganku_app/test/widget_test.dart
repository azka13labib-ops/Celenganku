import 'package:flutter_test/flutter_test.dart';
import 'package:celenganku_app/main.dart';

void main() {
  testWidgets('Celengan App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CelenganApp());
    expect(find.text('Celengan Pintar IoT'), findsOneWidget);
  });
}
