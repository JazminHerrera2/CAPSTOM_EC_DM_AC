import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/estacionamiento_model.dart';

/// Operaciones de la colección `estacionamientos` (RF-016 a RF-022). Las
/// pantallas del módulo solo llaman a este servicio; acá está todo lo que toca
/// Firestore.
///
/// Mismo patrón de seguridad que `mantenciones` y `abastecimientos`: cada
/// registro guarda el `uid` de su dueño y toda consulta filtra por `uid` y por
/// `vehiculo_id`. Lo que hace cada función calza con las reglas publicadas
/// (`estacionamientoValido()` en firestore.rules):
/// - un estacionamiento `activo` tiene hora de entrada y no de salida;
/// - solo se modifica mientras está activo;
/// - al finalizarlo se exige la hora de salida;
/// - uno finalizado ya no se modifica.
class EstacionamientoService {
  EstacionamientoService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _estacionamientos =>
      _firestore.collection('estacionamientos');

  String _uidActual() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Debes iniciar sesión para registrar un estacionamiento.');
    }
    return uid;
  }

  static String? _limpio(String? valor) {
    final t = valor?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// HU-15 (y HU-21 con IA): registra un estacionamiento ya terminado y
  /// devuelve su id. Si vienen las dos horas, la duración se calcula con
  /// ellas; si no, se usa [duracionMin] cuando se conoce (por ejemplo, un
  /// ticket de parquímetro que solo dice "60 min"). Siempre con tope de 30
  /// días.
  Future<String> registrarManual({
    required String vehiculoId,
    required DateTime fecha,
    String? lugar,
    DateTime? horaEntrada,
    DateTime? horaSalida,
    int? duracionMin,
    int? costo,
    String? observacion,
    GeoPoint? ubicacion,
    String origenRegistro = 'manual',
    DateTime? fechaCaptura,
    double? confianzaIa,
  }) async {
    if (horaEntrada != null &&
        horaSalida != null &&
        horaSalida.isBefore(horaEntrada)) {
      throw ArgumentError('La hora de salida no puede ser anterior a la de entrada.');
    }

    final estacionamiento = EstacionamientoModel(
      id: '',
      uid: _uidActual(),
      vehiculoId: vehiculoId,
      fecha: fecha,
      lugar: _limpio(lugar),
      horaEntrada: horaEntrada,
      horaSalida: horaSalida,
      duracionMin: horaEntrada != null && horaSalida != null
          ? duracionParaGuardar(horaEntrada, horaSalida)
          : duracionMin?.clamp(0, duracionMaximaMin),
      costo: costo,
      ubicacion: ubicacion,
      observacion: _limpio(observacion),
      estado: EstadoEstacionamiento.finalizado,
      origenRegistro: origenRegistro,
      fechaCaptura: fechaCaptura,
      confianzaIa: confianzaIa,
    );
    final ref = await _estacionamientos.add(estacionamiento.toJson());
    return ref.id;
  }

  /// HU-16: inicia el cronómetro. Guarda la fecha y hora de entrada y deja el
  /// estacionamiento `activo`. Si el vehículo ya tiene uno activo, no crea otro
  /// (las reglas no pueden impedirlo, así que se controla acá).
  Future<String> iniciar({
    required String vehiculoId,
    String? lugar,
    DateTime? ahora,
  }) async {
    if (await obtenerActivo(vehiculoId) != null) {
      throw StateError(
        'Este vehículo ya tiene un estacionamiento en curso. Finalízalo antes '
        'de iniciar otro.',
      );
    }
    final inicio = ahora ?? DateTime.now();
    final estacionamiento = EstacionamientoModel(
      id: '',
      uid: _uidActual(),
      vehiculoId: vehiculoId,
      fecha: inicio,
      lugar: _limpio(lugar),
      horaEntrada: inicio,
      estado: EstadoEstacionamiento.activo,
    );
    final ref = await _estacionamientos.add(estacionamiento.toJson());
    return ref.id;
  }

  /// Lee un estacionamiento y comprueba que siga activo. Si no, lanza un error
  /// con un mensaje para el usuario.
  Future<EstacionamientoModel> _activoPorId(String id) async {
    final doc = await _estacionamientos.doc(id).get();
    final datos = doc.data();
    if (datos == null) {
      throw StateError('El estacionamiento ya no existe.');
    }
    final estacionamiento = EstacionamientoModel.fromJson(datos, doc.id);
    if (!estacionamiento.estaActivo) {
      throw StateError('El estacionamiento ya fue finalizado y no se puede modificar.');
    }
    return estacionamiento;
  }

  /// HU-17: finaliza el cronómetro. Guarda la hora de salida, calcula la
  /// duración y, si se indica, el costo.
  Future<void> finalizar(String id, {int? costo, DateTime? ahora}) async {
    final estacionamiento = await _activoPorId(id);
    final entrada = estacionamiento.horaEntrada ?? ahora ?? DateTime.now();
    // Si el reloj del dispositivo quedó atrás de la entrada, se usa la
    // entrada: las reglas rechazan una salida anterior a la entrada.
    final propuesta = ahora ?? DateTime.now();
    final salida = propuesta.isBefore(entrada) ? entrada : propuesta;
    await _estacionamientos.doc(id).update({
      'estado': EstadoEstacionamiento.finalizado.valorFirestore,
      'hora_salida': Timestamp.fromDate(salida),
      // Con tope de 30 días: si no, las reglas rechazarían el finalizar.
      'duracion_min': duracionParaGuardar(entrada, salida),
      'costo': ?costo,
    });
  }

  /// HU-18: guarda dónde quedó el vehículo. Se llama cuando el usuario
  /// presiona "Guardar ubicación". Solo se puede mientras el estacionamiento
  /// está activo (después ya no se modifica).
  Future<void> guardarUbicacion(String id, GeoPoint ubicacion) async {
    await _activoPorId(id);
    await _estacionamientos.doc(id).update({'ubicacion': ubicacion});
  }

  /// El estacionamiento en curso del vehículo, o null si no hay.
  Future<EstacionamientoModel?> obtenerActivo(String vehiculoId) async {
    final snapshot = await _consultaActivo(vehiculoId).get();
    return _primeroActivo(snapshot);
  }

  /// Igual que [obtenerActivo], pero se actualiza solo: sirve para mostrar el
  /// cronómetro y el botón "Ver dónde está mi auto".
  Stream<EstacionamientoModel?> streamActivo(String vehiculoId) {
    return _consultaActivo(vehiculoId).snapshots().map(_primeroActivo);
  }

  Query<Map<String, dynamic>> _consultaActivo(String vehiculoId) {
    // Solo igualdades: no necesita índice compuesto.
    return _estacionamientos
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .where('estado', isEqualTo: EstadoEstacionamiento.activo.valorFirestore);
  }

  /// Si por algún motivo hubiera más de uno activo, toma el más reciente.
  static EstacionamientoModel? _primeroActivo(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final activos = snapshot.docs
        .map((d) => EstacionamientoModel.fromJson(d.data(), d.id))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return activos.firstOrNull;
  }

  /// Estacionamientos del vehículo, el más reciente primero. Solo usa
  /// igualdades (sin orderBy), así que no necesita índice compuesto; el orden
  /// se aplica acá.
  Stream<List<EstacionamientoModel>> streamPorVehiculo(String vehiculoId) {
    return _estacionamientos
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((d) => EstacionamientoModel.fromJson(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha)));
  }

  Future<void> eliminar(String id) => _estacionamientos.doc(id).delete();

  /// Borra todos los estacionamientos de un vehículo. Se usa al eliminar el
  /// vehículo, para no dejar registros huérfanos.
  Future<void> eliminarDeVehiculo(String vehiculoId) async {
    final snapshot = await _estacionamientos
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
