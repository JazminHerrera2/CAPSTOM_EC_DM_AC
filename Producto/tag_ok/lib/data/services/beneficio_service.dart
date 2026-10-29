import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/beneficio_model.dart';

/// Lectura de la colección `beneficios` (catálogo global). La leen todos los
/// usuarios con sesión; solo la escribe el backoffice (ver firestore.rules).
///
/// No filtra en Firestore: trae el catálogo y la vigencia, el estado activo y
/// los filtros se aplican en cliente con [catalogoParaConductor], así no hace
/// falta ningún índice. Los errores (p. ej. reglas aún no publicadas) se
/// propagan por el stream para que la pantalla muestre un estado de error en
/// vez de romperse.
class BeneficioService {
  final FirebaseFirestore _firestore;

  BeneficioService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _beneficios =>
      _firestore.collection('beneficios');

  /// Todos los beneficios, sin filtrar.
  Stream<List<BeneficioModel>> streamTodos() {
    return _beneficios.snapshots().map(
          (snapshot) => snapshot.docs
              .map((d) => BeneficioModel.fromJson(d.data(), d.id))
              .toList(),
        );
  }

  /// Catálogo del conductor (RF-030, RF-033): activos y vigentes, con los
  /// destacados primero.
  Stream<List<BeneficioModel>> streamCatalogo({
    FiltroBeneficios filtro = const FiltroBeneficios(),
  }) {
    return streamTodos()
        .map((todos) => catalogoParaConductor(todos, filtro: filtro));
  }

  /// Cantidad de beneficios disponibles hoy (RF-047).
  Stream<int> streamCantidadDisponibles() =>
      streamCatalogo().map((lista) => lista.length);
}
