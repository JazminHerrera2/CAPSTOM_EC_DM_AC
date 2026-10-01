import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notificacion_config_model.dart';

/// Servicio para configurar avisos preventivos de vencimiento en Firestore.
///
/// El envío real push/in-app queda fuera de este alcance (Sprint 5 / EP-08).
class NotificacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notificaciones =>
      _firestore.collection('notificaciones');

  CollectionReference<Map<String, dynamic>> get _vehiculos =>
      _firestore.collection('vehiculos');

  /// Crea los avisos preventivos para un documento vehicular.
  ///
  /// - 15 días antes del vencimiento
  /// - 7 días antes del vencimiento
  Future<void> configurarNotificacionesVencimiento({
    required String vehiculoId,
    required String documentoId,
    required String nombreDocumento,
    required DateTime fechaVencimiento,
  }) async {
    final vehiculoDoc = await _vehiculos.doc(vehiculoId).get();
    if (!vehiculoDoc.exists) {
      throw StateError(
        'No existe el vehículo $vehiculoId para generar la notificación de vencimiento.',
      );
    }

    final usuarioId = _resolverUsuarioId(vehiculoDoc.data() ?? {});
    if (usuarioId.trim().isEmpty) {
      throw StateError(
        'No se pudo obtener un usuario válido para el vehículo $vehiculoId.',
      );
    }

    final avisos = <({String id, DateTime fechaProgramada, String mensaje})>[
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

        continue;
      }

      final notificacion = NotificacionConfigModel(
        id: aviso.id,
        usuarioId: usuarioId,
        vehiculoId: vehiculoId,
        tipo: 'vencimiento_documento',
        referenciaId: documentoId,
        mensaje: aviso.mensaje,
        fechaProgramada: fechaProgramada,
        fechaGeneracion: DateTime.now(),
        leida: false,
        estado: 'pendiente',
      );

      await ref.set(notificacion.toJson());
    }
  }

  /// Borra los avisos de vencimiento de un documento (15 y 7 días).
  Future<void> eliminarNotificacionesDocumento(String documentoId) async {
    for (final sufijo in const ['15dias', '7dias']) {
      await _notificaciones.doc('${documentoId}_$sufijo').delete();
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
