import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/mantencion_model.dart';
import '../models/tipo_mantencion.dart';

/// CRUD de la colección `mantenciones`.
///
/// Mismo patrón de seguridad que `documentos_vehiculares`: cada mantención
/// guarda el `uid` de su dueño y toda consulta filtra por `uid` (las reglas de
/// Firestore solo dejan leer lo propio) y por `vehiculo_id`. No se guarda
/// ningún archivo: este servicio no usa Firebase Storage.
class MantencionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _mantenciones =>
      _firestore.collection('mantenciones');

  /// UID del usuario con sesión iniciada; se guarda como `uid` en cada
  /// mantención nueva para que las reglas verifiquen el dueño.
  String _uidActual() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Debes iniciar sesión para registrar una mantención.');
    }
    return uid;
  }

  /// Crea una mantención del usuario actual y devuelve su id.
  Future<String> crear({
    required String vehiculoId,
    required EstadoMantencion estado,
    required TipoMantencion tipo,
    String? tipoOtro,
    DateTime? fecha,
    int? kilometraje,
    String? taller,
    int? costo,
    String? descripcion,
    String? observaciones,
    DateTime? proximaFecha,
    int? proximoKilometraje,
    TipoComprobante? tipoComprobante,
    String? numeroComprobante,
    String origenRegistro = 'manual',
    DateTime? fechaCaptura,
    double? confianzaIa,
  }) async {
    String? limpio(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final mantencion = MantencionModel(
      id: '',
      uid: _uidActual(),
      vehiculoId: vehiculoId,
      estado: estado,
      fecha: fecha,
      kilometraje: kilometraje,
      tipo: tipo,
      tipoOtro: tipo == TipoMantencion.otra ? limpio(tipoOtro) : null,
      taller: limpio(taller),
      costo: costo,
      descripcion: limpio(descripcion),
      observaciones: limpio(observaciones),
      proximaFecha: proximaFecha,
      proximoKilometraje: proximoKilometraje,
      tipoComprobante: tipoComprobante,
      numeroComprobante: limpio(numeroComprobante),
      origenRegistro: origenRegistro,
      fechaCaptura: fechaCaptura,
      confianzaIa: confianzaIa,
    );

    final ref = await _mantenciones.add(mantencion.toJson());
    return ref.id;
  }

  /// Mantenciones del usuario para un vehículo, opcionalmente solo de un
  /// estado. Solo usa igualdades (sin orderBy), así que no necesita índice
  /// compuesto; el orden se aplica acá:
  ///  - realizadas: la más reciente primero;
  ///  - programadas: la más próxima primero (las sin fecha, al final).
  Stream<List<MantencionModel>> streamPorVehiculo(
    String vehiculoId, {
    EstadoMantencion? estado,
  }) {
    Query<Map<String, dynamic>> consulta = _mantenciones
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId);
    if (estado != null) {
      consulta = consulta.where('estado', isEqualTo: estado.valorFirestore);
    }

    return consulta.snapshots().map((snapshot) {
      final lista = snapshot.docs
          .map((doc) => MantencionModel.fromJson(doc.data(), doc.id))
          .toList();

      DateTime? clave(MantencionModel m) =>
          m.estado == EstadoMantencion.programada ? m.proximaFecha : m.fecha;

      lista.sort((a, b) {
        final fa = clave(a);
        final fb = clave(b);
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        // Programadas: ascendente. Realizadas: descendente.
        return a.estado == EstadoMantencion.programada
            ? fa.compareTo(fb)
            : fb.compareTo(fa);
      });
      return lista;
    });
  }

  Future<MantencionModel?> obtener(String id) async {
    final doc = await _mantenciones.doc(id).get();
    if (!doc.exists) return null;
    return MantencionModel.fromJson(doc.data()!, doc.id);
  }

  /// Actualiza campos de una mantención propia. `uid`, `vehiculo_id` y los
  /// datos de origen no se pueden cambiar (las reglas también lo impiden).
  /// Las claves son los nombres de campo de Firestore.
  Future<void> actualizar(String id, Map<String, dynamic> cambios) async {
    const editables = {
      'estado',
      'fecha',
      'kilometraje',
      'tipo',
      'tipo_otro',
      'taller',
      'costo',
      'descripcion',
      'observaciones',
      'proxima_fecha',
      'proximo_kilometraje',
      'tipo_comprobante',
      'numero_comprobante',
    };
    final invalidas = cambios.keys.where((k) => !editables.contains(k));
    if (invalidas.isNotEmpty) {
      throw ArgumentError('Campos no editables: ${invalidas.join(', ')}');
    }
    await _mantenciones.doc(id).update(cambios);
  }

  Future<void> eliminar(String id) => _mantenciones.doc(id).delete();

  /// Borra todas las mantenciones de un vehículo. Se usa al eliminar el
  /// vehículo, para no dejar mantenciones huérfanas.
  Future<void> eliminarDeVehiculo(String vehiculoId) async {
    final snapshot = await _mantenciones
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
