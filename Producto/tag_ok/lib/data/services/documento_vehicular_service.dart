import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/documento_vehicular_model.dart';
import 'auditoria_service.dart';

/// CRUD de la colección `documentos_vehiculares` (CU3, CU4, CU6, CU7, CU39).
class DocumentoVehicularService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditoriaService _auditoriaService = AuditoriaService();

  CollectionReference<Map<String, dynamic>> get _documentos =>
      _firestore.collection('documentos_vehiculares');

  /// CU3 / CU40 — registro manual (sin IA) de un documento.
  Future<String> crearDocumentoManual(DocumentoVehicularModel documento) async {
    final docRef = await _documentos.add(documento.toJson());

    await _auditoriaService.registrar(
      usuarioId: null,
      accion: 'CREAR',
      tipoEntidad: 'DOCUMENTO_VEHICULAR',
      entidadId: docRef.id,
      detalle: 'Documento registrado manualmente',
      origen: 'manual',
    );

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

    final docRef = await _documentos.add(documento.toJson());

    await _auditoriaService.registrar(
      usuarioId: null,
      accion: 'CREAR',
      tipoEntidad: 'DOCUMENTO_VEHICULAR',
      entidadId: docRef.id,
      detalle: 'Documento confirmado después de revisión (Registro Inteligente)',
      origen: 'ia',
    );

    return docRef.id;
  }

  /// CU4 — configurar/actualizar la fecha de vencimiento de un documento.
  Future<void> actualizarVencimiento(
    String documentoId,
    DateTime fechaVencimiento,
  ) async {
    await _documentos.doc(documentoId).update({
      'fecha_vencimiento': Timestamp.fromDate(fechaVencimiento),
    });
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
