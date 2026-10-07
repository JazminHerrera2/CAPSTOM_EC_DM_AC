import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/vehiculo_model.dart';
import 'auditoria_service.dart';
import 'documento_vehicular_service.dart';
import 'storage_service.dart';

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
      fechaRegistro: DateTime.now(),
    );

    final docRef = await _vehiculos.add(vehiculo.toJson());
    return docRef.id;
  }
  
  /// CU2 — Modificar información (marca, modelo, año, combustible, kilometraje, alias, foto).
  Future<void> actualizarVehiculo(
    String vehiculoId, {
    String? marca,
    String? modelo,
    int? anio,
    String? tipoCombustible,
    int? kilometrajeActual,
    String? alias,
    String? fotoPath,
    bool quitarFoto = false,
  }) async {
    final cambios = <String, dynamic>{};
    if (marca != null) cambios['marca'] = marca;
    if (modelo != null) cambios['modelo'] = modelo;
    if (anio != null) cambios['anio'] = anio;
    if (tipoCombustible != null) cambios['tipo_combustible'] = tipoCombustible;
    if (kilometrajeActual != null) {
      cambios['kilometraje_actual'] = kilometrajeActual;
    }
    if (alias != null) cambios['alias'] = alias;
    if (fotoPath != null) cambios['foto_path'] = fotoPath;
    if (quitarFoto && fotoPath == null) {
      cambios['foto_path'] = FieldValue.delete();
    }

    if (cambios.isEmpty) return;
    await _vehiculos.doc(vehiculoId).update(cambios);
  }

  /// Elimina el vehículo junto con sus documentos (y avisos y archivos de
  /// éstos). Primero se borran los documentos: si algo falla, el vehículo
  /// sigue existiendo y se puede reintentar sin dejar datos huérfanos.
  Future<void> eliminarVehiculo(String vehiculoId) async {
    final datos = (await _vehiculos.doc(vehiculoId).get()).data();
    final patente = datos?['patente'];
    final fotoPath = datos?['foto_path'];
    final idUsuario = datos?['id_usuario'];

    await DocumentoVehicularService().eliminarDocumentosDeVehiculo(vehiculoId);
    await _vehiculos.doc(vehiculoId).delete();

    // Si era el vehículo principal del usuario, ese dato deja de apuntar a él.
    if (patente is String && idUsuario is DocumentReference) {
      try {
        final usuario = await idUsuario.get();
        final data = usuario.data() as Map<String, dynamic>?;
        if (data?['vehiculo_principal_id'] == patente) {
          await idUsuario.update({
            'vehiculo_principal_id': FieldValue.delete(),
          });
        }
      } catch (e) {
        debugPrint('No se pudo limpiar el vehículo principal: $e');
      }
    }

    if (fotoPath is String &&
        fotoPath.trim().isNotEmpty &&
        StorageService.configurado) {
      try {
        await StorageService().eliminarArchivo(fotoPath.trim());
      } catch (e) {
        debugPrint('No se pudo eliminar la foto $fotoPath: $e');
      }
    }

    await AuditoriaService().registrar(
      usuarioId: null,
      accion: 'ELIMINAR',
      tipoEntidad: 'VEHICULO',
      entidadId: vehiculoId,
      detalle: 'Vehículo eliminado${patente != null ? ' ($patente)' : ''}',
      origen: 'manual',
    );
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
