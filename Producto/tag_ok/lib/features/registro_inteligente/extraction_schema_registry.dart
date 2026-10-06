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
      CampoExtraido(
        clave: 'numero',
        etiqueta: 'Número de informe/certificado',
      ),
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

/// Sufijo de la propiedad booleana que indica si el OCR acertó en un campo.
const String sufijoOcrCorrecto = '_ocr_correcto';

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

/// Descripción de un campo a partir de las etiquetas que le da cada tipo
/// (`tipo -> etiqueta`). Si todos coinciden se usa esa etiqueta; si difieren,
/// se indica a qué tipo corresponde cada una.
String _descripcionCampo(Map<String, String> etiquetaPorTipo) {
  final distintas = etiquetaPorTipo.values.toSet();
  if (distintas.length == 1) return distintas.first;

  return etiquetaPorTipo.entries
      .map((e) => '${e.value} (${e.key})')
      .join(' / ');
}

/// Construye el `Schema` combinado que se le pide a Gemini cuando el tipo de
/// documento todavía no se conoce (CU34: es la propia IA quien lo identifica
/// entre las opciones permitidas). Es la unión de los campos de todos los
/// `tiposPermitidos` — un campo que no aplica al tipo detectado simplemente
/// queda vacío (RF-041, no se inventa nada).
///
/// Si [conVerificacionOcr] es true, junto a cada campo se pide un booleano
/// `{campo}_ocr_correcto`. Cuando no corrió OCR esas propiedades ni siquiera
/// se piden, así llegan ausentes (equivalente a null) y nunca como `false`.
Schema buildCombinedSchema(
  List<DocumentType> tiposPermitidos, {
  bool conVerificacionOcr = false,
}) {
  // Una misma clave puede existir en varios tipos con etiquetas distintas
  // (p. ej. `numero`: informe de Revisión Técnica vs. póliza SOAP). La
  // descripción combina las de todos los tipos que la definen, en vez de
  // quedarse con la del último.
  final etiquetasPorClave = <String, Map<String, String>>{};
  for (final tipo in tiposPermitidos) {
    final schema = extractionSchemas[tipo]!;
    for (final campo in schema.campos) {
      etiquetasPorClave.putIfAbsent(campo.clave, () => {})[schema.etiqueta] =
          campo.etiqueta;
    }
  }

  final descripciones = <String, String>{
    for (final entry in etiquetasPorClave.entries)
      entry.key: _descripcionCampo(entry.value),
  };

  final properties = <String, Schema>{
    'tipo_documento': Schema.enumString(
      enumValues: tiposPermitidos.map(_valorFirestore).toList(),
      description:
          'El tipo de documento detectado, o ausente si no se pudo identificar.',
      nullable: true,
    ),
    for (final entry in descripciones.entries)
      entry.key: Schema.string(
        description: entry.value,
        nullable: true,
      ),
    if (conVerificacionOcr)
      for (final entry in descripciones.entries)
        '${entry.key}$sufijoOcrCorrecto': Schema.boolean(
          description:
              'true si el valor del OCR para "${entry.value}" coincide con '
              'lo que se ve en la imagen; false si no coincide; ausente si el '
              'campo no aparece en el documento.',
          nullable: true,
        ),
  };

  return Schema.object(properties: properties);
}

/// Prompt de instrucciones para la extracción combinada (CU34 + CU35).
///
/// [textoDesdeOcr] indica que junto a la imagen se envía un texto obtenido por
/// OCR local del mismo documento: Gemini actúa como verificador de ese texto
/// contra la imagen, que es la única fuente de verdad.
String buildExtractionPrompt(
  List<DocumentType> tiposPermitidos, {
  bool textoDesdeOcr = false,
}) {
  final avisoOcr = textoDesdeOcr
      ? '''


Además de la imagen, se incluye un texto obtenido por OCR de ese mismo
documento, que puede tener errores de reconocimiento (por ejemplo "0"
confundido con "O", "1" con "I" o "l", "5" con "S", "8" con "B"). La imagen es
tu única fuente de verdad: para cada campo, usa lo que ves en la imagen. Si el
valor del texto de OCR coincide con lo que ves, confírmalo. Si no coincide, usa
el valor correcto que ves en la imagen, nunca el del OCR. Nunca agregues
información que no esté en la imagen.

Para cada campo devuelve además "{campo}_ocr_correcto": true si el valor del
OCR coincidía con lo que ves en la imagen, false si no coincidía o el OCR no lo
detectó. Si el campo no aparece en el documento, deja ambos vacíos.
'''
      : '';

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
deja "tipo_documento" vacío.$avisoOcr''';
}

/// Interpreta la respuesta JSON de Gemini contra los tipos permitidos.
///
/// `confianzaIa` es la proporción de campos con `{campo}_ocr_correcto: true`
/// sobre el total de campos con valor devueltos. Es null cuando no hubo OCR
/// (ningún `_ocr_correcto` con valor): nunca se fuerza a 0 ni a 1.
({DocumentType? tipo, Map<String, dynamic> campos, double? confianzaIa})
    parseExtractionResponse(
  Map<String, dynamic> json,
) {
  final tipoRaw = json['tipo_documento'] as String?;
  final tipo = tipoRaw != null ? _tipoDesdeValorFirestore(tipoRaw) : null;

  final campos = <String, dynamic>{};
  var verificadosPorOcr = 0;
  var ocrCorrectos = 0;

  for (final entry in json.entries) {
    if (entry.key == 'tipo_documento') continue;
    final valor = entry.value;

    // Los booleanos de verificación no son campos del documento.
    if (entry.key.endsWith(sufijoOcrCorrecto)) {
      if (valor is bool) {
        verificadosPorOcr++;
        if (valor) ocrCorrectos++;
      }
      continue;
    }

    if (valor is String && valor.trim().isEmpty) continue;
    if (valor != null) campos[entry.key] = valor;
  }

  final confianzaIa = (verificadosPorOcr == 0 || campos.isEmpty)
      ? null
      : (ocrCorrectos / campos.length).clamp(0.0, 1.0).toDouble();

  return (tipo: tipo, campos: campos, confianzaIa: confianzaIa);
}
