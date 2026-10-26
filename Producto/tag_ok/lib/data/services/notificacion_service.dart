import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notificacion_config_model.dart';
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
  final que = (patente ?? '').trim().isEmpty
      ? nombreMantencion
      : '$nombreMantencion (${patente!.trim()})';
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

  /// Borra los recordatorios de una mantención (7 días antes y el mismo día).
  Future<void> eliminarRecordatoriosMantencion(String mantencionId) async {
    for (final sufijo in sufijosAvisoMantencion) {
      final id = '${mantencionId}_$sufijo';
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
  Future<void> eliminarNotificacionesDocumento(String documentoId) async {
    for (final sufijo in const ['30dias', '15dias', '7dias']) {
      final id = '${documentoId}_$sufijo';
      await _notificaciones.doc(id).delete();
      await RecordatoriosLocalesService.instance.cancelar(id);
    }
  }

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
