
import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado actual del estacionamiento.
enum EstadoEstacionamiento {
  activo,
  pendienteComprobante,
  finalizado;

  static EstadoEstacionamiento fromFirestore(String? valor) {
    switch (valor) {
      case 'activo':
        return EstadoEstacionamiento.activo;
      case 'pendienteComprobante':
        return EstadoEstacionamiento.pendienteComprobante;
      case 'finalizado':
        return EstadoEstacionamiento.finalizado;
      default:
        return EstadoEstacionamiento.finalizado;
    }
  }
}

/// Registro de un estacionamiento asociado a un vehículo.
class EstacionamientoModel {
  final String id;
  final String? uid;
  final String vehiculoId;

  final String lugar;
  final String? direccion;
  final String? nivel;
  final String? sector;

  final DateTime fechaEntrada;
  final DateTime? fechaSalida;

  final int? costo;
  final String? observaciones;

  final double? latitud;
  final double? longitud;

  final EstadoEstacionamiento estado;

  /// 'manual', 'ia' o 'cronometro'.
  final String origenRegistro;

  final DateTime? fechaCaptura;
  final double? confianzaIa;

  const EstacionamientoModel({
    required this.id,
    this.uid,
    required this.vehiculoId,
    required this.lugar,
    this.direccion,
    this.nivel,
    this.sector,
    required this.fechaEntrada,
    this.fechaSalida,
    this.costo,
    this.observaciones,
    this.latitud,
    this.longitud,
    this.estado = EstadoEstacionamiento.finalizado,
    this.origenRegistro = 'manual',
    this.fechaCaptura,
    this.confianzaIa,
  });

  /// Duración calculada a partir de las fechas.
  /// Si está activo, utiliza la hora actual.
  Duration get duracion {
  final DateTime fin;

  if (estado == EstadoEstacionamiento.activo) {
    fin = DateTime.now();
  } else {
    fin = fechaSalida ?? fechaEntrada;
  }

  final diferencia = fin.difference(fechaEntrada);

  return diferencia.isNegative ? Duration.zero : diferencia;
}

  bool get estaActivo => estado == EstadoEstacionamiento.activo;

  bool get pendienteDeComprobante =>
    estado == EstadoEstacionamiento.pendienteComprobante;

  bool get estaFinalizado =>
    estado == EstadoEstacionamiento.finalizado;

  factory EstacionamientoModel.fromJson(
    Map<String, dynamic> json,
    String id,
  ) {
    return EstacionamientoModel(
      id: id,
      uid: json['uid'] as String?,
      vehiculoId: json['vehiculo_id'] as String? ?? '',
      lugar: json['lugar'] as String? ?? '',
      direccion: json['direccion'] as String?,
      nivel: json['nivel'] as String?,
      sector: json['sector'] as String?,
      fechaEntrada:
          (json['fecha_entrada'] as Timestamp?)?.toDate() ??
          DateTime(1970),
      fechaSalida:
          (json['fecha_salida'] as Timestamp?)?.toDate(),
      costo: (json['costo'] as num?)?.toInt(),
      observaciones: json['observaciones'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      estado: EstadoEstacionamiento.fromFirestore(
        json['estado'] as String?,
      ),
      origenRegistro:
          json['origen_registro'] as String? ?? 'manual',
      fechaCaptura:
          (json['fecha_captura'] as Timestamp?)?.toDate(),
      confianzaIa:
          (json['confianza_ia'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (uid != null) 'uid': uid,
      'vehiculo_id': vehiculoId,
      'lugar': lugar,
      'direccion': direccion,
      'nivel': nivel,
      'sector': sector,
      'fecha_entrada': Timestamp.fromDate(fechaEntrada),
      'fecha_salida': fechaSalida != null
          ? Timestamp.fromDate(fechaSalida!)
          : null,
      'costo': costo,
      'observaciones': observaciones,
      'latitud': latitud,
      'longitud': longitud,
      'estado': estado.name,
      'origen_registro': origenRegistro,
      'fecha_captura': fechaCaptura != null
          ? Timestamp.fromDate(fechaCaptura!)
          : null,
      'confianza_ia': confianzaIa,
    };
  }
}
