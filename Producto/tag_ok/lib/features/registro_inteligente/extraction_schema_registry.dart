import 'package:google_generative_ai/google_generative_ai.dart';
import 'document_type.dart';

/// Un campo que la IA puede extraer para un tipo de documento — RNF-007:
/// el esquema por tipo de documento vive acá, desacoplado del motor de IA
/// (`GeminiExtractionService`) y de la UI (`SmartCaptureReviewScreen`).
class CampoExtraido {
  final String clave;
  final String etiqueta;
  final bool requerido;

  const CampoExtraido({
    required this.clave,
    required this.etiqueta,
    this.requerido = false,
  });
}

class ExtractionSchema {
  final DocumentType tipo;
  final String etiqueta;
  final List<CampoExtraido> campos;

  const ExtractionSchema({
    required this.tipo,
    required this.etiqueta,
    required this.campos,
  });
}

/// Registro central: cada tipo de documento define acá sus propios campos.
/// Agregar un tipo nuevo (Sprint 3+) no requiere tocar el resto del
/// componente de Registro Inteligente.
const Map<DocumentType, ExtractionSchema> extractionSchemas = {
  DocumentType.permisoCirculacion: ExtractionSchema(
    tipo: DocumentType.permisoCirculacion,
    etiqueta: 'Permiso de Circulación',
    campos: [
      CampoExtraido(clave: 'patente', etiqueta: 'Patente', requerido: true),
      CampoExtraido(clave: 'numero', etiqueta: 'Número de documento'),
      CampoExtraido(clave: 'fecha_emision', etiqueta: 'Fecha de emisión'),
      CampoExtraido(
        clave: 'fecha_vencimiento',
        etiqueta: 'Fecha de vencimiento',
        requerido: true,
      ),
    ],
  ),
  DocumentType.revisionTecnica: ExtractionSchema(
    tipo: DocumentType.revisionTecnica,
    etiqueta: 'Revisión Técnica',
    campos: [
      CampoExtraido(clave: 'patente', etiqueta: 'Patente', requerido: true),
      CampoExtraido(clave: 'numero', etiqueta: 'Número de documento'),
      CampoExtraido(clave: 'fecha_emision', etiqueta: 'Fecha de emisión'),
      CampoExtraido(
        clave: 'fecha_vencimiento',
        etiqueta: 'Fecha de vencimiento',
        requerido: true,
      ),
    ],
  ),
  DocumentType.soap: ExtractionSchema(
    tipo: DocumentType.soap,
    etiqueta: 'SOAP',
    campos: [
      CampoExtraido(clave: 'patente', etiqueta: 'Patente', requerido: true),
      CampoExtraido(clave: 'numero', etiqueta: 'Número de póliza SOAP'),
      CampoExtraido(clave: 'compania', etiqueta: 'Compañía'),
      CampoExtraido(clave: 'fecha_emision', etiqueta: 'Fecha de emisión'),
      CampoExtraido(
        clave: 'fecha_vencimiento',
        etiqueta: 'Fecha de vencimiento',
        requerido: true,
      ),
    ],
  ),
  DocumentType.seguro: ExtractionSchema(
    tipo: DocumentType.seguro,
    etiqueta: 'Seguro Automotriz',
    campos: [
      CampoExtraido(clave: 'patente', etiqueta: 'Patente', requerido: true),
      CampoExtraido(clave: 'compania', etiqueta: 'Compañía', requerido: true),
      CampoExtraido(clave: 'numero_poliza', etiqueta: 'Número de póliza'),
      CampoExtraido(clave: 'fecha_emision', etiqueta: 'Fecha de emisión'),
      CampoExtraido(
        clave: 'fecha_vencimiento',
        etiqueta: 'Fecha de vencimiento',
        requerido: true,
      ),
    ],
  ),
};

String _valorFirestore(DocumentType tipo) {
  switch (tipo) {
    case DocumentType.permisoCirculacion:
      return 'permiso_circulacion';
    case DocumentType.revisionTecnica:
      return 'revision_tecnica';
    case DocumentType.soap:
      return 'soap';
    case DocumentType.seguro:
      return 'seguro';
  }
}

DocumentType? _tipoDesdeValorFirestore(String valor) {
  for (final tipo in DocumentType.values) {
    if (_valorFirestore(tipo) == valor) return tipo;
  }
  return null;
}

/// Construye el `Schema` combinado que se le pide a Gemini cuando el tipo de
/// documento todavía no se conoce (CU34: es la propia IA quien lo identifica
/// entre las opciones permitidas). Es la unión de los campos de todos los
/// `tiposPermitidos` — un campo que no aplica al tipo detectado simplemente
/// queda vacío (RF-041, no se inventa nada).
Schema buildCombinedSchema(List<DocumentType> tiposPermitidos) {
  final camposUnicos = <String, CampoExtraido>{};
  for (final tipo in tiposPermitidos) {
    for (final campo in extractionSchemas[tipo]!.campos) {
      camposUnicos[campo.clave] = campo;
    }
  }

  final properties = <String, Schema>{
    'tipo_documento': Schema.enumString(
      enumValues: tiposPermitidos.map(_valorFirestore).toList(),
      description:
          'El tipo de documento detectado, o ausente si no se pudo identificar.',
      nullable: true,
    ),
    for (final campo in camposUnicos.values)
      campo.clave: Schema.string(
        description: campo.etiqueta,
        nullable: true,
      ),
  };

  return Schema.object(properties: properties);
}

/// Prompt de instrucciones para la extracción combinada (CU34 + CU35).
String buildExtractionPrompt(List<DocumentType> tiposPermitidos) {
  final descripcionTipos = tiposPermitidos.map((tipo) {
    final schema = extractionSchemas[tipo]!;
    final camposTexto = schema.campos.map((c) => c.etiqueta).join(', ');
    return '- ${schema.etiqueta}: campos esperados ($camposTexto)';
  }).join('\n');

  return '''
Eres un asistente experto en documentos vehiculares chilenos. Analiza la
evidencia (imagen o texto) recibida e identifica a cuál de los siguientes
tipos de documento corresponde:

$descripcionTipos

Extrae únicamente los campos que puedas reconocer con certeza del documento.
Si un campo no es legible o no aparece en el documento, déjalo vacío — nunca
inventes ni infieras un valor. Las fechas deben devolverse en formato
"YYYY-MM-DD". Si no puedes identificar el tipo de documento con confianza,
deja "tipo_documento" vacío.
''';
}

/// Interpreta la respuesta JSON de Gemini contra los tipos permitidos.
({DocumentType? tipo, Map<String, dynamic> campos}) parseExtractionResponse(
  Map<String, dynamic> json,
) {
  final tipoRaw = json['tipo_documento'] as String?;
  final tipo = tipoRaw != null ? _tipoDesdeValorFirestore(tipoRaw) : null;

  final campos = <String, dynamic>{};
  for (final entry in json.entries) {
    if (entry.key == 'tipo_documento') continue;
    final valor = entry.value;
    if (valor is String && valor.trim().isEmpty) continue;
    if (valor != null) campos[entry.key] = valor;
  }

  return (tipo: tipo, campos: campos);
}
