import 'package:cloud_firestore/cloud_firestore.dart';

class CruceModel {
  final String id;
  final String porticoId;
  final DateTime timestamp;
  final double costo;

  CruceModel({
    required this.id,
    required this.porticoId,
    required this.timestamp,
    required this.costo,
  });

  factory CruceModel.fromJson(Map<String, dynamic> json, String id) {
    return CruceModel(
      id: id,
      porticoId: json['portico_id'] ?? '',
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      costo: (json['costo'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'portico_id': porticoId,
      'timestamp': Timestamp.fromDate(timestamp),
      'costo': costo,
    };
  }
}
