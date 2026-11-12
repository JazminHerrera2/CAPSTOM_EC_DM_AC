import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/abastecimiento_model.dart';
import '../models/mantencion_model.dart';

/// Valores de `tipo_entidad` de los registros que escribe la app.
const String entidadAuditoriaMantencion = 'MANTENCION';
const String entidadAuditoriaAbastecimiento = 'ABASTECIMIENTO';

String _sufijoOrigen(String origen) =>
    origen == 'ia' ? ' con IA (revisada y confirmada por el usuario)' : '';

/// Detalle de auditoría al crear una mantención:
/// "Mantención realizada registrada: Cambio de aceite".
String detalleAuditoriaMantencionCreada({
  required EstadoMantencion estado,
  required String nombre,
  required String origen,
}) {
  final que = estado == EstadoMantencion.realizada
      ? 'Mantención realizada'
      : 'Mantención programada';
  return '$que registrada${_sufijoOrigen(origen)}: $nombre';
}

/// Detalle de auditoría al eliminar una mantención.
String detalleAuditoriaMantencionEliminada({
  required EstadoMantencion estado,
  required String nombre,
}) {
  final que = estado == EstadoMantencion.realizada
      ? 'Mantención realizada'
      : 'Mantención programada';
  return '$que eliminada: $nombre';
}

/// Detalle de auditoría al crear una carga:
/// "Carga de combustible registrada con IA (...)".
String detalleAuditoriaAbastecimientoCreado({
  required TipoAbastecimiento tipo,
  required String origen,
}) {
  final que = tipo == TipoAbastecimiento.cargaElectrica
      ? 'Carga eléctrica'
      : 'Carga de combustible';
  return '$que registrada${_sufijoOrigen(origen)}';
}

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

  /// Igual que [registrar], pero si falla solo lo informa en consola. Se usa
  /// después de guardar un registro: el registro ya quedó guardado y no debe
  /// mostrarse como fallido (el usuario lo reintentaría y quedaría duplicado).
  Future<void> registrarSinInterrumpir({
    required String accion,
    required String tipoEntidad,
    required String entidadId,
    String? detalle,
    required String origen,
  }) async {
    try {
      await registrar(
        accion: accion,
        tipoEntidad: tipoEntidad,
        entidadId: entidadId,
        detalle: detalle,
        origen: origen,
      );
    } catch (e) {
      debugPrint('No se pudo auditar $accion $tipoEntidad $entidadId: $e');
    }
  }
}
