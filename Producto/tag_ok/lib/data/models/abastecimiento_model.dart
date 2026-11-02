import 'package:cloud_firestore/cloud_firestore.dart';

/// Qué se cargó: combustible líquido/gas (litros) o energía de un vehículo
/// eléctrico o híbrido enchufable (kWh). Deja lista la estructura para
/// vehículos híbridos y eléctricos: cada registro lleva su propio tipo y
/// unidad, así un híbrido puede mezclar cargas de ambos.
///
/// Si se agrega un tipo, hay que actualizar también `abastecimientoValido()` en
/// firestore.rules.
enum TipoAbastecimiento {
  combustible('combustible', 'Combustible', 'L'),
  cargaElectrica('carga_electrica', 'Carga eléctrica', 'kWh');

  const TipoAbastecimiento(this.valorFirestore, this.etiqueta, this.unidad);

  /// Valor que se guarda en Firestore.
  final String valorFirestore;

  /// Texto que ve el usuario.
  final String etiqueta;

  /// Unidad de la cantidad cargada.
  final String unidad;

  static TipoAbastecimiento fromFirestore(String? valor) {
    return TipoAbastecimiento.values
            .where((t) => t.valorFirestore == valor)
            .firstOrNull ??
        TipoAbastecimiento.combustible;
  }
}

/// Combustibles que se ofrecen al registrar una carga (texto que ve el usuario
/// y que se guarda en `tipo_combustible`).
const List<String> combustiblesDeCarga = [
  'Gasolina 93',
  'Gasolina 95',
  'Gasolina 97',
  'Diésel',
  'Gas licuado (GLP)',
];

/// Valor de `tipo_combustible` de una carga eléctrica.
const String combustibleElectrico = 'Eléctrico';

/// Entidad ABASTECIMIENTOS (colección `abastecimientos`): una carga de
/// combustible o de energía eléctrica de un vehículo.
///
/// Todo es opcional salvo la fecha: el usuario no está obligado a completar
/// los campos que no necesita. Como en Mantenciones, no se guarda la imagen de
/// la boleta, solo los datos extraídos.
class AbastecimientoModel {
  final String id;

  /// UID de FirebaseAuth del dueño. Lo asigna el servicio al crear la carga;
  /// las reglas de Firestore verifican que sea el del autor.
  final String? uid;
  final String vehiculoId;
  final DateTime fecha;
  final int? kilometraje;
  final String? estacionServicio;
  final TipoAbastecimiento tipoAbastecimiento;

  /// "Gasolina 95", "Diésel", "Eléctrico"... Texto libre de hasta 40 caracteres.
  final String? tipoCombustible;

  /// Litros o kWh, según [tipoAbastecimiento].
  final double? cantidad;
  final double? precioUnitario;

  /// Monto total en pesos chilenos (entero).
  final int? total;

  /// 'manual' o 'ia'.
  final String origenRegistro;
  final DateTime? fechaCaptura;
  final double? confianzaIa;

  const AbastecimientoModel({
    required this.id,
    this.uid,
    required this.vehiculoId,
    required this.fecha,
    this.kilometraje,
    this.estacionServicio,
    this.tipoAbastecimiento = TipoAbastecimiento.combustible,
    this.tipoCombustible,
    this.cantidad,
    this.precioUnitario,
    this.total,
    this.origenRegistro = 'manual',
    this.fechaCaptura,
    this.confianzaIa,
  });

  String get unidad => tipoAbastecimiento.unidad;

  /// Título para el historial: la estación, o el tipo de carga si no hay.
  String get titulo {
    final estacion = (estacionServicio ?? '').trim();
    return estacion.isNotEmpty ? estacion : tipoAbastecimiento.etiqueta;
  }

  factory AbastecimientoModel.fromJson(Map<String, dynamic> json, String id) {
    return AbastecimientoModel(
      id: id,
      uid: json['uid'],
      vehiculoId: json['vehiculo_id'] ?? '',
      fecha: (json['fecha'] as Timestamp?)?.toDate() ?? DateTime(1970),
      kilometraje: (json['kilometraje'] as num?)?.toInt(),
      estacionServicio: json['estacion_servicio'],
      tipoAbastecimiento: TipoAbastecimiento.fromFirestore(
        json['tipo_abastecimiento'],
      ),
      tipoCombustible: json['tipo_combustible'],
      cantidad: (json['cantidad'] as num?)?.toDouble(),
      precioUnitario: (json['precio_unitario'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toInt(),
      origenRegistro: json['origen_registro'] ?? 'manual',
      fechaCaptura: (json['fecha_captura'] as Timestamp?)?.toDate(),
      confianzaIa: (json['confianza_ia'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (uid != null) 'uid': uid,
      'vehiculo_id': vehiculoId,
      'fecha': Timestamp.fromDate(fecha),
      'kilometraje': kilometraje,
      'estacion_servicio': estacionServicio,
      'tipo_abastecimiento': tipoAbastecimiento.valorFirestore,
      'tipo_combustible': tipoCombustible,
      'cantidad': cantidad,
      'unidad': unidad,
      'precio_unitario': precioUnitario,
      'total': total,
      'origen_registro': origenRegistro,
      'fecha_captura': fechaCaptura != null
          ? Timestamp.fromDate(fechaCaptura!)
          : null,
      'confianza_ia': confianzaIa,
    };
  }
}
