import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/documento_vehicular_model.dart';
import 'auditoria_service.dart';
import 'notificacion_service.dart';
import 'storage_service.dart';

/// CRUD de la colección `documentos_vehiculares` (CU3, CU4, CU6, CU7, CU39).
class DocumentoVehicularService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditoriaService _auditoriaService = AuditoriaService();
  final NotificacionService _notificacionService = NotificacionService();
  final StorageService _storageService = StorageService();

  CollectionReference<Map<String, dynamic>> get _documentos =>
      _firestore.collection('documentos_vehiculares');

  /// Documentos ya registrados del mismo tipo para el vehículo. Debe llamarse
  /// ANTES de crear el nuevo, para no incluirlo.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _buscarAnteriores(
    String vehiculoId,
    TipoDocumentoVehicular tipo,
  ) async {
    final snapshot = await _documentos
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .where('tipo_documento', isEqualTo: tipo.valorFirestore)
        .get();
    return snapshot.docs;
  }

  /// Un vehículo tiene un solo documento vigente por tipo: al registrar uno
  /// nuevo se borran los anteriores (registro, avisos de vencimiento y
  /// archivo). Ocurre DESPUÉS de guardar el nuevo, así un fallo de red nunca
  /// deja al vehículo sin documento. Es "best effort": si algo del borrado
  /// falla se registra en consola y el documento nuevo queda guardado igual.
  Future<void> _eliminarReemplazados(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> anteriores, {
    required String nuevoId,
    required String? nuevoArchivoPath,
  }) async {
    for (final anterior in anteriores) {
      if (anterior.id == nuevoId) continue;

      try {
        await _notificacionService.eliminarNotificacionesDocumento(anterior.id);
        await anterior.reference.delete();
        await _auditoriaService.registrar(
          usuarioId: null,
          accion: 'ELIMINAR',
          tipoEntidad: 'DOCUMENTO_VEHICULAR',
          entidadId: anterior.id,
          detalle: 'Documento reemplazado por uno nuevo ($nuevoId)',
          origen: 'sistema',
        );
      } catch (e) {
        debugPrint('No se pudo eliminar el documento anterior ${anterior.id}: $e');
        continue;
      }

      final archivoAnterior = anterior.data()['archivo_path'];
      if (archivoAnterior is String &&
          archivoAnterior.trim().isNotEmpty &&
          archivoAnterior != nuevoArchivoPath &&
          StorageService.configurado) {
        try {
          await _storageService.eliminarArchivo(archivoAnterior.trim());
        } catch (e) {
          debugPrint('No se pudo eliminar el archivo anterior $archivoAnterior: $e');
        }
      }
    }
  }

  /// CU3 / CU40 — registro manual (sin IA) de un documento.
  Future<String> crearDocumentoManual(DocumentoVehicularModel documento) async {
    final anteriores = await _buscarAnteriores(
      documento.vehiculoId,
      documento.tipoDocumento,
    );
    final docRef = await _documentos.add(documento.toJson());
    await _eliminarReemplazados(
      anteriores,
      nuevoId: docRef.id,
      nuevoArchivoPath: documento.archivoPath,
    );

    await _auditoriaService.registrar(
      usuarioId: null,
      accion: 'CREAR',
      tipoEntidad: 'DOCUMENTO_VEHICULAR',
      entidadId: docRef.id,
      detalle: 'Documento registrado manualmente',
      origen: 'manual',
    );

    if (documento.fechaVencimiento != null) {
      await _notificacionService.configurarNotificacionesVencimiento(
        vehiculoId: documento.vehiculoId,
        documentoId: docRef.id,
        nombreDocumento: documento.tipoDocumento.etiqueta,
        fechaVencimiento: documento.fechaVencimiento!,
      );
    }

    return docRef.id;
  }

  /// CU7 / CU39 — persiste el resultado ya revisado y confirmado por el
  /// conductor de un documento capturado con Registro Inteligente. La
  /// confirmación explícita (RNF-004/RNF-005) debe haber ocurrido antes de
  /// llamar a este método — este servicio no la valida, solo persiste.
  Future<String> confirmarDesdeIA({
    required String vehiculoId,
    required TipoDocumentoVehicular tipoDocumento,
    String? numero,
    DateTime? fechaEmision,
    DateTime? fechaVencimiento,
    String? compania,
    String? numeroPoliza,
    String? archivoPath,
    required DateTime fechaCaptura,
    double? confianzaIa,
  }) async {
    final documento = DocumentoVehicularModel(
      id: '',
      vehiculoId: vehiculoId,
      tipoDocumento: tipoDocumento,
      numero: numero,
      fechaEmision: fechaEmision,
      fechaVencimiento: fechaVencimiento,
      compania: compania,
      numeroPoliza: numeroPoliza,
      archivoPath: archivoPath,
      origenRegistro: 'ia',
      fechaCaptura: fechaCaptura,
      confianzaIa: confianzaIa,
      fechaRegistro: DateTime.now(),
    );

    final anteriores = await _buscarAnteriores(vehiculoId, tipoDocumento);
    final docRef = await _documentos.add(documento.toJson());
    await _eliminarReemplazados(
      anteriores,
      nuevoId: docRef.id,
      nuevoArchivoPath: archivoPath,
    );

    await _auditoriaService.registrar(
      usuarioId: null,
      accion: 'CREAR',
      tipoEntidad: 'DOCUMENTO_VEHICULAR',
      entidadId: docRef.id,
      detalle: 'Documento confirmado después de revisión (Registro Inteligente)',
      origen: 'ia',
    );

    if (fechaVencimiento != null) {
      await _notificacionService.configurarNotificacionesVencimiento(
        vehiculoId: vehiculoId,
        documentoId: docRef.id,
        nombreDocumento: tipoDocumento.etiqueta,
        fechaVencimiento: fechaVencimiento,
      );
    }

    return docRef.id;
  }

  /// CU4 — configurar/actualizar la fecha de vencimiento de un documento.
  Future<void> actualizarVencimiento(
    String documentoId,
    DateTime fechaVencimiento,
  ) async {
    final documentoRef = _documentos.doc(documentoId);
    final documentoSnapshot = await documentoRef.get();

    if (!documentoSnapshot.exists) {
      throw StateError('No existe el documento vehicular $documentoId.');
    }

    final documentoData = documentoSnapshot.data();
    if (documentoData == null) {
      throw StateError('El documento vehicular $documentoId no tiene datos válidos.');
    }

    final rawVehiculoId = documentoData['vehiculo_id'];

    if (rawVehiculoId is! String || rawVehiculoId.trim().isEmpty) {
      throw StateError(
        'No se pudo obtener un vehiculo_id válido asociado al documento $documentoId.',
      );
    }

    final vehiculoId = rawVehiculoId.trim();

    await documentoRef.update({
      'fecha_vencimiento': Timestamp.fromDate(fechaVencimiento),
    });

    final nombreDocumento = TipoDocumentoVehicularJson.fromFirestore(
      documentoData['tipo_documento'] ?? '',
    ).etiqueta;

    await _notificacionService.configurarNotificacionesVencimiento(
      vehiculoId: vehiculoId,
      documentoId: documentoId,
      nombreDocumento: nombreDocumento,
      fechaVencimiento: fechaVencimiento,
    );
  }

  /// CU3 — documentos asociados a un vehículo.
  Stream<List<DocumentoVehicularModel>> streamDocumentosPorVehiculo(
    String vehiculoId,
  ) {
    return _documentos
        .where('vehiculo_id', isEqualTo: vehiculoId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DocumentoVehicularModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }
}
