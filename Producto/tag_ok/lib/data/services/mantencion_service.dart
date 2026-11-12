import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/mantencion_model.dart';
import 'auditoria_service.dart';
import 'notificacion_service.dart';
import 'vehiculo_service.dart';

/// CRUD de la colección `mantenciones`.
///
/// Mismo patrón de seguridad que `documentos_vehiculares`: cada mantención
/// guarda el `uid` de su dueño y toda consulta filtra por `uid` (las reglas de
/// Firestore solo dejan leer lo propio) y por `vehiculo_id`. No se guarda
/// ningún archivo: este servicio no usa Firebase Storage.
///
/// Las mantenciones programadas generan recordatorios (RF-012) en
/// `notificaciones`: por fecha (7 días antes y el día) y por kilometraje
/// (cerca y alcanzado, HU-11/HU-48). Este servicio los crea, actualiza y borra
/// junto con la mantención. Las realizadas con kilometraje actualizan el km
/// del vehículo. Crear y eliminar dejan registro en `auditoria` (RF-054).
class MantencionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificacionService _notificacionService = NotificacionService();
  final AuditoriaService _auditoriaService = AuditoriaService();

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
    required String tipo,
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
    List<String> componentes = const [],
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
            taller: limpio(taller),
      costo: costo,
      descripcion: limpio(descripcion),
      observaciones: limpio(observaciones),
      proximaFecha: proximaFecha,
      proximoKilometraje: proximoKilometraje,
      tipoComprobante: tipoComprobante,
      numeroComprobante: limpio(numeroComprobante),
      componentes: componentes,
      origenRegistro: origenRegistro,
      fechaCaptura: fechaCaptura,
      confianzaIa: confianzaIa,
    );

    final ref = await _mantenciones.add(mantencion.toJson());
    // RF-054: queda la traza de quién la registró, cuándo y si vino de la IA.
    await _auditoriaService.registrarSinInterrumpir(
      accion: 'CREAR',
      tipoEntidad: entidadAuditoriaMantencion,
      entidadId: ref.id,
      detalle: detalleAuditoriaMantencionCreada(
        estado: estado,
        nombre: mantencion.nombreTipo,
        origen: origenRegistro,
      ),
      origen: origenRegistro,
    );
    if (estado == EstadoMantencion.programada &&
        (proximaFecha != null || proximoKilometraje != null)) {
      await _sincronizarRecordatorios(
        MantencionModel.fromJson(mantencion.toJson(), ref.id),
      );
    }
    // Una mantención hecha trae el km del auto en ese momento: el vehículo
    // queda con el último km conocido (no falla si no se puede).
    if (estado == EstadoMantencion.realizada) {
      await VehiculoService().actualizarKilometrajeSiEsMayor(
        vehiculoId,
        kilometraje,
      );
    }
    return ref.id;
  }

  /// Deja los recordatorios de [m] acordes a su estado. Si está programada:
  ///  - con fecha, los avisos por fecha se crean o reprograman;
  ///  - con kilometraje, los avisos por km se rehacen (el km o el nombre
  ///    pudieron cambiar) y se crea el que ya corresponda según el km actual
  ///    del vehículo.
  /// Lo que no aplica se borra. Es "best effort": si falla, la mantención
  /// queda guardada igual y el error va a consola.
  Future<void> _sincronizarRecordatorios(MantencionModel m) async {
    final programada = m.estado == EstadoMantencion.programada;
    try {
      final fecha = m.proximaFecha;
      if (programada && fecha != null) {
        await _notificacionService.configurarRecordatoriosMantencion(
          vehiculoId: m.vehiculoId,
          mantencionId: m.id,
          nombreMantencion: m.nombreTipo,
          proximaFecha: fecha,
        );
      } else {
        await _notificacionService.eliminarRecordatoriosFechaMantencion(m.id);
      }
    } catch (e) {
      debugPrint('No se pudieron actualizar los recordatorios de ${m.id}: $e');
    }

    try {
      await _notificacionService.eliminarAvisosKilometrajeMantencion(m.id);
      final km = m.proximoKilometraje;
      if (programada && km != null) {
        await _notificacionService.configurarAvisoKilometrajeMantencion(
          vehiculoId: m.vehiculoId,
          mantencionId: m.id,
          nombreMantencion: m.nombreTipo,
          proximoKilometraje: km,
        );
      }
    } catch (e) {
      debugPrint('No se pudieron actualizar los avisos por km de ${m.id}: $e');
    }
  }

  /// Revisa las mantenciones programadas por kilometraje del vehículo con su
  /// nuevo [kilometraje] y crea los avisos que correspondan (cerca o
  /// alcanzado; los que ya existen no se repiten). Lo llama
  /// `VehiculoService` cada vez que cambia el km del vehículo. Es "best
  /// effort": un error solo va a consola.
  Future<void> revisarAvisosKilometraje(
    String vehiculoId,
    int kilometraje,
  ) async {
    try {
      final snapshot = await _mantenciones
          .where('uid', isEqualTo: _uidActual())
          .where('vehiculo_id', isEqualTo: vehiculoId)
          .where('estado', isEqualTo: EstadoMantencion.programada.valorFirestore)
          .get();
      for (final doc in snapshot.docs) {
        final m = MantencionModel.fromJson(doc.data(), doc.id);
        final km = m.proximoKilometraje;
        if (km == null) continue;
        try {
          await _notificacionService.configurarAvisoKilometrajeMantencion(
            vehiculoId: vehiculoId,
            mantencionId: m.id,
            nombreMantencion: m.nombreTipo,
            proximoKilometraje: km,
            kilometrajeActual: kilometraje,
          );
        } catch (e) {
          debugPrint('No se pudo crear el aviso por km de ${m.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('No se pudieron revisar los avisos por km de $vehiculoId: $e');
    }
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
      'componentes',
    };
    final invalidas = cambios.keys.where((k) => !editables.contains(k));
    if (invalidas.isNotEmpty) {
      throw ArgumentError('Campos no editables: ${invalidas.join(', ')}');
    }
    await _mantenciones.doc(id).update(cambios);

    // Cambió la fecha, el km, el estado o el nombre: los recordatorios se
    // rehacen.
    const afectanRecordatorios = {
      'estado',
      'proxima_fecha',
      'proximo_kilometraje',
      'tipo',
      'tipo_otro',
    };
    if (cambios.keys.any(afectanRecordatorios.contains)) {
      final actualizada = await obtener(id);
      if (actualizada != null) await _sincronizarRecordatorios(actualizada);
    }
  }

  /// Borra la mantención y sus recordatorios, y lo deja en `auditoria`.
  Future<void> eliminar(String id) async {
    final mantencion = await obtener(id);
    await _notificacionService.eliminarRecordatoriosMantencion(id);
    await _mantenciones.doc(id).delete();
    await _auditoriaService.registrarSinInterrumpir(
      accion: 'ELIMINAR',
      tipoEntidad: entidadAuditoriaMantencion,
      entidadId: id,
      detalle: mantencion == null
          ? 'Mantención eliminada'
          : detalleAuditoriaMantencionEliminada(
              estado: mantencion.estado,
              nombre: mantencion.nombreTipo,
            ),
      origen: 'manual',
    );
  }

  /// Borra todas las mantenciones de un vehículo (y los recordatorios de las
  /// programadas). Se usa al eliminar el vehículo, para no dejar mantenciones
  /// ni avisos huérfanos.
  Future<void> eliminarDeVehiculo(String vehiculoId) async {
    final snapshot = await _mantenciones
        .where('uid', isEqualTo: _uidActual())
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .get();
    for (final doc in snapshot.docs) {
      if (doc.data()['estado'] == EstadoMantencion.programada.valorFirestore) {
        await _notificacionService.eliminarRecordatoriosMantencion(doc.id);
      }
      await doc.reference.delete();
    }
  }
}
