// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:arqueo_flutter/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Renderiza pantalla de login', (WidgetTester tester) async {
    await tester.pumpWidget(const ArqueoReplicaApp());
    expect(find.text('Arqueo multiempresa'), findsWidgets);
  });
}
