import 'package:cloud_firestore/cloud_firestore.dart';

class UsuarioModel {
  final String uid;
  final String email;
  final String? nombreMostrar;
  final DateTime fechaCreacion;
  final String? vehiculoPrincipalId;
  final double limitePresupuestoMensual;

  UsuarioModel({
    required this.uid,
    required this.email,
    this.nombreMostrar,
    required this.fechaCreacion,
    this.vehiculoPrincipalId,
    this.limitePresupuestoMensual = 0.0,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json, String id) {
    return UsuarioModel(
      uid: id,
      email: json['email'] ?? '',
      nombreMostrar: json['nombre_mostrar'],
      fechaCreacion: (json['fecha_creacion'] as Timestamp).toDate(),
      vehiculoPrincipalId: json['vehiculo_principal_id'],
      limitePresupuestoMensual: (json['limite_presupuesto_mensual'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'nombre_mostrar': nombreMostrar,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'vehiculo_principal_id': vehiculoPrincipalId,
      'limite_presupuesto_mensual': limitePresupuestoMensual,
    };
  }
}
