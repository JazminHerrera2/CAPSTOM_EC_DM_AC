import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/screens/mantenimiento/gasto_periodo.dart';
import 'package:tag_ok/screens/mantenimiento/selector_periodo_gasto.dart';
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
      tipo: 'Cambio de aceite',
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

    test('etiquetas', () {
      expect(octubre.etiqueta, 'Octubre 2026');
      expect(PeriodoGasto.mes(DateTime(2027, 1)).etiqueta, 'Enero 2027');
      expect(PeriodoGasto.anio(hoy).etiqueta, '2026');
      expect(PeriodoGasto.todo().etiqueta, 'Todo');
    });

    test('solo salen los meses y años con registros, del más reciente al más antiguo',
        () {
      final lista = [
        _m(costo: 45000, fecha: DateTime(2026, 10, 3)),
        _m(costo: 30000, fecha: DateTime(2026, 10, 28)), // mismo mes
        _m(costo: 87520, fecha: DateTime(2026, 7, 15)),
        _m(costo: 10000, fecha: DateTime(2024, 3, 5)),
        _m(costo: null, fecha: DateTime(2026, 9, 9)), // sin costo: no cuenta
        _m(costo: 5000, fecha: null), // sin fecha: no cuenta
        _m(
          costo: 9999,
          fecha: DateTime(2026, 8, 1),
          estado: EstadoMantencion.programada, // programada: no cuenta
        ),
      ];

      expect(mesesConMantenciones(lista), [
        DateTime(2026, 10),
        DateTime(2026, 7),
        DateTime(2024, 3),
      ]);
      // Septiembre y agosto no aparecen; 2025 tampoco.
      expect(aniosConMantenciones(lista), [2026, 2024]);
      expect(mesesConMantenciones(const []), isEmpty);
      expect(aniosConMantenciones(const []), isEmpty);
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

    Future<void> abrirSelector(
      WidgetTester tester, {
      required PeriodoGasto actual,
      required List<DateTime> meses,
      required List<int> anios,
      required void Function(PeriodoGasto?) alCerrar,
    }) async {
      await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => alCerrar(await mostrarSelectorPeriodo(
            context,
            actual: actual,
            meses: meses,
            anios: anios,
          )),
          child: const Text('abrir'),
        ),
      )));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('el selector de mes solo ofrece los meses con registros',
        (tester) async {
      PeriodoGasto? elegido;
      await abrirSelector(
        tester,
        actual: octubre,
        meses: [DateTime(2026, 10), DateTime(2026, 7), DateTime(2024, 3)],
        anios: [2026, 2024],
        alCerrar: (p) => elegido = p,
      );

      expect(find.text('Oct'), findsOneWidget);
      expect(find.text('Jul'), findsOneWidget);
      expect(find.text('Mar'), findsOneWidget);
      // Sin registros: no son opción.
      expect(find.text('Sep'), findsNothing);
      expect(find.text('Ago'), findsNothing);
      expect(find.text('Ene'), findsNothing);
      // Se agrupan por año, y 2025 (sin registros) no aparece.
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2025'), findsNothing);

      await tester.tap(find.text('Jul'));
      await tester.pumpAndSettle();
      expect(elegido, PeriodoGasto.mes(DateTime(2026, 7)));
    });

    testWidgets('el selector de año solo ofrece los años con registros',
        (tester) async {
      PeriodoGasto? elegido;
      await abrirSelector(
        tester,
        actual: PeriodoGasto.anio(hoy),
        meses: [DateTime(2026, 10), DateTime(2024, 3)],
        anios: [2026, 2024],
        alCerrar: (p) => elegido = p,
      );

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2025'), findsNothing);

      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      expect(elegido, PeriodoGasto.anio(DateTime(2024)));
    });

    testWidgets('sin ninguna mantención el selector lo dice y no ofrece nada',
        (tester) async {
      await abrirSelector(
        tester,
        actual: octubre,
        meses: const [],
        anios: const [],
        alCerrar: (_) {},
      );
      expect(find.textContaining('Aún no tienes mantenciones'), findsOneWidget);
      expect(find.text('Oct'), findsNothing);
    });

    testWidgets('botones a la izquierda y la opción de mes a la derecha, sin desbordar en 320 px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(Row(
        children: [
          SegmentosPeriodo(seleccionado: TipoPeriodo.mes, onChanged: (_) {}),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: PildoraPeriodo(
                periodo: PeriodoGasto.mes(DateTime(2026, 9)),
                onElegir: () {},
              ),
            ),
          ),
        ],
      )));

      expect(tester.takeException(), isNull);
      final izquierda = tester.getTopLeft(find.text('Mes')).dx;
      final derecha = tester.getTopLeft(find.text('Septiembre 2026')).dx;
      expect(izquierda, lessThan(derecha));
    });
  });
}
