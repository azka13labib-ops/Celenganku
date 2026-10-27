import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celenganku_app/main.dart';

void main() {
  testWidgets('Celengan App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CelenganApp());
    expect(find.text('Celengan Pintar IoT'), findsOneWidget);

    // Unmount widget secara bersih agar semua timer dan stream di-dispose
    await tester.pumpWidget(const SizedBox());
  });
}

