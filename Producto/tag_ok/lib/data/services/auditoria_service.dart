import 'package:cloud_firestore/cloud_firestore.dart';

/// Escribe trazas en la colección `auditoria` (RF-054 / RNF-006).
///
/// Genérico y transversal a propósito: cualquier módulo que persista un
/// registro capturado o confirmado vía IA (o manualmente) debe dejar traza
/// aquí, no solo Mi Vehículo. No depende de ningún modelo de módulo
/// específico — `tipoEntidad`/`entidadId` son la referencia lógica, igual
/// como está definido en el diccionario de datos.
class AuditoriaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _auditoria =>
      _firestore.collection('auditoria');

  Future<void> registrar({
    String? usuarioId,
    required String accion,
    required String tipoEntidad,
    required String entidadId,
    String? detalle,
    required String origen,
  }) async {
    await _auditoria.add({
      'usuario_id': usuarioId,
      'accion': accion,
      'tipo_entidad': tipoEntidad,
      'entidad_id': entidadId,
      'detalle': detalle,
      'origen': origen,
      'fecha': Timestamp.now(),
    });
  }
}
