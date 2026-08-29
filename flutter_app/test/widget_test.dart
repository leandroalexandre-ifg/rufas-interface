import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('App carrega e mostra a tela de fazendas', (WidgetTester tester) async {
    await tester.pumpWidget(const RufasApp());

    expect(find.text('Fazendas'), findsOneWidget);
    // A chamada GET /simulations ainda nao resolveu neste ponto do teste.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
