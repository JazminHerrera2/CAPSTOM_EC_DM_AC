import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      // Si el llamador no lo indica, se usa el usuario con sesión iniciada:
      // las reglas de Firestore exigen que usuario_id sea el uid del autor.
      'usuario_id': usuarioId ?? FirebaseAuth.instance.currentUser?.uid,
      'accion': accion,
      'tipo_entidad': tipoEntidad,
      'entidad_id': entidadId,
      'detalle': detalle,
      'origen': origen,
      'fecha': Timestamp.now(),
    });
  }
}
