import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/screens/dialogo_cambiar_contrasena.dart';

class _UsuarioFalso extends Fake implements User {}

/// Abre el diálogo desde un botón, como en Perfil. Cualquier excepción del
/// framework (p. ej. controladores liberados mientras el diálogo se cierra)
/// hace fallar el test.
Future<void> _abrir(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) =>
                DialogoCambiarContrasena(user: _UsuarioFalso(), email: 'a@b.cl'),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('abre, se escribe y se cancela sin errores', (tester) async {
    await _abrir(tester);
    expect(find.text('Cambiar contraseña'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'actual123');
    await tester.enterText(find.byType(TextField).at(1), 'nueva456');
    await tester.pump();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar contraseña'), findsNothing);
  });

  testWidgets('valida los campos antes de llamar a Firebase', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Completa los tres campos.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'actual123');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.enterText(find.byType(TextField).at(2), '123');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.textContaining('al menos 6 caracteres'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'nueva456');
    await tester.enterText(find.byType(TextField).at(2), 'otra4567');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.textContaining('no coincide'), findsOneWidget);
  });

  testWidgets('el ojo muestra y oculta la contraseña', (tester) async {
    await _abrir(tester);
    TextField campo(int i) => tester.widget<TextField>(find.byType(TextField).at(i));

    expect(campo(0).obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
    await tester.pump();
    expect(campo(0).obscureText, isFalse);
  });
}
