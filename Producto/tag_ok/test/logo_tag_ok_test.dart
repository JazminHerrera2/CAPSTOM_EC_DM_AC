import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/screens/dashboard/logo_tag_ok.dart';

void main() {
  testWidgets('el encabezado carga la imagen del logo (no el texto de respaldo)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: LogoTagOk()))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    // Si el asset no se pudiera cargar, se vería el texto de respaldo.
    expect(find.text('TAG OK'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
