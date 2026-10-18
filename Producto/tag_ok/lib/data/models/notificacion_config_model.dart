import 'package:cloud_firestore/cloud_firestore.dart';

/// Valores del campo `tipo` de un aviso.
const String tipoAvisoVencimientoDocumento = 'vencimiento_documento';
const String tipoAvisoMantencion = 'mantencion_programada';

/// Tipos de aviso que la app entrega (bandeja, teléfono y navegador).
const Set<String> tiposAvisoEntregables = {
  tipoAvisoVencimientoDocumento,
  tipoAvisoMantencion,
};

/// Título con que se muestra un aviso según su tipo.
String tituloAviso(String tipo) => tipo == tipoAvisoMantencion
    ? 'Mantención programada'
    : 'Documento por vencer';

/// Entidad NOTIFICACIONES: avisos de vencimiento de documentos (CU4) y
/// recordatorios de mantenciones programadas (RF-012). El envío ocurre en el
/// dispositivo (notificación local y bandeja); no hay push desde servidor.
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
