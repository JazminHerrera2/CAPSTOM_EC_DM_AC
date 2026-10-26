import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/notificacion_config_model.dart';

/// Hora del día (local) a la que se dispara cada aviso de vencimiento.
const int horaAvisoVencimiento = 9;

const String _prefijoPayload = 'venc:';

/// Id numérico estable (31 bits) para un id de Firestore. `String.hashCode`
/// no sirve: no está garantizado que sea igual entre ejecuciones, y el id
/// debe ser el mismo para poder reemplazar o cancelar el aviso más tarde.
int idNotificacionLocal(String idFirestore) {
  var hash = 0x811c9dc5;
  for (final unidad in idFirestore.codeUnits) {
    hash ^= unidad;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// Momento en que debe sonar un aviso programado para [fechaProgramada].
///
/// - Día futuro: ese día a las [horaAvisoVencimiento].
/// - Hoy: a esa hora; si ya pasó, unos segundos después de [ahora] (el aviso
///   corresponde a hoy y el cliente aún no lo ha visto).
/// - Día pasado: `null` (ya no tiene sentido avisar).
DateTime? momentoDeAviso(DateTime fechaProgramada, DateTime ahora) {
  final dia = DateTime(
    fechaProgramada.year,
    fechaProgramada.month,
    fechaProgramada.day,
  );
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  if (dia.isBefore(hoy)) return null;

  final aLaHora = DateTime(dia.year, dia.month, dia.day, horaAvisoVencimiento);
  if (aLaHora.isAfter(ahora)) return aLaHora;
  return ahora.add(const Duration(seconds: 5));
}

/// Canal de Android de cada tipo de aviso: el usuario puede silenciar uno sin
/// perder el otro desde los ajustes del teléfono.
({String id, String nombre, String descripcion}) _canalDe(String tipo) =>
    tipo == tipoAvisoMantencion
        ? (
            id: 'recordatorios_mantencion_v1',
            nombre: 'Mantenciones programadas',
            descripcion: 'Recordatorios de mantenciones programadas',
          )
        : (
            id: 'vencimientos_documentos_v1',
            nombre: 'Vencimientos de documentos',
            descripcion: 'Avisos de documentos del vehículo próximos a vencer',
          );

/// Programa en el dispositivo (Android / iOS) los avisos que
/// `NotificacionService` guarda en Firestore (vencimientos de documentos y
/// mantenciones programadas), para que lleguen aunque la app esté cerrada o
/// no haya internet. En web no hace nada: allí los avisos se ven en la
/// bandeja de notificaciones de la app.
class RecordatoriosLocalesService {
  RecordatoriosLocalesService._();
  static final RecordatoriosLocalesService instance =
      RecordatoriosLocalesService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inicializado = false;

  bool get _soportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> _asegurarInicio() async {
    if (!_soportado) return false;
    if (_inicializado) return true;

    tz_data.initializeTimeZones();
    // Basta una zona fija: se programa un instante absoluto
    // (TZDateTime.from conserva el momento exacto), no una hora "de reloj".
    tz.setLocalLocation(tz.UTC);

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final tipo in tiposAvisoEntregables) {
      final canal = _canalDe(tipo);
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          canal.id,
          canal.nombre,
          description: canal.descripcion,
          importance: Importance.high,
        ),
      );
    }

    _inicializado = true;
    return true;
  }

  /// Pide el permiso de notificaciones (Android 13+ / iOS). Es seguro
  /// llamarlo varias veces: el sistema solo pregunta una vez.
  Future<void> pedirPermiso() async {
    try {
      if (!await _asegurarInicio()) return;
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('RecordatoriosLocales: error al pedir permiso: $e');
    }
  }

  /// Programa (o reemplaza) el aviso [n]. No hace nada si ya fue leído, no
  /// está pendiente o su día ya pasó.
  Future<void> programar(NotificacionConfigModel n) async {
    try {
      if (!await _asegurarInicio()) return;

      final fecha = n.fechaProgramada;
      final momento =
          (n.leida || n.estado != 'pendiente' || fecha == null)
              ? null
              : momentoDeAviso(fecha, DateTime.now());

      final id = idNotificacionLocal(n.id);
      if (momento == null) {
        await _plugin.cancel(id: id);
        return;
      }

      final canal = _canalDe(n.tipo);
      await _plugin.zonedSchedule(
        id: id,
        title: tituloAviso(n.tipo),
        body: n.mensaje,
        scheduledDate: tz.TZDateTime.from(momento, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            canal.id,
            canal.nombre,
            channelDescription: canal.descripcion,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Inexacto a propósito: no requiere el permiso de alarmas exactas y,
        // para un aviso de días, unos minutos de margen no importan.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_prefijoPayload${n.id}',
      );
    } catch (e) {
      debugPrint('RecordatoriosLocales: error al programar ${n.id}: $e');
    }
  }

  Future<void> cancelar(String idFirestore) async {
    try {
      if (!await _asegurarInicio()) return;
      await _plugin.cancel(id: idNotificacionLocal(idFirestore));
    } catch (e) {
      debugPrint('RecordatoriosLocales: error al cancelar $idFirestore: $e');
    }
  }

  /// Deja programados exactamente los avisos de [avisos] (los pendientes y
  /// futuros) y cancela cualquier otro aviso que haya quedado (documento o
  /// mantención borrados desde otro dispositivo, aviso ya leído, etc.).
  Future<void> sincronizar(List<NotificacionConfigModel> avisos) async {
    try {
      if (!await _asegurarInicio()) return;

      final vigentes = <int>{};
      for (final aviso in avisos) {
        if (!tiposAvisoEntregables.contains(aviso.tipo)) continue;
        await programar(aviso);
        final fecha = aviso.fechaProgramada;
        if (!aviso.leida &&
            aviso.estado == 'pendiente' &&
            fecha != null &&
            momentoDeAviso(fecha, DateTime.now()) != null) {
          vigentes.add(idNotificacionLocal(aviso.id));
        }
      }

      final pendientes = await _plugin.pendingNotificationRequests();
      for (final p in pendientes) {
        final esDeVencimiento = p.payload?.startsWith(_prefijoPayload) ?? false;
        if (esDeVencimiento && !vigentes.contains(p.id)) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      debugPrint('RecordatoriosLocales: error al sincronizar: $e');
    }
  }

  /// Quita todos los avisos programados (al cerrar sesión, para que el
  /// siguiente usuario del dispositivo no reciba avisos ajenos).
  Future<void> cancelarTodos() async {
    try {
      if (!await _asegurarInicio()) return;
      final pendientes = await _plugin.pendingNotificationRequests();
      for (final p in pendientes) {
        if (p.payload?.startsWith(_prefijoPayload) ?? false) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      debugPrint('RecordatoriosLocales: error al cancelar todos: $e');
    }
  }
}
