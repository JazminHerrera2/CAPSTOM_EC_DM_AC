import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de un estacionamiento. Si se agrega uno, hay que actualizar también
/// `estacionamientoValido()` en firestore.rules.
enum EstadoEstacionamiento {
  /// Cronómetro corriendo: tiene hora de entrada y todavía no tiene salida.
  activo('activo', 'En curso'),

  /// Terminado: registrado a mano, con IA o al finalizar el cronómetro. Ya no
  /// se modifica (lo exigen las reglas).
  finalizado('finalizado', 'Finalizado');

  const EstadoEstacionamiento(this.valorFirestore, this.etiqueta);

  /// Valor que se guarda en Firestore.
  final String valorFirestore;

  /// Texto que ve el usuario.
  final String etiqueta;

  static EstadoEstacionamiento fromFirestore(String? valor) {
    return EstadoEstacionamiento.values
            .where((e) => e.valorFirestore == valor)
            .firstOrNull ??
        EstadoEstacionamiento.finalizado;
  }
}

/// Minutos completos entre [entrada] y [salida]. Nunca negativo: si la salida
/// es anterior a la entrada devuelve 0 (las reglas igual rechazan ese caso).
int duracionEnMinutos(DateTime entrada, DateTime salida) {
  final minutos = salida.difference(entrada).inMinutes;
  return minutos < 0 ? 0 : minutos;
}

/// Entidad ESTACIONAMIENTOS (colección `estacionamientos`), RF-016 a RF-022.
///
/// Se crea de tres formas: a mano (ya terminado), con el cronómetro (queda
/// `activo` hasta finalizarlo) o con IA desde el ticket (terminado). Las horas
/// guardan fecha y hora completas, para que el cronómetro sobreviva al cierre
/// de la app y la duración se calcule bien aunque pase la medianoche. No se
/// guarda la foto del ticket, solo los datos.
class EstacionamientoModel {
  final String id;

  /// UID de FirebaseAuth del dueño. Lo asigna el servicio al crear; las reglas
  /// de Firestore verifican que sea el del autor.
  final String? uid;
  final String vehiculoId;
  final DateTime fecha;
  final String? lugar;
  final DateTime? horaEntrada;
  final DateTime? horaSalida;
  final int? duracionMin;

  /// Monto en pesos chilenos (entero).
  final int? costo;

  /// Dónde quedó el vehículo (HU-18). Solo se puede guardar mientras el
  /// estacionamiento está activo, o al registrarlo.
  final GeoPoint? ubicacion;
  final String? observacion;
  final EstadoEstacionamiento estado;

  /// 'manual' o 'ia'.
  final String origenRegistro;
  final DateTime? fechaCaptura;
  final double? confianzaIa;

  const EstacionamientoModel({
    required this.id,
    this.uid,
    required this.vehiculoId,
    required this.fecha,
    this.lugar,
    this.horaEntrada,
    this.horaSalida,
    this.duracionMin,
    this.costo,
    this.ubicacion,
    this.observacion,
    this.estado = EstadoEstacionamiento.finalizado,
    this.origenRegistro = 'manual',
    this.fechaCaptura,
    this.confianzaIa,
  });

  bool get estaActivo => estado == EstadoEstacionamiento.activo;

  bool get tieneUbicacion => ubicacion != null;

  /// Título para el historial: el lugar, o "Estacionamiento" si no hay.
  String get titulo {
    final texto = (lugar ?? '').trim();
    return texto.isNotEmpty ? texto : 'Estacionamiento';
  }

  /// Minutos que lleva o que duró. Si está activo, se cuentan hasta [ahora];
  /// si está finalizado, se usa la duración guardada o se calcula con las
  /// horas. null si no hay datos para saberlo.
  int? minutosTranscurridos({DateTime? ahora}) {
    final entrada = horaEntrada;
    if (estaActivo) {
      return entrada == null
          ? null
          : duracionEnMinutos(entrada, ahora ?? DateTime.now());
    }
    if (duracionMin != null) return duracionMin;
    final salida = horaSalida;
    if (entrada != null && salida != null) {
      return duracionEnMinutos(entrada, salida);
    }
    return null;
  }

  factory EstacionamientoModel.fromJson(Map<String, dynamic> json, String id) {
    DateTime? fechaDe(Object? valor) =>
        valor is Timestamp ? valor.toDate() : null;

    return EstacionamientoModel(
      id: id,
      uid: json['uid'],
      vehiculoId: json['vehiculo_id'] ?? '',
      fecha: fechaDe(json['fecha']) ?? DateTime(1970),
      lugar: json['lugar'],
      horaEntrada: fechaDe(json['hora_entrada']),
      horaSalida: fechaDe(json['hora_salida']),
      duracionMin: (json['duracion_min'] as num?)?.toInt(),
      costo: (json['costo'] as num?)?.toInt(),
      ubicacion: json['ubicacion'] is GeoPoint ? json['ubicacion'] : null,
      observacion: json['observacion'],
      estado: EstadoEstacionamiento.fromFirestore(json['estado']),
      origenRegistro: json['origen_registro'] ?? 'manual',
      fechaCaptura: fechaDe(json['fecha_captura']),
      confianzaIa: (json['confianza_ia'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    Timestamp? ts(DateTime? fecha) =>
        fecha == null ? null : Timestamp.fromDate(fecha);

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
    };
  }
}
