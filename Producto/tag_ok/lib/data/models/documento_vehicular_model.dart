import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de documento vehicular soportados por Mi Vehículo (CU3/CU6).
///
/// El componente transversal de Registro Inteligente (lib/features/
/// registro_inteligente/document_type.dart) tiene su propio enum genérico
/// DocumentType; este enum es específico del módulo Mi Vehículo y se mapea
/// al genérico en la capa de UI, no al revés — así los Sprints siguientes
/// agregan sus propios tipos sin tocar este archivo.
enum TipoDocumentoVehicular {
  permisoCirculacion,
  revisionTecnica,
  soap,
  seguro,
}

extension TipoDocumentoVehicularJson on TipoDocumentoVehicular {
  String get valorFirestore {
    switch (this) {
      case TipoDocumentoVehicular.permisoCirculacion:
        return 'permiso_circulacion';
      case TipoDocumentoVehicular.revisionTecnica:
        return 'revision_tecnica';
      case TipoDocumentoVehicular.soap:
        return 'soap';
      case TipoDocumentoVehicular.seguro:
        return 'seguro';
    }
  }

  String get etiqueta {
    switch (this) {
      case TipoDocumentoVehicular.permisoCirculacion:
        return 'Permiso de Circulación';
      case TipoDocumentoVehicular.revisionTecnica:
        return 'Revisión Técnica';
      case TipoDocumentoVehicular.soap:
        return 'SOAP';
      case TipoDocumentoVehicular.seguro:
        return 'Seguro Automotriz';
    }
  }

  static TipoDocumentoVehicular fromFirestore(String valor) {
    return TipoDocumentoVehicular.values.firstWhere(
      (t) => t.valorFirestore == valor,
      orElse: () => TipoDocumentoVehicular.permisoCirculacion,
    );
  }
}

/// Entidad DOCUMENTOS_VEHICULARES.
class DocumentoVehicularModel {
  final String id;
  final String vehiculoId;
  final TipoDocumentoVehicular tipoDocumento;
  final String? numero;
  final DateTime? fechaEmision;
  final DateTime? fechaVencimiento;
  final String? compania;
  final String? numeroPoliza;
  final String? archivoPath;

  /// 'manual' o 'ia' — RNF-006 / RF-042.
  final String origenRegistro;
  final DateTime? fechaCaptura;
  final double? confianzaIa;
  final DateTime fechaRegistro;

  DocumentoVehicularModel({
    required this.id,
    required this.vehiculoId,
    required this.tipoDocumento,
    this.numero,
    this.fechaEmision,
    this.fechaVencimiento,
    this.compania,
    this.numeroPoliza,
    this.archivoPath,
    required this.origenRegistro,
    this.fechaCaptura,
    this.confianzaIa,
    required this.fechaRegistro,
  });

  factory DocumentoVehicularModel.fromJson(
    Map<String, dynamic> json,
    String id,
  ) {
    return DocumentoVehicularModel(
      id: id,
      vehiculoId: json['vehiculo_id'] ?? '',
      tipoDocumento: TipoDocumentoVehicularJson.fromFirestore(
        json['tipo_documento'] ?? '',
      ),
      numero: json['numero'],
      fechaEmision: (json['fecha_emision'] as Timestamp?)?.toDate(),
      fechaVencimiento: (json['fecha_vencimiento'] as Timestamp?)?.toDate(),
      compania: json['compania'],
      numeroPoliza: json['numero_poliza'],
      archivoPath: json['archivo_path'],
      origenRegistro: json['origen_registro'] ?? 'manual',
      fechaCaptura: (json['fecha_captura'] as Timestamp?)?.toDate(),
      confianzaIa: (json['confianza_ia'] as num?)?.toDouble(),
      fechaRegistro: (json['fecha_registro'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehiculo_id': vehiculoId,
      'tipo_documento': tipoDocumento.valorFirestore,
      'numero': numero,
      'fecha_emision': fechaEmision != null
          ? Timestamp.fromDate(fechaEmision!)
          : null,
      'fecha_vencimiento': fechaVencimiento != null
          ? Timestamp.fromDate(fechaVencimiento!)
          : null,
      'compania': compania,
      'numero_poliza': numeroPoliza,
      'archivo_path': archivoPath,
      'origen_registro': origenRegistro,
      'fecha_captura': fechaCaptura != null
          ? Timestamp.fromDate(fechaCaptura!)
          : null,
      'confianza_ia': confianzaIa,
      'fecha_registro': Timestamp.fromDate(fechaRegistro),
    };
  }
}
