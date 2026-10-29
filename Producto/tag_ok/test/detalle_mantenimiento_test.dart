import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/screens/mantenimiento/tarjeta_mantencion.dart';

void main() {
  final mantencion = MantencionModel(
    id: 'm1',
    uid: 'u',
    vehiculoId: 'v1',
    estado: EstadoMantencion.realizada,
    tipo: 'Cambio de aceite',
    fecha: DateTime(2026, 10, 1),
    kilometraje: 72450,
    taller: 'Taller Los Andes',
    costo: 45000,
    descripcion: 'Aceite sintético y filtro',
    observaciones: 'Volver en 10.000 km',
    tipoComprobante: TipoComprobante.boleta,
    numeroComprobante: 'B-123',
    componentes: const ['frenos', 'filtro_aire'],
    origenRegistro: 'ia',
  );

  testWidgets('tocar una tarjeta del historial abre su detalle con todos los datos', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TarjetaMantencion(mantencion: mantencion))),
    );
    expect(find.text('Detalle de mantención'), findsNothing);

    await tester.tap(find.byType(TarjetaMantencion));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de mantención'), findsOneWidget);
    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.text('Realizada'), findsOneWidget);
    expect(find.text('Registrada con IA'), findsOneWidget);
    expect(find.text('01/10/2026'), findsOneWidget);
    expect(find.text('72.450 km'), findsOneWidget);
    expect(find.text('Taller Los Andes'), findsOneWidget);
    expect(find.text('\$45.000'), findsOneWidget);
    expect(find.text('Aceite sintético y filtro'), findsOneWidget);
    expect(find.text('Volver en 10.000 km'), findsOneWidget);
    expect(find.text('Boleta N° B-123'), findsOneWidget);
    expect(find.text('Frenos'), findsOneWidget);
    expect(find.text('Filtro de aire'), findsOneWidget);
  });

  MantencionModel programada() => MantencionModel(
        id: 'p1',
        uid: 'u',
        vehiculoId: 'v1',
        estado: EstadoMantencion.programada,
        tipo: 'Frenos',
        proximaFecha: DateTime(2027, 1, 15),
        origenRegistro: 'manual',
      );

  testWidgets('una mantención programada no abre detalle y muestra el botón de eliminar',
      (tester) async {
    var eliminadas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TarjetaMantencion(
            mantencion: programada(),
            onEliminar: () => eliminadas++,
          ),
        ),
      ),
    );

    // Tocar la tarjeta no abre ningún detalle.
    await tester.tap(find.text('Frenos'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de mantención'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    // El botón de eliminar está al lado y avisa.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(eliminadas, 1);
  });

  testWidgets('una mantención realizada sigue abriendo su detalle y no trae eliminar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TarjetaMantencion(mantencion: mantencion))),
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
