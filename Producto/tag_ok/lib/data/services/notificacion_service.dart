import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../screens/dashboard/dashboard_logica.dart' show formatearMiles;
import '../models/notificacion_config_model.dart';
import 'aviso_navegador_service.dart';
import 'recordatorio_local_service.dart';

/// Un aviso por crear: su id en `notificaciones`, el día en que corresponde y
/// el texto que verá el usuario.
typedef AvisoProgramado = ({String id, DateTime fechaProgramada, String mensaje});

/// Sufijos de id de los recordatorios de una mantención (`{id}_7dias`,
/// `{id}_dia`).
const List<String> sufijosAvisoMantencion = ['7dias', 'dia'];

/// Recordatorios de una mantención programada (RF-012): 7 días antes y el
/// mismo día de la fecha programada.
List<AvisoProgramado> avisosMantencion({
  required String mantencionId,
  required String nombreMantencion,
  required DateTime proximaFecha,
  String? patente,
}) {
  final que = _queMantencion(nombreMantencion, patente);
  return [
    (
      id: '${mantencionId}_7dias',
      fechaProgramada: proximaFecha.subtract(const Duration(days: 7)),
      mensaje: 'Mantención programada en 7 días: $que.',
    ),
    (
      id: '${mantencionId}_dia',
      fechaProgramada: proximaFecha,
      mensaje: 'Hoy tienes una mantención programada: $que.',
    ),
  ];
}

/// "Cambio de aceite (ABCD12)", o solo el nombre si no hay patente.
String _queMantencion(String nombreMantencion, String? patente) =>
    (patente ?? '').trim().isEmpty
        ? nombreMantencion
        : '$nombreMantencion (${patente!.trim()})';

/// Cuántos km antes del kilometraje programado se avisa que la mantención se
/// acerca (acordado en el Sprint 5; los requisitos no fijan un valor).
const int margenAvisoKilometraje = 1000;

/// Sufijos de id de los avisos por kilometraje de una mantención
/// (`{id}_km_cerca`, `{id}_km_alcanzado`).
const List<String> sufijosAvisoMantencionKm = ['km_cerca', 'km_alcanzado'];

/// Aviso por kilometraje (HU-11/HU-48) que corresponde a una mantención
/// programada a los [proximoKilometraje] km, con el vehículo en
/// [kilometrajeActual]:
///  - llegó o pasó el km programado: `{id}_km_alcanzado`;
///  - le faltan [margenAvisoKilometraje] km o menos: `{id}_km_cerca`;
///  - le falta más: null (todavía no se avisa).
/// El aviso queda para [ahora]: se genera cuando sube el km, no se agenda.
AvisoProgramado? avisoMantencionKm({
  required String mantencionId,
  required String nombreMantencion,
  required int proximoKilometraje,
  required int kilometrajeActual,
  required DateTime ahora,
  String? patente,
}) {
  final que = _queMantencion(nombreMantencion, patente);
  final programado = formatearMiles(proximoKilometraje);
  final faltan = proximoKilometraje - kilometrajeActual;
  if (faltan <= 0) {
    return (
      id: '${mantencionId}_km_alcanzado',
      fechaProgramada: ahora,
      mensaje: 'Tu vehículo llegó a los $programado km: toca la mantención '
          '$que.',
    );
  }
  if (faltan <= margenAvisoKilometraje) {
    return (
      id: '${mantencionId}_km_cerca',
      fechaProgramada: ahora,
      mensaje: 'Faltan ${formatearMiles(faltan)} km para la mantención $que '
          '(a los $programado km).',
    );
  }
  return null;
}

/// Servicio para configurar avisos preventivos en Firestore y entregarlos al
/// cliente: vencimiento de documentos y mantenciones programadas.
///
/// Los avisos se guardan en `notificaciones` y se entregan de dos formas:
/// - Notificación local programada en el dispositivo
///   (`RecordatoriosLocalesService`, Android/iOS), aun con la app cerrada.
/// - Bandeja dentro de la app (`NotificacionesScreen`), que también funciona
///   en web.
class NotificacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notificaciones =>
      _firestore.collection('notificaciones');

  CollectionReference<Map<String, dynamic>> get _vehiculos =>
      _firestore.collection('vehiculos');

  /// Crea los avisos preventivos para un documento vehicular.
  ///
  /// - 30 días antes del vencimiento
  /// - 15 días antes del vencimiento
  /// - 7 días antes del vencimiento
  Future<void> configurarNotificacionesVencimiento({
    required String vehiculoId,
    required String documentoId,
    required String nombreDocumento,
    required DateTime fechaVencimiento,
  }) async {
    final vehiculo = await _datosVehiculo(vehiculoId);

    final avisos = <AvisoProgramado>[
      (
        id: '${documentoId}_30dias',
        fechaProgramada: fechaVencimiento.subtract(const Duration(days: 30)),
        mensaje: 'Recordatorio: $nombreDocumento vence en 30 días.',
      ),
      (
        id: '${documentoId}_15dias',
        fechaProgramada: fechaVencimiento.subtract(const Duration(days: 15)),
        mensaje: 'Recordatorio: $nombreDocumento vence en 15 días.',
      ),
      (
        id: '${documentoId}_7dias',
        fechaProgramada: fechaVencimiento.subtract(const Duration(days: 7)),
        mensaje: 'Recordatorio: $nombreDocumento vence en 7 días.',
      ),
    ];

    await _guardarAvisos(
      usuarioId: _resolverUsuarioId(vehiculo),
      vehiculoId: vehiculoId,
      referenciaId: documentoId,
      tipo: tipoAvisoVencimientoDocumento,
      avisos: avisos,
    );
  }

  /// Crea (o reemplaza) los recordatorios de una mantención programada:
  /// 7 días antes y el mismo día de [proximaFecha] (RF-012).
  Future<void> configurarRecordatoriosMantencion({
    required String vehiculoId,
    required String mantencionId,
    required String nombreMantencion,
    required DateTime proximaFecha,
  }) async {
    final vehiculo = await _datosVehiculo(vehiculoId);
    final patente = vehiculo['patente'];

    await _guardarAvisos(
      usuarioId: _resolverUsuarioId(vehiculo),
      vehiculoId: vehiculoId,
      referenciaId: mantencionId,
      tipo: tipoAvisoMantencion,
      avisos: avisosMantencion(
        mantencionId: mantencionId,
        nombreMantencion: nombreMantencion,
        proximaFecha: proximaFecha,
        patente: patente is String ? patente : null,
      ),
    );
  }

  /// Crea el aviso por kilometraje de una mantención programada si el
  /// vehículo ya está cerca o llegó a [proximoKilometraje] (ver
  /// [avisoMantencionKm]). Cada aviso se crea una sola vez: si ya existe, se
  /// deja como está (leído o no), así cada nueva carga no lo repite.
  /// [kilometrajeActual] es el km recién guardado; si es null se usa el del
  /// vehículo.
  Future<void> configurarAvisoKilometrajeMantencion({
    required String vehiculoId,
    required String mantencionId,
    required String nombreMantencion,
    required int proximoKilometraje,
    int? kilometrajeActual,
  }) async {
    final vehiculo = await _datosVehiculo(vehiculoId);
    final km = kilometrajeActual ??
        (vehiculo['kilometraje_actual'] as num?)?.toInt();
    if (km == null) return;

    final patente = vehiculo['patente'];
    final ahora = DateTime.now();
    final aviso = avisoMantencionKm(
      mantencionId: mantencionId,
      nombreMantencion: nombreMantencion,
      proximoKilometraje: proximoKilometraje,
      kilometrajeActual: km,
      ahora: ahora,
      patente: patente is String ? patente : null,
    );
    if (aviso == null) return;

    final ref = _notificaciones.doc(aviso.id);
    if ((await ref.get()).exists) return;

    final notificacion = NotificacionConfigModel(
      id: aviso.id,
      usuarioId: _resolverUsuarioId(vehiculo),
      vehiculoId: vehiculoId,
      tipo: tipoAvisoMantencionKm,
      referenciaId: mantencionId,
      mensaje: aviso.mensaje,
      fechaProgramada: aviso.fechaProgramada,
      fechaGeneracion: ahora,
      leida: false,
      estado: 'pendiente',
    );
    await ref.set(notificacion.toJson());
    await RecordatoriosLocalesService.instance.programar(notificacion);
    // En web el navegador revisa los avisos cada 15 minutos; éste nace ahora
    // (al subir el km), así que se muestra sin esperar esa revisión.
    if (kIsWeb) {
      unawaited(
        AvisoNavegadorService.instance.revisar(notificacion.usuarioId),
      );
    }
  }

  /// Borra todos los avisos de una mantención: por fecha (7 días antes y el
  /// mismo día) y por kilometraje (cerca y alcanzado).
  Future<void> eliminarRecordatoriosMantencion(String mantencionId) async {
    await eliminarRecordatoriosFechaMantencion(mantencionId);
    await eliminarAvisosKilometrajeMantencion(mantencionId);
  }

  /// Borra los recordatorios por fecha de una mantención.
  Future<void> eliminarRecordatoriosFechaMantencion(String mantencionId) =>
      _eliminarAvisos(mantencionId, sufijosAvisoMantencion);

  /// Borra los avisos por kilometraje de una mantención.
  Future<void> eliminarAvisosKilometrajeMantencion(String mantencionId) =>
      _eliminarAvisos(mantencionId, sufijosAvisoMantencionKm);

  Future<void> _eliminarAvisos(
    String referenciaId,
    List<String> sufijos,
  ) async {
    for (final sufijo in sufijos) {
      final id = '${referenciaId}_$sufijo';
      await _notificaciones.doc(id).delete();
      await RecordatoriosLocalesService.instance.cancelar(id);
    }
  }

  Future<Map<String, dynamic>> _datosVehiculo(String vehiculoId) async {
    final vehiculoDoc = await _vehiculos.doc(vehiculoId).get();
    if (!vehiculoDoc.exists) {
      throw StateError(
        'No existe el vehículo $vehiculoId para generar la notificación.',
      );
    }
    return vehiculoDoc.data() ?? {};
  }

  /// Guarda cada aviso en `notificaciones` y lo programa en el dispositivo.
  /// Los avisos cuyo día ya pasó no se crean (y se borran si existían).
  Future<void> _guardarAvisos({
    required String usuarioId,
    required String vehiculoId,
    required String referenciaId,
    required String tipo,
    required List<AvisoProgramado> avisos,
  }) async {
    if (usuarioId.trim().isEmpty) {
      throw StateError(
        'No se pudo obtener un usuario válido para el vehículo $vehiculoId.',
      );
    }

    final ahora = DateTime.now();
    final hoy = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
    );

    for (final aviso in avisos) {
      final fechaProgramada = aviso.fechaProgramada;
      final fechaProgramadaSoloDia = DateTime(
        fechaProgramada.year,
        fechaProgramada.month,
        fechaProgramada.day,
      );

      final ref = _notificaciones.doc(aviso.id);

      if (fechaProgramadaSoloDia.isBefore(hoy)) {
        final existente = await ref.get();

        if (existente.exists) {
          await ref.delete();
        }
        await RecordatoriosLocalesService.instance.cancelar(aviso.id);

        continue;
      }

      final notificacion = NotificacionConfigModel(
        id: aviso.id,
        usuarioId: usuarioId,
        vehiculoId: vehiculoId,
        tipo: tipo,
        referenciaId: referenciaId,
        mensaje: aviso.mensaje,
        fechaProgramada: fechaProgramada,
        fechaGeneracion: DateTime.now(),
        leida: false,
        estado: 'pendiente',
      );

      await ref.set(notificacion.toJson());
      await RecordatoriosLocalesService.instance.programar(notificacion);
    }
  }

  /// Borra los avisos de vencimiento de un documento (30, 15 y 7 días).
  Future<void> eliminarNotificacionesDocumento(String documentoId) =>
      _eliminarAvisos(documentoId, const ['30dias', '15dias', '7dias']);

  /// Avisos del usuario en tiempo real (más recientes primero). Se filtra
  /// solo por `usuario_id` para no requerir un índice compuesto; el orden y
  /// el corte "ya toca / aún no" se hacen en el cliente.
  Stream<List<NotificacionConfigModel>> escucharDelUsuario(String usuarioId) {
    return _notificaciones
        .where('usuario_id', isEqualTo: usuarioId)
        .snapshots()
        .map((snap) {
      final lista = <NotificacionConfigModel>[];
      for (final doc in snap.docs) {
        try {
          lista.add(NotificacionConfigModel.fromJson(doc.data(), doc.id));
        } catch (e) {
          debugPrint('NotificacionService: aviso ${doc.id} inválido: $e');
        }
      }
      lista.sort((a, b) => (b.fechaProgramada ?? b.fechaGeneracion)
          .compareTo(a.fechaProgramada ?? a.fechaGeneracion));
      return lista;
    });
  }

  /// Lectura única de los avisos del usuario (para sincronizar el celular).
  Future<List<NotificacionConfigModel>> obtenerDelUsuario(
    String usuarioId,
  ) async {
    final snap = await _notificaciones
        .where('usuario_id', isEqualTo: usuarioId)
        .get();
    final lista = <NotificacionConfigModel>[];
    for (final doc in snap.docs) {
      try {
        lista.add(NotificacionConfigModel.fromJson(doc.data(), doc.id));
      } catch (e) {
        debugPrint('NotificacionService: aviso ${doc.id} inválido: $e');
      }
    }
    return lista;
  }

  /// Programa en el dispositivo los avisos pendientes del usuario y pide el
  /// permiso de notificaciones. Se llama al abrir la app ya autenticado.
  Future<void> sincronizarDispositivo(String usuarioId) async {
    try {
      await RecordatoriosLocalesService.instance.pedirPermiso();
      final avisos = await obtenerDelUsuario(usuarioId);
      await RecordatoriosLocalesService.instance.sincronizar(avisos);
    } catch (e) {
      debugPrint('NotificacionService: no se pudo sincronizar el equipo: $e');
    }
  }

  Future<void> marcarLeida(String id) async {
    await _notificaciones.doc(id).update({'leida': true, 'estado': 'leida'});
    await RecordatoriosLocalesService.instance.cancelar(id);
  }

  Future<void> marcarTodasLeidas(Iterable<String> ids) async {
    final batch = _firestore.batch();
    var hay = false;
    for (final id in ids) {
      batch.update(_notificaciones.doc(id), {'leida': true, 'estado': 'leida'});
      hay = true;
    }
    if (!hay) return;
    await batch.commit();
    for (final id in ids) {
      await RecordatoriosLocalesService.instance.cancelar(id);
    }
  }

  String _resolverUsuarioId(Map<String, dynamic> vehiculoData) {
    final rawUsuarioId = vehiculoData['id_usuario'];

    if (rawUsuarioId == null) {
      throw StateError('El vehículo no tiene definido id_usuario.');
    }

    if (rawUsuarioId is DocumentReference) {
      return rawUsuarioId.id;
    }

    if (rawUsuarioId is String && rawUsuarioId.trim().isNotEmpty) {
      return rawUsuarioId.trim();
    }

    throw StateError(
      'El campo id_usuario del vehículo tiene un formato incompatible. Debe ser DocumentReference o String.',
    );
  }
}
