import 'package:cloud_firestore/cloud_firestore.dart';

import 'tipo_mantencion.dart';

/// Una mantención puede estar programada (aún por hacer) o realizada.
enum EstadoMantencion { programada, realizada }

extension EstadoMantencionJson on EstadoMantencion {
  String get valorFirestore =>
      this == EstadoMantencion.programada ? 'programada' : 'realizada';

  static EstadoMantencion fromFirestore(String? valor) {
    return valor == 'programada'
        ? EstadoMantencion.programada
        : EstadoMantencion.realizada;
  }
}

/// Entidad MANTENCIONES (colección `mantenciones`).
///
/// No guarda archivo adjunto (ni foto de boleta o factura): para este módulo
/// solo se conservan los datos extraídos, por decisión del cliente. Por eso no
/// existe `archivo_path` ni se usa Firebase Storage.
class MantencionModel {
  final String id;

  /// UID de FirebaseAuth del dueño. Lo asigna el servicio al crear la
  /// mantención; las reglas de Firestore verifican que sea el del autor.
  final String? uid;
  final String vehiculoId;

  /// 'programada' (usa proxima_fecha / proximo_kilometraje) o 'realizada'
  /// (usa fecha y kilometraje).
  final EstadoMantencion estado;

  final DateTime? fecha;
  final int? kilometraje;
  final TipoMantencion tipo;

  /// Texto libre cuando [tipo] es [TipoMantencion.otra].
  final String? tipoOtro;
  final String? taller;

  /// Monto en pesos chilenos (entero).
  final int? costo;
  final String? descripcion;
  final String? observaciones;
  final DateTime? proximaFecha;
  final int? proximoKilometraje;

  /// 'manual' o 'ia'.
  final String origenRegistro;
  final DateTime? fechaCaptura;
  final double? confianzaIa;

  MantencionModel({
    required this.id,
    this.uid,
    required this.vehiculoId,
    required this.estado,
    this.fecha,
    this.kilometraje,
    required this.tipo,
    this.tipoOtro,
    this.taller,
    this.costo,
    this.descripcion,
    this.observaciones,
    this.proximaFecha,
    this.proximoKilometraje,
    this.origenRegistro = 'manual',
    this.fechaCaptura,
    this.confianzaIa,
  });

  /// Nombre a mostrar: el texto libre cuando el tipo es "Otra".
  String get nombreTipo {
    final otro = tipoOtro?.trim() ?? '';
    return tipo == TipoMantencion.otra && otro.isNotEmpty
        ? otro
        : tipo.etiqueta;
  }

  factory MantencionModel.fromJson(Map<String, dynamic> json, String id) {
    return MantencionModel(
      id: id,
      uid: json['uid'],
      vehiculoId: json['vehiculo_id'] ?? '',
      estado: EstadoMantencionJson.fromFirestore(json['estado']),
      fecha: (json['fecha'] as Timestamp?)?.toDate(),
      kilometraje: (json['kilometraje'] as num?)?.toInt(),
      tipo: TipoMantencion.fromFirestore(json['tipo'] ?? ''),
      tipoOtro: json['tipo_otro'],
      taller: json['taller'],
      costo: (json['costo'] as num?)?.toInt(),
      descripcion: json['descripcion'],
      observaciones: json['observaciones'],
      proximaFecha: (json['proxima_fecha'] as Timestamp?)?.toDate(),
      proximoKilometraje: (json['proximo_kilometraje'] as num?)?.toInt(),
      origenRegistro: json['origen_registro'] ?? 'manual',
      fechaCaptura: (json['fecha_captura'] as Timestamp?)?.toDate(),
      confianzaIa: (json['confianza_ia'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (uid != null) 'uid': uid,
      'vehiculo_id': vehiculoId,
      'estado': estado.valorFirestore,
      'fecha': fecha != null ? Timestamp.fromDate(fecha!) : null,
      'kilometraje': kilometraje,
      'tipo': tipo.valorFirestore,
      'tipo_otro': tipoOtro,
      'taller': taller,
      'costo': costo,
      'descripcion': descripcion,
      'observaciones': observaciones,
      'proxima_fecha':
          proximaFecha != null ? Timestamp.fromDate(proximaFecha!) : null,
      'proximo_kilometraje': proximoKilometraje,
      'origen_registro': origenRegistro,
      'fecha_captura':
          fechaCaptura != null ? Timestamp.fromDate(fechaCaptura!) : null,
      'confianza_ia': confianzaIa,
    };
  }
}
