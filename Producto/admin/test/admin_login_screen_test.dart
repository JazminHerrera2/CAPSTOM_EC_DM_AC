import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/screens/admin_login_screen.dart';

// Datos de prueba inventados (no son credenciales reales).
const _correo = 'admin@ejemplo.test';
const _clave = 'clave-de-prueba';

Future<void> _mostrar(
  WidgetTester tester, {
  required double ancho,
  required Future<String?> Function(String, String) onLogin,
  String? errorMessage,
}) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: AdminLoginScreen(onLogin: onLogin, errorMessage: errorMessage),
  ));
  // La línea animada se repite para siempre: no se usa pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _escribir(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), _correo);
  await tester.enterText(find.byType(TextField).at(1), _clave);
}

ElevatedButton _boton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton));

void main() {
  testWidgets('a 1200 px muestra el panel azul y el formulario', (tester) async {
    await _mostrar(tester, ancho: 1200, onLogin: (_, _) async => null);

    expect(find.textContaining('Gestiona tus peajes'), findsOneWidget);
    expect(find.text('Panel administrador'), findsOneWidget);
    expect(find.textContaining('Pórticos y tarifas geolocalizados'), findsOneWidget);
    expect(find.textContaining('Reportes de cruces'), findsOneWidget);
    expect(find.textContaining('© 2026 TAG OK'), findsOneWidget);
    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 600 px se oculta el panel azul y queda el formulario', (tester) async {
    await _mostrar(tester, ancho: 600, onLogin: (_, _) async => null);

    expect(find.textContaining('Gestiona tus peajes'), findsNothing);
    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el botón llama a onLogin con el correo y la contraseña', (tester) async {
    String? recibidoCorreo, recibidoClave;
    await _mostrar(tester, ancho: 1200, onLogin: (e, p) async {
      recibidoCorreo = e;
      recibidoClave = p;
      return null;
    });

    await _escribir(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(recibidoCorreo, _correo);
    expect(recibidoClave, _clave);
  });

  testWidgets('Enter en la contraseña también envía el formulario', (tester) async {
    var llamadas = 0;
    await _mostrar(tester, ancho: 1200, onLogin: (_, _) async {
      llamadas++;
      return null;
    });

    await _escribir(tester);
    await tester.tap(find.byType(TextField).at(1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(llamadas, 1);
  });

  testWidgets('mientras carga, el botón se deshabilita y muestra el indicador',
      (tester) async {
    final espera = Completer<String?>();
    await _mostrar(tester, ancho: 1200, onLogin: (_, _) => espera.future);

    await _escribir(tester);
    expect(_boton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(_boton(tester).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);

    espera.complete(null);
    await tester.pump();
    expect(_boton(tester).onPressed, isNotNull);
  });

  testWidgets('muestra el error que devuelve onLogin', (tester) async {
    await _mostrar(
      tester,
      ancho: 1200,
      onLogin: (_, _) async => 'Credenciales incorrectas.',
    );

    await _escribir(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Credenciales incorrectas.'), findsOneWidget);
  });

  testWidgets('muestra el errorMessage inicial (acceso denegado)', (tester) async {
    await _mostrar(
      tester,
      ancho: 1200,
      onLogin: (_, _) async => null,
      errorMessage: 'Acceso denegado.',
    );
    expect(find.text('Acceso denegado.'), findsOneWidget);
  });

  testWidgets('el ojo muestra y oculta la contraseña', (tester) async {
    await _mostrar(tester, ancho: 1200, onLogin: (_, _) async => null);
    bool oculta() => tester.widget<TextField>(find.byType(TextField).at(1)).obscureText;

    expect(oculta(), isTrue);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(oculta(), isFalse);
  });
}
