import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/tipo_mantencion.dart';
import 'package:tag_ok/screens/mantenimiento/selector_tipo_mantencion.dart';

void main() {
  final opciones = [
    for (final t in TipoMantencion.values)
      if (t != TipoMantencion.otra) t.etiqueta,
    'Otros',
  ];

  Future<TextEditingController> abrir(
    WidgetTester tester,
    List<String?> elegidos,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? valor;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SelectorTipoMantencion(
              label: 'Tipo de mantención *',
              hint: 'Seleccionar tipo',
              opciones: opciones,
              valor: valor,
              otroController: controller,
              opcionOtra: 'Otros',
              largoMaximoOtro: 60,
              flotante: true,
              onChanged: (v) {
                elegidos.add(v);
                setState(() {
                  valor = v;
                  controller.text = v == 'Otros' ? '' : v;
                });
              },
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('la lista incluye los tipos y "Otros"; elegir uno lo selecciona', (tester) async {
    final elegidos = <String?>[];
    final controller = await abrir(tester, elegidos);

    await tester.tap(find.text('Seleccionar tipo'));
    await tester.pumpAndSettle();
    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.text('Frenos'), findsOneWidget);
    // "Otros" es la última opción: la lista tiene alto limitado y se desliza.
    expect(find.text('Otros'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Otros'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Frenos'));
    await tester.pumpAndSettle();
    expect(elegidos, ['Frenos']);
    expect(controller.text, 'Frenos');
    // Con un tipo de la lista no hay casilla para escribir.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('"Otros" muestra la casilla para escribir el tipo, con límite de 60', (tester) async {
    final elegidos = <String?>[];
    final controller = await abrir(tester, elegidos);

    await tester.tap(find.text('Seleccionar tipo'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otros'));
    await tester.pumpAndSettle();

    final casilla = find.byType(TextField);
    expect(casilla, findsOneWidget);
    expect(find.text('Escribe el tipo de mantención'), findsOneWidget);
    expect(tester.widget<TextField>(casilla).maxLength, 60);

    await tester.enterText(casilla, 'Cambio de correa de distribución');
    expect(controller.text, 'Cambio de correa de distribución');
  });
}
