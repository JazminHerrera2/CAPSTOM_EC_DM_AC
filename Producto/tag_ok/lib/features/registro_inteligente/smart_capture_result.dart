import 'document_type.dart';

/// La lanza el callback `onConfirm` de un módulo cuando rechaza los datos ya
/// revisados por una regla propia (p. ej. la patente del documento no coincide
/// con la del vehículo). La pantalla de revisión muestra [mensaje] tal cual,
/// en vez del error genérico de guardado, y el usuario puede corregir.
class SmartCaptureValidationException implements Exception {
  final String mensaje;

  const SmartCaptureValidationException(this.mensaje);

  @override
  String toString() => 'SmartCaptureValidationException: $mensaje';
}

/// Contrato entre la capa de IA (captura + extracción) y la capa de UI de
/// cada módulo (CU33-CU35 → CU36/CU37 de revisión). Un módulo (Mi Vehículo
/// hoy, Mantenciones/Estacionamientos/Combustible después) recibe esto y
/// decide por su cuenta cómo persistirlo (CU39) — este componente no sabe
/// nada de Firestore ni de ningún módulo específico.
class SmartCaptureResult {
  /// Null si la IA no logró identificar el tipo de documento (E1 de CU34) —
  /// el módulo llamante debe permitir que el usuario lo seleccione
  /// manualmente o recurra a CU40.
  final DocumentType? tipoDetectado;

  /// Campos reconocidos, con las claves definidas en `extraction_schema_registry.dart`.
  final Map<String, dynamic> campos;

  /// Campos esperados para `tipoDetectado` que la IA no pudo reconocer —
  /// se destacan en la pantalla de revisión (CU36).
  final Set<String> camposDudosos;

  /// Proporción (0-1) de campos cuyo valor del OCR coincidió con la imagen,
  /// según la verificación de Gemini. Null si no corrió OCR.
  final double? confianzaIa;

  final String origen;
  final DateTime fechaCaptura;

  SmartCaptureResult({
    required this.tipoDetectado,
    required this.campos,
    required this.camposDudosos,
    this.confianzaIa,
    this.origen = 'ia',
    required this.fechaCaptura,
  });
}
