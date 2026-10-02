import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehiculo_model.dart';

/// CRUD de la colección `vehiculos` — compartida entre Fase 1
/// (`vehiculos_screen.dart`) y Fase 2 (módulo Mi Vehículo). Ver
/// `docs/07-desviaciones-diccionario-datos.md` para el detalle de por qué
/// `id_usuario` se mantiene como DocumentReference en vez de un `usuario_id`
/// string, y por qué `categoria`/`tipo_vehiculo` coexisten sin fusionarse.
class VehiculoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _vehiculos =>
      _firestore.collection('vehiculos');

  /// CU1 — Registrar vehículo.
  Future<String> registrarVehiculo({
    required String usuarioId,
    required String patente,
    String? marca,
    String? modelo,
    int? anio,
    String? tipoVehiculo,
    String? tipoCombustible,
    int? kilometrajeActual,
    String? alias,
  }) async {
    final idUsuario = _firestore.collection('usuarios').doc(usuarioId);

    final vehiculo = VehiculoModel(
      id: '',
      idUsuario: idUsuario,
      patente: patente,
      marca: marca,
      modelo: modelo,
      anio: anio,
      tipoVehiculo: tipoVehiculo,
      tipoCombustible: tipoCombustible,
      kilometrajeActual: kilometrajeActual,
      alias: alias,
      estado: 'activo',
    );

    final docRef = await _vehiculos.add(vehiculo.toJson());
    return docRef.id;
  }
  
  /// CU2 — Modificar información (kilometraje, alias, foto).
  Future<void> actualizarVehiculo(
    String vehiculoId, {
    int? kilometrajeActual,
    String? alias,
    String? fotoPath,
  }) async {
    final cambios = <String, dynamic>{};
    if (kilometrajeActual != null) {
      cambios['kilometraje_actual'] = kilometrajeActual;
    }
    if (alias != null) cambios['alias'] = alias;
    if (fotoPath != null) cambios['foto_path'] = fotoPath;

    if (cambios.isEmpty) return;
    await _vehiculos.doc(vehiculoId).update(cambios);
  }

  Future<VehiculoModel?> obtenerVehiculo(String vehiculoId) async {
    final doc = await _vehiculos.doc(vehiculoId).get();
    if (!doc.exists) return null;
    return VehiculoModel.fromJson(doc.data()!, doc.id);
  }

  /// CU5 (parte de datos) — vehículos del usuario para calcular su estado.
  Stream<List<VehiculoModel>> streamVehiculosUsuario(String usuarioId) {
    final idUsuario = _firestore.collection('usuarios').doc(usuarioId);
    return _vehiculos
        .where('id_usuario', isEqualTo: idUsuario)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => VehiculoModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }
}
