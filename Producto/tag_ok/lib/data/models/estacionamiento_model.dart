import 'package:cloud_firestore/cloud_firestore.dart';

/// Estados compartidos por el temporizador y el registro de comprobantes.
enum EstadoEstacionamiento {
  activo('activo', 'En curso'),
  pendienteComprobante('pendienteComprobante', 'Pendiente de comprobante'),
  finalizado('finalizado', 'Finalizado');

  const EstadoEstacionamiento(this.valorFirestore, this.etiqueta);
  final String valorFirestore;
  final String etiqueta;

  static EstadoEstacionamiento fromFirestore(String? valor) {
    for (final estado in EstadoEstacionamiento.values) {
      if (estado.valorFirestore == valor) return estado;
    }
    return EstadoEstacionamiento.finalizado;
  }
}

int duracionEnMinutos(DateTime entrada, DateTime salida) {
  final minutos = salida.difference(entrada).inMinutes;
  return minutos < 0 ? 0 : minutos;
}

const int duracionMaximaMin = 43200;

int duracionParaGuardar(DateTime entrada, DateTime salida) {
  final minutos = duracionEnMinutos(entrada, salida);
  return minutos > duracionMaximaMin ? duracionMaximaMin : minutos;
}

/// Modelo compatible con los campos usados por Jazmin y Estephany.
///
/// IMPORTANTE: las reglas de Firestore y el servicio deben actualizarse antes
/// de escribir estados pendientes o metadatos adicionales de Jazmin.
class EstacionamientoModel {
  final String id;
  final String? uid;
  final String vehiculoId;
  final DateTime fecha;
  final String lugar;
  final DateTime? horaEntrada;
  final DateTime? horaSalida;
  final int? duracionMin;
  final int? costo;
  final GeoPoint? ubicacion;
  final String? observacion;
  final String? direccion;
  final String? nivel;
  final String? sector;
  final double? latitud;
  final double? longitud;
  final EstadoEstacionamiento estado;
  final String origenRegistro;
  final DateTime? fechaCaptura;
  final double? confianzaIa;

  EstacionamientoModel({
    required this.id,
    this.uid,
    required this.vehiculoId,
    DateTime? fecha,
    String? lugar,
    DateTime? fechaEntrada,
    DateTime? fechaSalida,
    DateTime? horaEntrada,
    DateTime? horaSalida,
    this.duracionMin,
    this.costo,
    GeoPoint? ubicacion,
    String? observacion,
    String? observaciones,
    this.direccion,
    this.nivel,
    this.sector,
    double? latitud,
    double? longitud,
    this.estado = EstadoEstacionamiento.finalizado,
    this.origenRegistro = 'manual',
    this.fechaCaptura,
    this.confianzaIa,
  }) : fecha = fecha ?? fechaEntrada ?? horaEntrada ?? DateTime(1970),
       lugar = lugar ?? '',
       horaEntrada = horaEntrada ?? fechaEntrada,
       horaSalida = horaSalida ?? fechaSalida,
       observacion = observacion ?? observaciones,
       ubicacion =
           ubicacion ??
           (latitud != null && longitud != null
               ? GeoPoint(latitud, longitud)
               : null),
       latitud = latitud ?? ubicacion?.latitude,
       longitud = longitud ?? ubicacion?.longitude;

  /// Nombres usados por las pantallas de Jazmin.
  DateTime get fechaEntrada => horaEntrada ?? fecha;
  DateTime? get fechaSalida => horaSalida;
  String? get observaciones => observacion;

  bool get estaActivo => estado == EstadoEstacionamiento.activo;
  bool get pendienteDeComprobante =>
      estado == EstadoEstacionamiento.pendienteComprobante;
  bool get estaFinalizado => estado == EstadoEstacionamiento.finalizado;
  bool get tieneUbicacion => ubicacion != null;

  String get titulo => lugar.trim().isEmpty ? 'Estacionamiento' : lugar.trim();

  Duration get duracion {
    final fin = estaActivo ? DateTime.now() : (horaSalida ?? fechaEntrada);
    final diferencia = fin.difference(fechaEntrada);
    return diferencia.isNegative ? Duration.zero : diferencia;
  }

  int? minutosTranscurridos({DateTime? ahora}) {
    if (estaActivo) {
      final entrada = horaEntrada;
      return entrada == null
          ? null
          : duracionEnMinutos(entrada, ahora ?? DateTime.now());
    }
    if (duracionMin != null) return duracionMin;
    if (horaEntrada != null && horaSalida != null) {
      return duracionEnMinutos(horaEntrada!, horaSalida!);
    }
    return null;
  }

  factory EstacionamientoModel.fromJson(Map<String, dynamic> json, String id) {
    DateTime? leerFecha(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final entrada =
        leerFecha(json['hora_entrada']) ?? leerFecha(json['fecha_entrada']);
    final salida =
        leerFecha(json['hora_salida']) ?? leerFecha(json['fecha_salida']);
    final punto = json['ubicacion'] is GeoPoint
        ? json['ubicacion'] as GeoPoint
        : null;
    final lat = (json['latitud'] as num?)?.toDouble() ?? punto?.latitude;
    final lon = (json['longitud'] as num?)?.toDouble() ?? punto?.longitude;

    return EstacionamientoModel(
      id: id,
      uid: json['uid'] as String?,
      vehiculoId: json['vehiculo_id'] as String? ?? '',
      fecha: leerFecha(json['fecha']) ?? entrada ?? DateTime(1970),
      lugar: json['lugar'] as String?,
      horaEntrada: entrada,
      horaSalida: salida,
      duracionMin: (json['duracion_min'] as num?)?.toInt(),
      costo: (json['costo'] as num?)?.toInt(),
      ubicacion: punto,
      observacion: (json['observacion'] ?? json['observaciones']) as String?,
      direccion: json['direccion'] as String?,
      nivel: json['nivel'] as String?,
      sector: json['sector'] as String?,
      latitud: lat,
      longitud: lon,
      estado: EstadoEstacionamiento.fromFirestore(json['estado'] as String?),
      origenRegistro: json['origen_registro'] as String? ?? 'manual',
      fechaCaptura: leerFecha(json['fecha_captura']),
      confianzaIa: (json['confianza_ia'] as num?)?.toDouble(),
    );
  }

  /// Formato unificado. Requiere reglas Firestore compatibles para escribir
  /// los campos adicionales y el estado pendienteComprobante.
  Map<String, dynamic> toJson() {
    Timestamp? ts(DateTime? value) =>
        value == null ? null : Timestamp.fromDate(value);

    return {
      if (uid != null) 'uid': uid,
      'vehiculo_id': vehiculoId,
      'fecha': Timestamp.fromDate(fecha),
      'lugar': lugar,
      'hora_entrada': ts(horaEntrada),
      'hora_salida': ts(horaSalida),
      'duracion_min': duracionMin,
      'costo': costo,
      'ubicacion': ubicacion,
      'observacion': observacion,
      'estado': estado.valorFirestore,
      'origen_registro': origenRegistro,
      'fecha_captura': ts(fechaCaptura),
      'confianza_ia': confianzaIa,
      if (direccion != null) 'direccion': direccion,
      if (nivel != null) 'nivel': nivel,
      if (sector != null) 'sector': sector,
    };
  }
}
