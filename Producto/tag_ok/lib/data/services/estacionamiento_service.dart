import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/estacionamiento_model.dart';

/// Servicio de Firestore para el módulo Estacionamientos.
/// Cada registro pertenece a un usuario y a uno de sus vehículos.
class EstacionamientoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _estacionamientos =>
      _firestore.collection('estacionamientos');

  String _uidActual() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Debes iniciar sesión para registrar un estacionamiento.');
    }
    return uid;
  }

  String? _limpiar(String? valor) {
    final texto = valor?.trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  /// Crea un registro manual, histórico o activo.
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
    if (vehiculoId.trim().isEmpty) {
      throw ArgumentError('Debes seleccionar un vehículo.');
    }
    if (lugar.trim().isEmpty) {
      throw ArgumentError('Debes ingresar un lugar.');
    }
    if (fechaSalida != null && fechaSalida.isBefore(fechaEntrada)) {
      throw ArgumentError('La fecha de salida no puede ser anterior a la entrada.');
    }
    if (costo != null && costo < 0) {
      throw ArgumentError('El costo no puede ser negativo.');
    }
    if (estado == EstadoEstacionamiento.activo && fechaSalida != null) {
      throw ArgumentError('Un estacionamiento activo no puede tener fecha de salida.');
    }
    if (estado == EstadoEstacionamiento.pendienteComprobante &&
        fechaSalida == null) {
      throw ArgumentError('Un estacionamiento detenido debe tener fecha de salida.');
    }

    final estacionamiento = EstacionamientoModel(
      id: '',
      uid: _uidActual(),
      vehiculoId: vehiculoId.trim(),
      lugar: lugar.trim(),
      direccion: _limpiar(direccion),
      nivel: _limpiar(nivel),
      sector: _limpiar(sector),
      fechaEntrada: fechaEntrada,
      fechaSalida: fechaSalida,
      costo: costo,
      observaciones: _limpiar(observaciones),
      latitud: latitud,
      longitud: longitud,
      estado: estado,
      origenRegistro: origenRegistro,
      fechaCaptura: fechaCaptura,
      confianzaIa: confianzaIa,
    );

    final referencia = await _estacionamientos.add(estacionamiento.toJson());
    return referencia.id;
  }

  /// Inicia el cronómetro para el vehículo seleccionado.
  /// Una transacción impide dos inicios simultáneos desde este método.
  Future<String> iniciar({
    required String vehiculoId,
    required String lugar,
    required DateTime fechaEntrada,
    String? direccion,
    String? nivel,
    String? sector,
    String? observaciones,
    double? latitud,
    double? longitud,
  }) async {
    final uid = _uidActual();
    if (vehiculoId.trim().isEmpty || lugar.trim().isEmpty) {
      throw ArgumentError('Debes seleccionar un vehículo e ingresar un lugar.');
    }
    if (fechaEntrada.isAfter(DateTime.now())) {
      throw ArgumentError('La fecha de entrada no puede estar en el futuro.');
    }

    // Documento de control por usuario y vehículo. Su lectura y escritura
    // deben estar permitidas en las reglas de Firestore.
    final controlId = '${uid}_${vehiculoId.trim()}';
    final controlRef = _firestore.collection('estacionamientos_activos').doc(controlId);
    final nuevoRef = _estacionamientos.doc();

    await _firestore.runTransaction((transaction) async {
      final control = await transaction.get(controlRef);
      final idActivo = control.data()?['estacionamiento_id'] as String?;
      if (idActivo != null && idActivo.isNotEmpty) {
        throw StateError('Este vehículo ya tiene un estacionamiento en curso.');
      }

      final registro = EstacionamientoModel(
        id: nuevoRef.id,
        uid: uid,
        vehiculoId: vehiculoId.trim(),
        lugar: lugar.trim(),
        direccion: _limpiar(direccion),
        nivel: _limpiar(nivel),
        sector: _limpiar(sector),
        fechaEntrada: fechaEntrada,
        estado: EstadoEstacionamiento.activo,
        origenRegistro: 'cronometro',
        observaciones: _limpiar(observaciones),
        latitud: latitud,
        longitud: longitud,
      );
      transaction.set(nuevoRef, registro.toJson());
      transaction.set(controlRef, {
        'uid': uid,
        'vehiculo_id': vehiculoId.trim(),
        'estacionamiento_id': nuevoRef.id,
      });
    });
    return nuevoRef.id;
  }

  /// Obtiene registros del usuario para un vehículo, más recientes primero.
  Stream<List<EstacionamientoModel>> streamPorVehiculo(String vehiculoId) {
    return _estacionamientos
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .snapshots()
        .map((snapshot) {
      final lista = snapshot.docs
          .map((doc) => EstacionamientoModel.fromJson(doc.data(), doc.id))
          .toList();
      lista.sort((a, b) => b.fechaEntrada.compareTo(a.fechaEntrada));
      return lista;
    });
  }

  /// Detiene el tiempo y deja pendiente el registro del comprobante.
  /// Se conserva `costo` como parámetro opcional por compatibilidad,
  /// pero no se guarda aquí: el pago se registra en otro paso.
  Future<void> finalizar({
    required String estacionamientoId,
    required DateTime fechaSalida,
    int? costo,
  }) async {
    if (costo != null && costo < 0) {
      throw ArgumentError('El costo no puede ser negativo.');
    }
    final referencia = _estacionamientos.doc(estacionamientoId);
    final uid = _uidActual();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(referencia);
      if (!snapshot.exists) {
        throw StateError('El estacionamiento no existe.');
      }
      final datos = snapshot.data()!;
      if (datos['uid'] != uid) {
        throw StateError('No tienes permiso para finalizar este estacionamiento.');
      }
      if (datos['estado'] != EstadoEstacionamiento.activo.name) {
        throw StateError('Este estacionamiento no está en curso.');
      }
      final entrada = (datos['fecha_entrada'] as Timestamp).toDate();
      if (fechaSalida.isBefore(entrada)) {
        throw ArgumentError('La salida no puede ser anterior a la entrada.');
      }

      final vehiculoId = datos['vehiculo_id'] as String;
      final controlRef = _firestore
          .collection('estacionamientos_activos')
          .doc('${uid}_$vehiculoId');
      final control = await transaction.get(controlRef);
      if (control.exists &&
          control.data()?['estacionamiento_id'] == estacionamientoId) {
        transaction.delete(controlRef);
      }
      transaction.update(referencia, {
        'estado': EstadoEstacionamiento.pendienteComprobante.name,
        'fecha_salida': Timestamp.fromDate(fechaSalida),
      });
    });
  }

  /// Completa el registro del pago sin crear otro estacionamiento.
  /// `costo` puede ser cero si el estacionamiento fue gratuito.
  Future<void> registrarComprobante({
    required String estacionamientoId,
    required int costo,
    required String origenRegistro,
    DateTime? fechaCaptura,
    double? confianzaIa,
  }) async {
    if (costo < 0) {
      throw ArgumentError('El costo no puede ser negativo.');
    }
    if (!{'manual', 'ia'}.contains(origenRegistro)) {
      throw ArgumentError('El origen del comprobante debe ser manual o ia.');
    }
    final referencia = _estacionamientos.doc(estacionamientoId);
    final uid = _uidActual();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(referencia);
      if (!snapshot.exists) {
        throw StateError('El estacionamiento no existe.');
      }
      final datos = snapshot.data()!;
      if (datos['uid'] != uid) {
        throw StateError('No tienes permiso para registrar este comprobante.');
      }
      if (datos['estado'] != EstadoEstacionamiento.pendienteComprobante.name) {
        throw StateError('Primero debes detener el tiempo del estacionamiento.');
      }
      transaction.update(referencia, {
        'estado': EstadoEstacionamiento.finalizado.name,
        'costo': costo,
        'origen_comprobante': origenRegistro,
        'fecha_captura': fechaCaptura == null
            ? null
            : Timestamp.fromDate(fechaCaptura),
        'confianza_ia': confianzaIa,
      });
    });
  }

  /// Elimina un estacionamiento del usuario actual.
  Future<void> eliminar(String id) async {
    final referencia = _estacionamientos.doc(id);
    final uid = _uidActual();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(referencia);
      if (!snapshot.exists) return;
      final datos = snapshot.data()!;
      if (datos['uid'] != uid) {
        throw StateError('No tienes permiso para eliminar este estacionamiento.');
      }
      if (datos['estado'] == EstadoEstacionamiento.activo.name) {
        final vehiculoId = datos['vehiculo_id'] as String;
        final controlRef = _firestore
            .collection('estacionamientos_activos')
            .doc('${uid}_$vehiculoId');
        final control = await transaction.get(controlRef);
        if (control.exists && control.data()?['estacionamiento_id'] == id) {
          transaction.delete(controlRef);
        }
      }
      transaction.delete(referencia);
    });
  }

  /// Elimina registros de un vehículo. El lote evita borrados parciales
  /// dentro de cada grupo de hasta 200 registros.
  Future<void> eliminarDeVehiculo(String vehiculoId) async {
    final uid = _uidActual();
    final snapshot = await _estacionamientos
        .where('uid', isEqualTo: uid)
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .get();

    final controlRef = _firestore
        .collection('estacionamientos_activos')
        .doc('${uid}_$vehiculoId');
    for (var inicio = 0; inicio < snapshot.docs.length; inicio += 200) {
      final batch = _firestore.batch();
      final fin = inicio + 200 < snapshot.docs.length
          ? inicio + 200
          : snapshot.docs.length;
      for (final documento in snapshot.docs.sublist(inicio, fin)) {
        batch.delete(documento.reference);
      }
      await batch.commit();
    }
    await controlRef.delete();
  }
}
