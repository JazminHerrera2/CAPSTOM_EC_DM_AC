import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/screens/dashboard/dashboard_logica.dart';
import 'package:tag_ok/screens/dashboard/historial_gastos_screen.dart';

void main() {
  final movimientos = [
    MovimientoGasto(
      categoria: CategoriaGasto.mantenciones,
      fecha: DateTime(2026, 10, 20),
      monto: 5000,
      titulo: 'Cambio de aceite',
    ),
    MovimientoGasto(
      categoria: CategoriaGasto.combustible,
      fecha: DateTime(2026, 9, 5),
      monto: 30000,
      titulo: 'Carga',
    ),
  ];

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HistorialGastosScreen(
          nombreVehiculo: 'Mi Yaris · ABCD12',
          movimientos: movimientos,
          alAbrirCategoria: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin descripción ni título de filtros; el vehículo va en una tarjeta y una línea separa los filtros',
      (tester) async {
    await abrir(tester);
    expect(find.textContaining('Aquí podrás revisar'), findsNothing);
    expect(find.text('Filtrar historial'), findsNothing);
    expect(find.text('Vehículo'), findsOneWidget);
    // Una línea entre los filtros y el resto de la página.
    expect(find.byType(Divider), findsOneWidget);
    final linea = tester.getTopLeft(find.byType(Divider)).dy;
    expect(linea, greaterThan(tester.getBottomLeft(find.byType(DropdownMenu<int>).first).dy));
    expect(linea, lessThan(tester.getTopLeft(find.text('Total pagado')).dy));
    final nombre = tester.getTopLeft(find.text('Mi Yaris · ABCD12'));
    final filtros = tester.getTopLeft(find.byType(DropdownMenu<int>).first);
    expect(nombre.dy, lessThan(filtros.dy));
  });

  testWidgets('la lista del mes se abre debajo del campo, alineada y del mismo ancho',
      (tester) async {
    await abrir(tester);

    final campo = find.byType(DropdownMenu<int>).first;
    final rectCampo = tester.getRect(campo);

    await tester.tap(campo);
    await tester.pumpAndSettle();

    // "Enero" solo existe en la lista desplegada.
    final enero = find.text('Enero');
    expect(enero, findsOneWidget);
    final rectItem = tester.getRect(enero);

    // Debajo del campo, no encima.
    expect(rectItem.top, greaterThanOrEqualTo(rectCampo.bottom - 1));
    // Alineada con el campo: dentro de sus bordes izquierdo y derecho.
    expect(rectItem.left, greaterThanOrEqualTo(rectCampo.left - 1));
    expect(rectItem.right, lessThanOrEqualTo(rectCampo.right + 1));

    // Elegir un mes filtra: hay gastos en septiembre y octubre, no en enero.
    expect(find.text('\$ 35.000'), findsOneWidget);
    await tester.tap(enero);
    await tester.pumpAndSettle();
    expect(find.text('\$ 35.000'), findsNothing);
    expect(find.text('\$ 0'), findsWidgets);
  });
}
