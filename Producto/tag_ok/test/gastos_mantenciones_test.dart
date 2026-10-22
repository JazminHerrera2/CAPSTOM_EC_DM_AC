import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/data/models/tipo_mantencion.dart';
import 'package:tag_ok/screens/mantenimiento/gasto_periodo.dart';
import 'package:tag_ok/screens/mantenimiento/widgets_gasto.dart';

MantencionModel _m({
  required int? costo,
  DateTime? fecha,
  EstadoMantencion estado = EstadoMantencion.realizada,
}) =>
    MantencionModel(
      id: '',
      vehiculoId: 'v1',
      estado: estado,
      tipo: TipoMantencion.cambioAceite,
      costo: costo,
      fecha: fecha,
    );

void main() {
  final hoy = DateTime(2026, 10, 22);
  final octubre = PeriodoGasto.mes(DateTime(2026, 10));

  group('cálculo por periodo', () {
    test('1 mantención de \$87.000 en octubre 2026', () {
      final lista = [_m(costo: 87000, fecha: DateTime(2026, 10, 15))];
      expect(calcularGasto(lista, octubre), (total: 87000, cantidad: 1));
    });

    test('mes sin registros: \$0 y cantidad 0', () {
      final lista = [_m(costo: 87000, fecha: DateTime(2026, 8, 3))];
      expect(calcularGasto(lista, octubre), (total: 0, cantidad: 0));
    });

    test('una mantención sin costo no rompe el cálculo ni cuenta', () {
      final lista = [
        _m(costo: null, fecha: DateTime(2026, 10, 2)),
        _m(costo: 30000, fecha: DateTime(2026, 10, 9)),
      ];
      expect(calcularGasto(lista, octubre), (total: 30000, cantidad: 1));
    });

    test('las programadas y las sin fecha no entran a un mes ni a un año', () {
      final lista = [
        _m(
          costo: 99999,
          fecha: DateTime(2026, 10, 20),
          estado: EstadoMantencion.programada,
        ),
        _m(costo: 5000, fecha: null),
      ];
      expect(calcularGasto(lista, octubre).total, 0);
      expect(calcularGasto(lista, PeriodoGasto.anio(hoy)).total, 0);
      // Las sin fecha sí suman en Todo.
      expect(calcularGasto(lista, PeriodoGasto.todo()).total, 5000);
    });

    test('mes, año y Todo suman distinto con las mismas mantenciones', () {
      final lista = [
        _m(costo: 45000, fecha: DateTime(2026, 10, 3)),
        _m(costo: 30000, fecha: DateTime(2026, 9, 28)),
        _m(costo: 87520, fecha: DateTime(2026, 9, 15)),
        _m(costo: 10000, fecha: DateTime(2025, 10, 5)),
      ];
      expect(calcularGasto(lista, octubre).total, 45000);
      expect(calcularGasto(lista, PeriodoGasto.mes(DateTime(2026, 9))).total,
          117520);
      expect(calcularGasto(lista, PeriodoGasto.anio(hoy)),
          (total: 162520, cantidad: 3));
      expect(calcularGasto(lista, PeriodoGasto.todo()),
          (total: 172520, cantidad: 4));
    });
  });

  group('periodos', () {
    test('contiene compara por fecha calendario', () {
      expect(octubre.contiene(DateTime(2026, 10, 31, 23, 59)), isTrue);
      expect(octubre.contiene(DateTime(2026, 11, 1)), isFalse);
      expect(octubre.contiene(DateTime(2025, 10, 15)), isFalse);
      expect(PeriodoGasto.anio(hoy).contiene(DateTime(2026, 1, 1)), isTrue);
      expect(PeriodoGasto.anio(hoy).contiene(DateTime(2025, 12, 31)), isFalse);
      expect(PeriodoGasto.todo().contiene(DateTime(1999, 1, 1)), isTrue);
    });

    test('primer mes con mantenciones y etiquetas', () {
      final lista = [
        _m(costo: 1, fecha: DateTime(2026, 3, 9)),
        _m(costo: 1, fecha: DateTime(2025, 11, 30)),
      ];
      expect(primerMesConMantenciones(lista), DateTime(2025, 11));
      expect(primerMesConMantenciones(const []), isNull);
      expect(octubre.etiqueta, 'Octubre 2026');
      expect(PeriodoGasto.mes(DateTime(2027, 1)).etiqueta, 'Enero 2027');
      expect(PeriodoGasto.anio(hoy).etiqueta, '2026');
      expect(PeriodoGasto.todo().etiqueta, 'Todo');
    });
  });

  group('formato', () {
    test('CLP con separador de miles por punto, sin decimales', () {
      expect(clp(87000), '\$87.000');
      expect(clp(12345678), '\$12.345.678');
      expect(clp(0), '\$0');
    });

    test('singular y plural', () {
      expect(textoCantidad(1), '1 mantención');
      expect(textoCantidad(3), '3 mantenciones');
    });
  });

  group('widgets', () {
    Widget app(Widget hijo) => MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Padding(padding: const EdgeInsets.all(16), child: hijo),
          ),
        );

    testWidgets('el monto grande no desborda con \$12.345.678 en pantalla angosta',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const MontoPeriodo(
        resumen: (total: 12345678, cantidad: 2),
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('\$12.345.678'), findsOneWidget);
      expect(find.text('2 mantenciones'), findsOneWidget);
      expect(find.textContaining('promedio'), findsNothing);
      expect(find.textContaining('vs '), findsNothing);
    });

    testWidgets('estado vacío: \$0 y texto de sin mantenciones', (tester) async {
      await tester.pumpWidget(app(const MontoPeriodo(
        resumen: (total: 0, cantidad: 0),
      )));
      expect(find.text('\$0'), findsOneWidget);
      expect(find.text('Sin mantenciones en este periodo'), findsOneWidget);
      expect(find.textContaining('Sin registros'), findsNothing);
    });

    testWidgets('la píldora muestra el periodo, abre el selector y no hay flechas',
        (tester) async {
      var abrio = false;
      await tester.pumpWidget(app(PildoraPeriodo(
        periodo: octubre,
        onElegir: () => abrio = true,
      )));

      expect(find.text('Octubre 2026'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.bySemanticsLabel('Elegir mes, octubre 2026'), findsOneWidget);

      await tester.tap(find.text('Octubre 2026'));
      expect(abrio, isTrue);
    });

    testWidgets('los segmentos son compactos y cambian de tipo', (tester) async {
      TipoPeriodo? elegido;
      await tester.pumpWidget(app(SegmentosPeriodo(
        seleccionado: TipoPeriodo.mes,
        onChanged: (t) => elegido = t,
      )));

      // La barra de botones no ocupa todo el ancho (800 en la prueba).
      final barra = find.descendant(
        of: find.byType(SegmentosPeriodo),
        matching: find.byType(Row),
      );
      expect(tester.getSize(barra).width, lessThan(300));

      for (final texto in ['Mes', 'Año', 'Todo']) {
        final caja = tester.getSize(find.ancestor(
          of: find.text(texto),
          matching: find.byType(AnimatedContainer),
        ));
        expect(caja.height, lessThanOrEqualTo(36));
      }
      await tester.tap(find.text('Año'));
      expect(elegido, TipoPeriodo.anio);
    });

    testWidgets('el pie solo tiene "Ver detalle"', (tester) async {
      var abrio = false;
      await tester.pumpWidget(app(PieGasto(onVerDetalle: () => abrio = true)));
      expect(find.text('Total histórico'), findsNothing);
      expect(find.text('Ver detalle'), findsOneWidget);

      await tester.tap(find.text('Ver detalle'));
      expect(abrio, isTrue);
    });
  });
}
