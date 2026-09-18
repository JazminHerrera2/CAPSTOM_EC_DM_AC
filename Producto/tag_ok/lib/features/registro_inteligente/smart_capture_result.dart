import 'document_type.dart';

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

  final String origen;
  final DateTime fechaCaptura;

  SmartCaptureResult({
    required this.tipoDetectado,
    required this.campos,
    required this.camposDudosos,
    this.origen = 'ia',
    required this.fechaCaptura,
  });
}
