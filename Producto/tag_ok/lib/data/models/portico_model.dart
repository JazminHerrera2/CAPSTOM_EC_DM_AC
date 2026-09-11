import 'package:cloud_firestore/cloud_firestore.dart';

class PorticoModel {
  final String id;
  final String nombre;
  final GeoPoint ubicacion;
  final String nombreAutopista;

  PorticoModel({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.nombreAutopista,
  });

  factory PorticoModel.fromJson(Map<String, dynamic> json, String id) {
    return PorticoModel(
      id: id,
      nombre: json['nombre'] ?? '',
      ubicacion: json['ubicacion'] as GeoPoint,
      nombreAutopista: json['nombre_autopista'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'ubicacion': ubicacion,
      'nombre_autopista': nombreAutopista,
    };
  }
}
