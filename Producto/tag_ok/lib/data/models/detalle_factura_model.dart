import 'package:cloud_firestore/cloud_firestore.dart';

class DetalleFacturaModel {
  final String id;
  final DateTime fecha;
  final double montoCobrado;
  final String nombreAutopista;
  final String? porticoId; // Puede ser nulo si el OCR no lo reconoce con exactitud

  DetalleFacturaModel({
    required this.id,
    required this.fecha,
    required this.montoCobrado,
    required this.nombreAutopista,
    this.porticoId,
  });

  factory DetalleFacturaModel.fromJson(Map<String, dynamic> json, String id) {
    return DetalleFacturaModel(
      id: id,
      fecha: (json['fecha'] as Timestamp).toDate(),
      montoCobrado: (json['monto_cobrado'] ?? 0.0).toDouble(),
      nombreAutopista: json['nombre_autopista'] ?? '',
      porticoId: json['portico_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha': Timestamp.fromDate(fecha),
      'monto_cobrado': montoCobrado,
      'nombre_autopista': nombreAutopista,
      'portico_id': porticoId,
    };
  }
}
