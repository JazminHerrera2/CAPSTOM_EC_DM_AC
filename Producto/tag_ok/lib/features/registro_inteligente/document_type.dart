/// Tipos de documento que el componente transversal de Registro Inteligente
/// sabe reconocer y extraer (CU34/CU35).
///
/// Este Sprint solo declara los 4 tipos que usa Mi Vehículo. Los Sprints
/// siguientes (Mantenciones, Estacionamientos, Combustible) agregan sus
/// propios valores acá — el resto del componente (`GeminiExtractionService`,
/// `SmartCaptureController`, `SmartCaptureReviewScreen`) no cambia cuando
/// eso pase, solo se registra el tipo nuevo en `extraction_schema_registry.dart`.
enum DocumentType {
  permisoCirculacion,
  revisionTecnica,
  soap,
  seguro,
}
