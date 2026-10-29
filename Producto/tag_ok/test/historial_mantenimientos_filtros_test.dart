import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/screens/mantenimiento/historial_mantenimientos_screen.dart';

void main() {
  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Sin vehiculoId no se consulta Firestore: solo se ve la pantalla.
    await tester.pumpWidget(
      const MaterialApp(home: HistorialMantenimientosScreen(patente: 'ABCD12')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el ícono de filtros junto a la búsqueda abre mes, año y tipo en acordeón',
      (tester) async {
    await abrir(tester);

    // Panel cerrado al inicio.
    expect(find.text('Mes'), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // El ícono está a la derecha del campo de búsqueda.
    final busqueda = tester.getRect(find.byType(TextField));
    final icono = tester.getRect(find.byIcon(Icons.tune_rounded));
    expect(icono.left, greaterThan(busqueda.right - 1));

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Mes'), findsOneWidget);
    expect(find.text('Año'), findsOneWidget);
    expect(find.text('Tipo de mantención'), findsOneWidget);

    // El tipo es un acordeón: al tocarlo se despliega la lista.
    await tester.tap(find.text('Tipo de mantención'));
    await tester.pumpAndSettle();
    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.text('Frenos'), findsOneWidget);

    // Y se puede cerrar el panel con el mismo ícono.
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Mes'), findsNothing);
  });
}
