import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/modo_tema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ModoTema.cambiar(false);
  });

  test('por defecto la app parte en modo claro', () async {
    await ModoTema.cargar();
    expect(ModoTema.oscuro.value, isFalse);
    expect(AppColors.fondo, const Color(0xFFF6F4FE));
  });

  test('el modo oscuro usa la paleta oscura y se guarda', () async {
    await ModoTema.cambiar(true);
    expect(AppColors.fondo, const Color(0xFF13111C));
    expect(AppColors.superficie, const Color(0xFF1E1B2B));
    expect(AppColors.primario, const Color(0xFFAB9FF2));
    expect(AppColors.texto, const Color(0xFFF4F2FF));
    // La tarjeta de gastos sigue violeta.
    expect(AppColors.violeta, const Color(0xFF5B4CDB));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('modo_oscuro'), isTrue);
  });

  test('al abrir la app se recupera el modo guardado', () async {
    SharedPreferences.setMockInitialValues({'modo_oscuro': true});
    await ModoTema.cargar();
    expect(ModoTema.oscuro.value, isTrue);
    expect(AppColors.oscuro, isTrue);
  });
}
