import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// Modo claro / oscuro de la app.
///
/// Por defecto la app parte en modo claro. El switch del Inicio llama a
/// [cambiar]; la elección se guarda en el dispositivo y se recupera al abrir
/// la app ([cargar], en main.dart).
abstract final class ModoTema {
  static const String _clave = 'modo_oscuro';

  /// true = modo oscuro. MyApp lo escucha para cambiar el tema de Material.
  static final ValueNotifier<bool> oscuro = ValueNotifier<bool>(false);

  /// Lee la preferencia guardada. Si no hay (o falla la lectura), modo claro.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _aplicar(prefs.getBool(_clave) ?? false);
    } catch (e) {
      debugPrint('ModoTema: no se pudo leer la preferencia: $e');
    }
  }

  /// Cambia el modo, redibuja toda la app y guarda la elección.
  static Future<void> cambiar(bool valor) async {
    if (valor == oscuro.value) return;
    _aplicar(valor);
    _reconstruirTodo();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clave, valor);
    } catch (e) {
      debugPrint('ModoTema: no se pudo guardar la preferencia: $e');
    }
  }

  static void _aplicar(bool valor) {
    AppColors.oscuro = valor;
    oscuro.value = valor;
  }

  /// Las pantallas leen AppColors al construirse, y Flutter no vuelve a
  /// construir los widgets que no cambiaron. Se marcan todos para que se
  /// redibujen con la paleta nueva, sin perder su estado (pestaña abierta,
  /// scroll, formularios).
  static void _reconstruirTodo() {
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(marcar);
  }
}
