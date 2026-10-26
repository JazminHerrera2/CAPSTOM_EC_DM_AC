import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/titulo_mantencion.dart';

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

/// Intervalo por defecto entre mantenciones: un año desde la última.
DateTime proximaMantencionAnual(DateTime ultima) {
  // Un 29 de febrero pasa al 28 del año siguiente (no al 1 de marzo).
  final dia = (ultima.month == 2 && ultima.day == 29) ? 28 : ultima.day;
  return DateTime(ultima.year + 1, ultima.month, dia);
}

/// Tipo del comprobante de pago de una mantención (campo `tipo_comprobante`).
///
/// Si se agrega o renombra un tipo, hay que actualizar también la lista de
/// `mantencionValida()` en firestore.rules.
enum TipoComprobante {
  boleta('boleta', 'Boleta'),
  factura('factura', 'Factura'),
  otro('otro', 'Otro');

  const TipoComprobante(this.valorFirestore, this.etiqueta);

  /// Valor que se guarda en Firestore.
  final String valorFirestore;

  /// Texto que ve el usuario.
  final String etiqueta;

  static TipoComprobante? fromFirestore(String? valor) {
    return TipoComprobante.values
        .where((t) => t.valorFirestore == valor)
        .firstOrNull;
  }

  static TipoComprobante? fromEtiqueta(String? etiqueta) {
    return TipoComprobante.values
        .where((t) => t.etiqueta == etiqueta)
        .firstOrNull;
  }
}

/// Entidad MANTENCIONES (colección `mantenciones`).
///
/// No guarda archivo adjunto (ni foto de boleta o factura): para este módulo
/// solo se conservan los datos extraídos, por decisión del cliente. Por eso no
/// existe `archivo_path` ni se usa Firebase Storage. Como "documento asociado"
/// del historial (RF-010) se guarda solo la referencia del comprobante:
/// `tipo_comprobante` y `numero_comprobante`.
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

  /// Título de la mantención, en texto libre ("Cambio de aceite"). Las
  /// anteriores guardan un valor de la lista antigua (`cambio_aceite`...):
  /// [nombreTipo] lo traduce al leerlo.
  final String tipo;

  /// Solo en mantenciones antiguas con tipo `otra`; las nuevas no lo usan.
  final String? tipoOtro;
  final String? taller;

  /// Monto en pesos chilenos (entero).
  final int? costo;
  final String? descripcion;
  final String? observaciones;
  final DateTime? proximaFecha;
  final int? proximoKilometraje;

  /// Referencia del comprobante de pago (sin la imagen). Ambos opcionales.
  final TipoComprobante? tipoComprobante;
  final String? numeroComprobante;

  /// Ids de `componentes_mantencion` revisados en esta mantención (marcados
  /// por la IA o a mano).
  final List<String> componentes;

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
    this.tipoComprobante,
    this.numeroComprobante,
    this.componentes = const [],
    this.origenRegistro = 'manual',
    this.fechaCaptura,
    this.confianzaIa,
  });

  /// Título a mostrar. Nunca queda vacío.
  String get nombreTipo => tituloMantencion(tipo, tipoOtro: tipoOtro);

  /// Texto del comprobante para el historial ("Boleta N° 458123"), o null si
  /// no se registró ninguno.
  String? get referenciaComprobante {
    final numero = numeroComprobante?.trim() ?? '';
    if (tipoComprobante == null) {
      return numero.isEmpty ? null : 'Comprobante N° $numero';
    }
    return numero.isEmpty
        ? tipoComprobante!.etiqueta
        : '${tipoComprobante!.etiqueta} N° $numero';
  }

  factory MantencionModel.fromJson(Map<String, dynamic> json, String id) {
    return MantencionModel(
      id: id,
      uid: json['uid'],
      vehiculoId: json['vehiculo_id'] ?? '',
      estado: EstadoMantencionJson.fromFirestore(json['estado']),
      fecha: (json['fecha'] as Timestamp?)?.toDate(),
      kilometraje: (json['kilometraje'] as num?)?.toInt(),
      tipo: json['tipo']?.toString() ?? '',
      tipoOtro: json['tipo_otro'],
      taller: json['taller'],
      costo: (json['costo'] as num?)?.toInt(),
      descripcion: json['descripcion'],
      observaciones: json['observaciones'],
      proximaFecha: (json['proxima_fecha'] as Timestamp?)?.toDate(),
      proximoKilometraje: (json['proximo_kilometraje'] as num?)?.toInt(),
      tipoComprobante: TipoComprobante.fromFirestore(json['tipo_comprobante']),
      numeroComprobante: json['numero_comprobante'],
      componentes: (json['componentes'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
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
      'tipo': tipo,
      'tipo_otro': tipoOtro,
      'taller': taller,
      'costo': costo,
      'descripcion': descripcion,
      'observaciones': observaciones,
      'proxima_fecha':
          proximaFecha != null ? Timestamp.fromDate(proximaFecha!) : null,
      'proximo_kilometraje': proximoKilometraje,
      'tipo_comprobante': tipoComprobante?.valorFirestore,
      'numero_comprobante': numeroComprobante,
      'componentes': componentes,
      'origen_registro': origenRegistro,
      'fecha_captura':
          fechaCaptura != null ? Timestamp.fromDate(fechaCaptura!) : null,
      'confianza_ia': confianzaIa,
    };
  }
}
