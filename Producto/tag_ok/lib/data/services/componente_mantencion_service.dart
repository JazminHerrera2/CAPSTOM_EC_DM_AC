import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/componente_mantencion_model.dart';

/// Colección `componentes_mantencion`: la leen todos los usuarios con sesión y
/// solo la escriben los administradores (ver firestore.rules). Si la colección
/// está vacía o no se puede leer, se usan [componentesPorDefecto].
class ComponenteMantencionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _componentes =>
      _firestore.collection('componentes_mantencion');

  /// Componentes activos ordenados. Ordena acá para no pedir un índice.
  Stream<List<ComponenteMantencion>> streamActivos() {
    return _componentes.snapshots().map((snapshot) {
      final lista = snapshot.docs
          .map((d) => ComponenteMantencion.fromJson(d.data(), d.id))
          .where((c) => c.activo)
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      return lista.isEmpty ? componentesPorDefecto : lista;
    }).handleError((Object e) {
      debugPrint('No se pudieron leer los componentes de mantención: $e');
    });
  }

  /// Componentes activos, una sola vez (con el mismo respaldo).
  Future<List<ComponenteMantencion>> obtenerActivos() async {
    try {
      return await streamActivos().first;
    } catch (_) {
      return componentesPorDefecto;
    }
  }

  // --- Administración (solo admins; las reglas lo hacen cumplir) -----------

  Future<void> guardar(ComponenteMantencion c) =>
      _componentes.doc(c.id).set(c.toJson());

  Future<void> eliminar(String id) => _componentes.doc(id).delete();

  /// Crea los componentes iniciales sin pisar los que ya existan.
  Future<void> sembrarPorDefecto() async {
    final batch = _firestore.batch();
    for (final c in componentesPorDefecto) {
      final ref = _componentes.doc(c.id);
      if (!(await ref.get()).exists) batch.set(ref, c.toJson());
    }
    await batch.commit();
  }
}
