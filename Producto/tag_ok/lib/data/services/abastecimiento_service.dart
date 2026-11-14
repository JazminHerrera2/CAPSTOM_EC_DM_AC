import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/abastecimiento_model.dart';
import 'auditoria_service.dart';
import 'vehiculo_service.dart';

/// CRUD de la colección `abastecimientos` (Combustible y carga).
///
/// Mismo patrón de seguridad que `mantenciones`: cada carga guarda el `uid` de
/// su dueño y toda consulta filtra por `uid` y por `vehiculo_id`. No se guarda
/// ningún archivo: este servicio no usa Firebase Storage. Una carga con
/// kilometraje actualiza el km del vehículo, y cada carga nueva deja registro
/// en `auditoria` (RF-054).
class AbastecimientoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _abastecimientos =>
      _firestore.collection('abastecimientos');

  String _uidActual() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Debes iniciar sesión para registrar una carga.');
    }
    return uid;
  }

  /// Crea una carga del usuario actual y devuelve su id.
  Future<String> crear({
    required String vehiculoId,
    required DateTime fecha,
    TipoAbastecimiento tipoAbastecimiento = TipoAbastecimiento.combustible,
    int? kilometraje,
    String? estacionServicio,
    String? tipoCombustible,
    double? cantidad,
    double? precioUnitario,
    int? total,
    String origenRegistro = 'manual',
    DateTime? fechaCaptura,
    double? confianzaIa,
  }) async {
    String? limpio(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final abastecimiento = AbastecimientoModel(
      id: '',
      uid: _uidActual(),
      vehiculoId: vehiculoId,
      fecha: fecha,
      kilometraje: kilometraje,
      estacionServicio: limpio(estacionServicio),
      tipoAbastecimiento: tipoAbastecimiento,
      tipoCombustible: limpio(tipoCombustible),
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      total: total,
      origenRegistro: origenRegistro,
      fechaCaptura: fechaCaptura,
      confianzaIa: confianzaIa,
    );

    final ref = await _abastecimientos.add(abastecimiento.toJson());
    // RF-054: queda la traza de quién la registró, cuándo y si vino de la IA.
    await AuditoriaService().registrarSinInterrumpir(
      accion: 'CREAR',
      tipoEntidad: entidadAuditoriaAbastecimiento,
      entidadId: ref.id,
      detalle: detalleAuditoriaAbastecimientoCreado(
        tipo: tipoAbastecimiento,
        origen: origenRegistro,
      ),
      origen: origenRegistro,
    );
    // El vehículo queda con el último km conocido (no falla si no se puede).
    await VehiculoService().actualizarKilometrajeSiEsMayor(
      vehiculoId,
      kilometraje,
    );
    return ref.id;
  }

  /// Cargas del usuario para un vehículo, la más reciente primero. Solo usa
  /// igualdades (sin orderBy), así que no necesita índice compuesto; el orden
  /// se aplica acá.
  Stream<List<AbastecimientoModel>> streamPorVehiculo(String vehiculoId) {
    return _abastecimientos
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .snapshots()
        .map((snapshot) {
          final lista =
              snapshot.docs
                  .map(
                    (doc) => AbastecimientoModel.fromJson(doc.data(), doc.id),
                  )
                  .toList()
                ..sort((a, b) => b.fecha.compareTo(a.fecha));
          return lista;
        });
  }

  Future<void> eliminar(String id) => _abastecimientos.doc(id).delete();

  /// Borra todas las cargas de un vehículo. Se usa al eliminar el vehículo,
  /// para no dejar registros huérfanos.
  Future<void> eliminarDeVehiculo(String vehiculoId) async {
    final snapshot = await _abastecimientos
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
