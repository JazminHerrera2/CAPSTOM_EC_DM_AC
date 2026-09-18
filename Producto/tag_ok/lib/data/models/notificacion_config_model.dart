import 'package:cloud_firestore/cloud_firestore.dart';

/// Entidad NOTIFICACIONES, acotada a lo que usa CU4 este Sprint: guardar la
/// configuración de vencimiento. El envío real (push/in-app) es Sprint 5 /
/// EP-08 y no agrega campos nuevos a este modelo, así que no se anticipan
/// aquí para no inventar estructura que todavía no está definida.
class NotificacionConfigModel {
  final String id;
  final String usuarioId;
  final String? vehiculoId;
  final String tipo;
  final String? referenciaId;
  final String mensaje;
  final DateTime? fechaProgramada;
  final DateTime fechaGeneracion;
  final bool leida;
  final String estado;

  NotificacionConfigModel({
    required this.id,
    required this.usuarioId,
    this.vehiculoId,
    required this.tipo,
    this.referenciaId,
    required this.mensaje,
    this.fechaProgramada,
    required this.fechaGeneracion,
    this.leida = false,
    this.estado = 'pendiente',
  });

  factory NotificacionConfigModel.fromJson(
    Map<String, dynamic> json,
    String id,
  ) {
    return NotificacionConfigModel(
      id: id,
      usuarioId: json['usuario_id'] ?? '',
      vehiculoId: json['vehiculo_id'],
      tipo: json['tipo'] ?? '',
      referenciaId: json['referencia_id'],
      mensaje: json['mensaje'] ?? '',
      fechaProgramada: (json['fecha_programada'] as Timestamp?)?.toDate(),
      fechaGeneracion: (json['fecha_generacion'] as Timestamp).toDate(),
      leida: json['leida'] ?? false,
      estado: json['estado'] ?? 'pendiente',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario_id': usuarioId,
      'vehiculo_id': vehiculoId,
      'tipo': tipo,
      'referencia_id': referenciaId,
      'mensaje': mensaje,
      'fecha_programada': fechaProgramada != null
          ? Timestamp.fromDate(fechaProgramada!)
          : null,
      'fecha_generacion': Timestamp.fromDate(fechaGeneracion),
      'leida': leida,
      'estado': estado,
    };
  }
}
