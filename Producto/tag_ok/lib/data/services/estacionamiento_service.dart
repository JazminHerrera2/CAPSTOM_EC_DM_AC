import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/estacionamiento_model.dart';

/// Integra el flujo de comprobantes de Jazmin con el registro histórico,
/// ubicación y consultas de Estephany.
/// IMPORTANTE: requiere reglas Firestore actualizadas antes de usarse en línea.
class EstacionamientoService {
  EstacionamientoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _registros =>
      _firestore.collection('estacionamientos');
  CollectionReference<Map<String, dynamic>> get _controles =>
      _firestore.collection('estacionamientos_activos');

  String _uid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'Debes iniciar sesión para registrar un estacionamiento.',
      );
    }
    return uid;
  }

  static String? _limpio(String? valor) {
    final texto = valor?.trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  static void _validarCosto(int? costo) {
    if (costo != null && (costo < 0 || costo > 10000000)) {
      throw ArgumentError('El costo debe estar entre 0 y 10.000.000.');
    }
  }

  DocumentReference<Map<String, dynamic>> _control(
    String uid,
    String vehiculoId,
  ) => _controles.doc('${uid}_$vehiculoId');

  /// Registro histórico o manual, compatible con Jazmin.
  Future<String> crear({
    required String vehiculoId,
    required String lugar,
    required DateTime fechaEntrada,
    DateTime? fechaSalida,
    String? direccion,
    String? nivel,
    String? sector,
    int? costo,
    String? observaciones,
    double? latitud,
    double? longitud,
    EstadoEstacionamiento estado = EstadoEstacionamiento.finalizado,
    String origenRegistro = 'manual',
    DateTime? fechaCaptura,
    double? confianzaIa,
  }) async {
    if (vehiculoId.trim().isEmpty || lugar.trim().isEmpty) {
      throw ArgumentError('Debes indicar vehículo y lugar.');
    }
    if (estado == EstadoEstacionamiento.activo) {
      throw ArgumentError('Para iniciar el cronómetro usa iniciar().');
    }
    if (fechaSalida != null && fechaSalida.isBefore(fechaEntrada)) {
      throw ArgumentError('La salida no puede ser anterior a la entrada.');
    }
    if (estado == EstadoEstacionamiento.pendienteComprobante &&
        fechaSalida == null) {
      throw ArgumentError(
        'Un estacionamiento detenido necesita hora de salida.',
      );
    }
    _validarCosto(costo);
    final modelo = EstacionamientoModel(
      id: '',
      uid: _uid(),
      vehiculoId: vehiculoId.trim(),
      lugar: lugar.trim(),
      fechaEntrada: fechaEntrada,
      fechaSalida: fechaSalida,
      direccion: _limpio(direccion),
      nivel: _limpio(nivel),
      sector: _limpio(sector),
      costo: costo,
      observaciones: _limpio(observaciones),
      latitud: latitud,
      longitud: longitud,
      estado: estado,
      origenRegistro: origenRegistro,
      fechaCaptura: fechaCaptura,
      confianzaIa: confianzaIa,
      duracionMin: fechaSalida == null
          ? null
          : duracionParaGuardar(fechaEntrada, fechaSalida),
    );
    return (await _registros.add(modelo.toJson())).id;
  }

  /// Registro de ticket histórico o IA, compatible con Estephany.
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
    if (vehiculoId.trim().isEmpty)
      throw ArgumentError('Debes seleccionar un vehículo.');
    if (horaEntrada != null &&
        horaSalida != null &&
        horaSalida.isBefore(horaEntrada)) {
      throw ArgumentError('La salida no puede ser anterior a la entrada.');
    }
    _validarCosto(costo);
    final modelo = EstacionamientoModel(
      id: '',
      uid: _uid(),
      vehiculoId: vehiculoId.trim(),
      fecha: fecha,
      lugar: _limpio(lugar),
      horaEntrada: horaEntrada,
      horaSalida: horaSalida,
      duracionMin: horaEntrada != null && horaSalida != null
          ? duracionParaGuardar(horaEntrada, horaSalida)
          : duracionMin?.clamp(0, duracionMaximaMin).toInt(),
      costo: costo,
      observacion: _limpio(observacion),
      ubicacion: ubicacion,
      estado: EstadoEstacionamiento.finalizado,
      origenRegistro: origenRegistro,
      fechaCaptura: fechaCaptura,
      confianzaIa: confianzaIa,
    );
    return (await _registros.add(modelo.toJson())).id;
  }

  /// Inicia el cronómetro con los argumentos de ambas pantallas.
  /// El documento de control evita dos inicios concurrentes por vehículo.
  Future<String> iniciar({
    required String vehiculoId,
    String? lugar,
    DateTime? fechaEntrada,
    DateTime? ahora,
    String? direccion,
    String? nivel,
    String? sector,
    String? observaciones,
    double? latitud,
    double? longitud,
  }) async {
    final uid = _uid();
    final vehiculo = vehiculoId.trim();
    if (vehiculo.isEmpty) throw ArgumentError('Debes seleccionar un vehículo.');
    final entrada = fechaEntrada ?? ahora ?? DateTime.now();
    if (entrada.isAfter(DateTime.now())) {
      throw ArgumentError('La fecha de entrada no puede estar en el futuro.');
    }
    final control = _control(uid, vehiculo);
    final nuevo = _registros.doc();
    await _firestore.runTransaction((tx) async {
      final existente = await tx.get(control);
      if (existente.exists) {
        throw StateError('Este vehículo ya tiene un estacionamiento en curso.');
      }
      final modelo = EstacionamientoModel(
        id: nuevo.id,
        uid: uid,
        vehiculoId: vehiculo,
        fechaEntrada: entrada,
        lugar: _limpio(lugar),
        direccion: _limpio(direccion),
        nivel: _limpio(nivel),
        sector: _limpio(sector),
        observaciones: _limpio(observaciones),
        latitud: latitud,
        longitud: longitud,
        estado: EstadoEstacionamiento.activo,
        origenRegistro: 'manual',
      );
      tx.set(nuevo, modelo.toJson());
      tx.set(control, {
        'uid': uid,
        'vehiculo_id': vehiculo,
        'estacionamiento_id': nuevo.id,
      });
    });
    return nuevo.id;
  }

  Query<Map<String, dynamic>> _consultaVehiculo(String vehiculoId) => _registros
      .where('uid', isEqualTo: _uid())
      .where('vehiculo_id', isEqualTo: vehiculoId);

  Query<Map<String, dynamic>> _consultaActivos(String vehiculoId) =>
      _consultaVehiculo(
        vehiculoId,
      ).where('estado', isEqualTo: EstadoEstacionamiento.activo.valorFirestore);

  static EstacionamientoModel? _primeroActivo(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final lista =
        snapshot.docs
            .map((d) => EstacionamientoModel.fromJson(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista.isEmpty ? null : lista.first;
  }

  Future<EstacionamientoModel?> obtenerActivo(String vehiculoId) async =>
      _primeroActivo(await _consultaActivos(vehiculoId).get());

  Stream<EstacionamientoModel?> streamActivo(String vehiculoId) =>
      _consultaActivos(vehiculoId).snapshots().map(_primeroActivo);

  Stream<List<EstacionamientoModel>> streamPorVehiculo(String vehiculoId) =>
      _consultaVehiculo(vehiculoId).snapshots().map((snapshot) {
        final lista = snapshot.docs
            .map((d) => EstacionamientoModel.fromJson(d.data(), d.id))
            .toList();
        lista.sort((a, b) => b.fechaEntrada.compareTo(a.fechaEntrada));
        return lista;
      });

  /// Detiene el temporizador y deja el pago pendiente (flujo Jazmin).
  Future<void> finalizar({
    required String estacionamientoId,
    required DateTime fechaSalida,
    int? costo,
  }) => _cerrar(
    estacionamientoId,
    fechaSalida,
    EstadoEstacionamiento.pendienteComprobante,
    costo: costo,
  );

  /// Cierre directo con costo opcional (flujo Estephany).
  /// Su pantalla debe llamar a este método en lugar de finalizar(id, ...).
  Future<void> finalizarDirectamente(
    String id, {
    int? costo,
    DateTime? ahora,
  }) => _cerrar(
    id,
    ahora ?? DateTime.now(),
    EstadoEstacionamiento.finalizado,
    costo: costo,
  );

  Future<void> _cerrar(
    String id,
    DateTime salida,
    EstadoEstacionamiento destino, {
    int? costo,
  }) async {
    _validarCosto(costo);
    final uid = _uid();
    final ref = _registros.doc(id);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final datos = doc.data();
      if (datos == null) throw StateError('El estacionamiento no existe.');
      if (datos['uid'] != uid)
        throw StateError('No tienes permiso para finalizarlo.');
      if (datos['estado'] != EstadoEstacionamiento.activo.valorFirestore) {
        throw StateError('El estacionamiento no está en curso.');
      }
      final entradaValor = datos['hora_entrada'] ?? datos['fecha_entrada'];
      if (entradaValor is! Timestamp)
        throw StateError('Falta la hora de entrada.');
      final entrada = entradaValor.toDate();
      if (salida.isBefore(entrada)) {
        throw ArgumentError('La salida no puede ser anterior a la entrada.');
      }
      final vehiculo = datos['vehiculo_id'] as String;
      final control = _control(uid, vehiculo);
      final docControl = await tx.get(control);
      if (docControl.exists && docControl.data()?['estacionamiento_id'] == id) {
        tx.delete(control);
      }
      tx.update(ref, {
        'estado': destino.valorFirestore,
        'hora_salida': Timestamp.fromDate(salida),
        'duracion_min': duracionParaGuardar(entrada, salida),
        if (destino == EstadoEstacionamiento.finalizado && costo != null)
          'costo': costo,
      });
    });
  }

  Future<void> registrarComprobante({
    required String estacionamientoId,
    required int costo,
    required String origenRegistro,
    DateTime? fechaCaptura,
    double? confianzaIa,
  }) async {
    _validarCosto(costo);
    if (origenRegistro != 'manual' && origenRegistro != 'ia') {
      throw ArgumentError('El origen del comprobante debe ser manual o ia.');
    }
    final uid = _uid();
    final ref = _registros.doc(estacionamientoId);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final datos = doc.data();
      if (datos == null) throw StateError('El estacionamiento no existe.');
      if (datos['uid'] != uid)
        throw StateError('No tienes permiso para modificarlo.');
      if (datos['estado'] !=
          EstadoEstacionamiento.pendienteComprobante.valorFirestore) {
        throw StateError('Primero debes detener el temporizador.');
      }
      tx.update(ref, {
        'estado': EstadoEstacionamiento.finalizado.valorFirestore,
        'costo': costo,
        'origen_comprobante': origenRegistro,
        'fecha_captura': fechaCaptura == null
            ? null
            : Timestamp.fromDate(fechaCaptura),
        'confianza_ia': confianzaIa,
      });
    });
  }

  Future<void> guardarUbicacion(String id, GeoPoint ubicacion) async {
    final doc = await _registros.doc(id).get();
    final datos = doc.data();
    if (datos == null ||
        datos['uid'] != _uid() ||
        datos['estado'] != EstadoEstacionamiento.activo.valorFirestore) {
      throw StateError(
        'Solo puedes guardar la ubicación de tu estacionamiento activo.',
      );
    }
    await doc.reference.update({'ubicacion': ubicacion});
  }

  Future<void> eliminar(String id) async {
    final uid = _uid();
    final ref = _registros.doc(id);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final datos = doc.data();
      if (datos == null) return;
      if (datos['uid'] != uid)
        throw StateError('No tienes permiso para eliminarlo.');
      if (datos['estado'] == EstadoEstacionamiento.activo.valorFirestore) {
        final control = _control(uid, datos['vehiculo_id'] as String);
        final docControl = await tx.get(control);
        if (docControl.exists &&
            docControl.data()?['estacionamiento_id'] == id) {
          tx.delete(control);
        }
      }
      tx.delete(ref);
    });
  }

  Future<void> eliminarDeVehiculo(String vehiculoId) async {
    final uid = _uid();
    final docs = await _consultaVehiculo(vehiculoId).get();
    final control = _control(uid, vehiculoId);
    for (var inicio = 0; inicio < docs.docs.length; inicio += 200) {
      final batch = _firestore.batch();
      final fin = (inicio + 200 < docs.docs.length)
          ? inicio + 200
          : docs.docs.length;
      for (final doc in docs.docs.sublist(inicio, fin)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await control.delete();
  }
}
