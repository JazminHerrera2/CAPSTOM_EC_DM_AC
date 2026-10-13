import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/notificacion_navegador.dart';
import '../models/notificacion_config_model.dart';
import 'notificacion_service.dart';
import 'recordatorio_local_service.dart' show horaAvisoVencimiento;

/// `true` si [n] ya debe mostrarse en el navegador: sigue pendiente, no fue
/// leído, su día llegó y (si es hoy) ya pasó la hora de aviso.
bool avisoListoParaNavegador(NotificacionConfigModel n, DateTime ahora) {
  if (n.leida || n.estado != 'pendiente') return false;
  final fecha = n.fechaProgramada;
  if (fecha == null) return true;

  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  if (dia.isBefore(hoy)) return true;
  if (dia.isAfter(hoy)) return false;
  return ahora.hour >= horaAvisoVencimiento;
}

/// Clave para no repetir un aviso en el navegador. Incluye la fecha
/// programada: si el documento se vuelve a guardar con otro vencimiento, el
/// aviso (mismo id) debe poder mostrarse de nuevo.
String claveAvisoMostrado(NotificacionConfigModel n) =>
    '${n.id}@${n.fechaProgramada?.millisecondsSinceEpoch ?? 0}';

/// Notificaciones del navegador para los avisos de vencimiento (web).
///
/// Solo avisa mientras la web está abierta: el navegador no puede programar
/// notificaciones con la pestaña cerrada sin push (FCM + Cloud Function).
class AvisoNavegadorService {
  AvisoNavegadorService._();
  static final AvisoNavegadorService instance = AvisoNavegadorService._();

  static const String _prefsClave = 'avisos_navegador_mostrados';
  static const Duration _intervalo = Duration(minutes: 15);

  Timer? _timer;

  /// Revisa ahora y luego cada 15 minutos (para cubrir que llegue las 9:00
  /// con la pestaña abierta).
  void iniciar(String usuarioId) {
    if (!navegadorSoportaNotificaciones) return;
    detener();
    unawaited(revisar(usuarioId));
    _timer = Timer.periodic(_intervalo, (_) => revisar(usuarioId));
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
  }

  /// Muestra en el navegador los avisos que ya tocan y no se han mostrado.
  /// Devuelve cuántos mostró.
  Future<int> revisar(String usuarioId) async {
    if (permisoNotificacionNavegador != 'granted') return 0;
    try {
      final avisos = await NotificacionService().obtenerDelUsuario(usuarioId);
      return await mostrarPendientes(avisos, DateTime.now());
    } catch (e) {
      debugPrint('AvisoNavegadorService: no se pudo revisar: $e');
      return 0;
    }
  }

  @visibleForTesting
  Future<int> mostrarPendientes(
    List<NotificacionConfigModel> avisos,
    DateTime ahora, {
    SharedPreferences? prefs,
  }) async {
    final almacen = prefs ?? await SharedPreferences.getInstance();
    final mostrados = (almacen.getStringList(_prefsClave) ?? const <String>[])
        .toSet();

    var nuevos = 0;
    for (final aviso in avisos) {
      if (aviso.tipo != 'vencimiento_documento') continue;
      if (!avisoListoParaNavegador(aviso, ahora)) continue;
      final clave = claveAvisoMostrado(aviso);
      if (mostrados.contains(clave)) continue;

      mostrarNotificacionNavegador(
        titulo: 'Documento por vencer',
        cuerpo: aviso.mensaje,
        tag: aviso.id,
      );
      mostrados.add(clave);
      nuevos++;
    }

    if (nuevos > 0) {
      await almacen.setStringList(_prefsClave, mostrados.toList());
    }
    return nuevos;
  }
}
