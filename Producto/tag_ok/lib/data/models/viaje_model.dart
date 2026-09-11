import 'package:cloud_firestore/cloud_firestore.dart';

class ViajeModel {
  final String id;
  final String usuarioId;
  final String vehiculoId;
  final DateTime horaInicio;
  final DateTime horaFin;
  final double costoTotalCalculado;

  ViajeModel({
    required this.id,
    required this.usuarioId,
    required this.vehiculoId,
    required this.horaInicio,
    required this.horaFin,
    this.costoTotalCalculado = 0.0,
  });

  factory ViajeModel.fromJson(Map<String, dynamic> json, String id) {
    return ViajeModel(
      id: id,
      usuarioId: json['usuario_id'] ?? '',
      vehiculoId: json['vehiculo_id'] ?? '',
      horaInicio: (json['hora_inicio'] as Timestamp).toDate(),
      horaFin: (json['hora_fin'] as Timestamp).toDate(),
      costoTotalCalculado: (json['costo_total_calculado'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario_id': usuarioId,
      'vehiculo_id': vehiculoId,
      'hora_inicio': Timestamp.fromDate(horaInicio),
      'hora_fin': Timestamp.fromDate(horaFin),
      'costo_total_calculado': costoTotalCalculado,
    };
  }
}
