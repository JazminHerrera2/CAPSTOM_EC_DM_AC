import 'document_type.dart';

/// Un campo que la IA puede extraer para un tipo de documento — RNF-007:
/// el esquema por tipo de documento vive acá, desacoplado del motor de IA
/// (`OpenAiExtractionService`) y de la UI (`SmartCaptureReviewScreen`).
class CampoExtraido {
  final String clave;
  final String etiqueta;
  final bool requerido;

  /// Cómo suele aparecer este campo en el documento real (nombres alternativos
  /// que usa cada emisor). Se le pasa a la IA para que no lo dé por ausente
  /// solo porque el documento lo rotula distinto.
  final String? pista;

  const CampoExtraido({
    required this.clave,
    required this.etiqueta,
    this.requerido = false,
    this.pista,
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
      CampoExtraido(clave: 'fecha_emision', etiqueta: 'Fecha de emisión', pista: 'muchos permisos NO la traen (solo el año y el período): si no figura una fecha de pago, emisión u otorgamiento, déjala en null'),
      CampoExtraido(
        clave: 'fecha_vencimiento',
        etiqueta: 'Fecha de vencimiento',
        requerido: true,
        pista: 'se rotula "PERÍODO" (ej. "31/03/2027"), "vence" o "válido hasta"; es la fecha hasta la que está vigente (suele ser el 31 de marzo del año siguiente)',
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
      CampoExtraido(clave: 'fecha_emision', etiqueta: 'Fecha de emisión', pista: 'en el certificado se rotula "FECHA REVISIÓN" (ej. "26 FEBRERO 2026"); también "fecha de inspección"'),
      CampoExtraido(
        clave: 'fecha_vencimiento',
        etiqueta: 'Fecha de vencimiento',
        requerido: true,
        pista: 'se rotula "VÁLIDO HASTA" con solo mes y año (ej. "FEBRERO 2027"): usa el último día de ese mes',
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
      CampoExtraido(clave: 'fecha_emision', etiqueta: 'Fecha de emisión', pista: 'se rotula "Fecha de emisión", "Rige desde", "Vigencia desde" o "Inicio de vigencia"'),
      CampoExtraido(
        clave: 'fecha_vencimiento',
        etiqueta: 'Fecha de vencimiento',
        requerido: true,
        pista: 'se rotula "Rige hasta", "Vigencia hasta" o "Término de vigencia"',
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
      CampoExtraido(clave: 'fecha_emision', etiqueta: 'Fecha de emisión', pista: 'se rotula "Fecha de emisión", "Vigencia desde", "Rige desde" o "Fecha de inicio"'),
      CampoExtraido(
        clave: 'fecha_vencimiento',
        etiqueta: 'Fecha de vencimiento',
        requerido: true,
        pista: 'se rotula "Vigencia hasta", "Rige hasta" o "Fecha de término"',
      ),
    ],
  ),
};

/// Campos que la IA lee solo para completar otros: se piden en el esquema pero
/// no se muestran en la revisión ni se guardan. Ej.: el año del permiso sirve
/// para estimar la fecha de emisión cuando el documento no la trae.
const Map<DocumentType, List<CampoExtraido>> camposAuxiliaresIa = {
  DocumentType.permisoCirculacion: [
    CampoExtraido(
      clave: 'anio_permiso',
      etiqueta: 'Año del permiso',
      pista: 'se rotula "AÑO" (ej. "2026"); solo el año, 4 dígitos',
    ),
  ],
};

/// Clave que la revisión agrega a los campos confirmados cuando la fecha de
/// emisión es una estimación (valor "true"). No es un campo del documento.
const String claveFechaEmisionEstimada = 'fecha_emision_estimada';

/// Clave del campo auxiliar con el año del permiso.
const String claveAnioPermiso = 'anio_permiso';

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

/// Construye el JSON Schema (modo estricto de OpenAI) que se le pide a la IA cuando el tipo de
/// documento todavía no se conoce (CU34: es la propia IA quien lo identifica
/// entre las opciones permitidas). Es la unión de los campos de todos los
/// `tiposPermitidos` — un campo que no aplica al tipo detectado simplemente
/// queda vacío (RF-041, no se inventa nada).
///
/// Si [conVerificacionOcr] es true, junto a cada campo se pide un booleano
/// `{campo}_ocr_correcto`. Cuando no corrió OCR esas propiedades ni siquiera
/// se piden, así llegan ausentes (equivalente a null) y nunca como `false`.
Map<String, dynamic> buildCombinedSchema(
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
    for (final campo in [...schema.campos, ...?camposAuxiliaresIa[tipo]]) {
      etiquetasPorClave.putIfAbsent(campo.clave, () => {})[schema.etiqueta] =
          campo.etiqueta;
    }
  }

  final descripciones = <String, String>{
    for (final entry in etiquetasPorClave.entries)
      entry.key: _descripcionCampo(entry.value),
  };

  // Modo estricto de OpenAI: todas las propiedades van en `required` y lo que
  // no aparece en el documento se devuelve como null (nunca se inventa).
  final properties = <String, dynamic>{
    'tipo_documento': {
      'type': ['string', 'null'],
      'enum': [...tiposPermitidos.map(_valorFirestore), null],
      'description':
          'El tipo de documento detectado, o null si no se pudo identificar.',
    },
    for (final entry in descripciones.entries)
      entry.key: {
        'type': ['string', 'null'],
        'description': entry.value,
      },
    if (conVerificacionOcr)
      for (final entry in descripciones.entries)
        '${entry.key}$sufijoOcrCorrecto': {
          'type': ['boolean', 'null'],
          'description':
              'true si el valor del OCR para "${entry.value}" coincide con '
              'lo que se ve en la imagen; false si no coincide; null si el '
              'campo no aparece en el documento.',
        },
  };

  return {
    'type': 'object',
    'properties': properties,
    'required': properties.keys.toList(),
    'additionalProperties': false,
  };
}

/// Prompt de instrucciones para la extracción combinada (CU34 + CU35).
///
/// [textoDesdeOcr] indica que junto a la imagen se envía un texto obtenido por
/// OCR local del mismo documento: la IA actúa como verificador de ese texto
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
    final camposTexto = [...schema.campos, ...?camposAuxiliaresIa[tipo]]
        .map((c) => c.pista == null ? c.etiqueta : '${c.etiqueta} (${c.pista})')
        .join('\n    · ');
    return '- ${schema.etiqueta}: campos esperados\n    · $camposTexto';
  }).join('\n');

  return '''
Eres un asistente experto en documentos vehiculares chilenos. Analiza la
evidencia (imagen o texto) recibida e identifica a cuál de los siguientes
tipos de documento corresponde:

$descripcionTipos

Extrae únicamente los campos que puedas reconocer con certeza del documento.
Si un campo no es legible o no aparece en el documento, devuélvelo como null —
nunca inventes ni infieras un valor. Si no puedes identificar el tipo de
documento con confianza, deja "tipo_documento" en null.

La foto puede estar girada (de lado o al revés) y el documento puede ser una
tarjeta plastificada con reflejos: léelo igualmente. Muchos documentos
rotulan la fecha de emisión o la de vencimiento con otro nombre (por ejemplo
"Rige desde"/"Rige hasta" o "Fecha revisión"/"Válido hasta"): usa las pistas
indicadas junto a cada campo y no los des por ausentes si aparecen con ese
rótulo.

Reglas de formato:
- "patente": la placa patente chilena en MAYÚSCULAS y sin guiones, puntos ni
  espacios. Si va seguida de un guion y un dígito verificador (ej. "KZZZ60-0"),
  ignora ese dígito: la patente es "KZZZ60". Los formatos válidos son 4 letras + 2 números (ej. "BCDF12"), 2
  letras + 4 números (ej. "AB1234", formato antiguo) y, en motos, 3 letras + 2
  números (ej. "BCD12"). Ten cuidado de no confundir "0" con "O", "1" con "I",
  "5" con "S" ni "8" con "B": las letras y los números van en posiciones fijas
  de la patente.
- Fechas: formato "YYYY-MM-DD". Los documentos chilenos escriben las fechas
  como día/mes/año ("05/03/2026" es el 5 de marzo de 2026, no el 3 de mayo) o
  con el mes en palabras ("26 FEBRERO 2026" es 2026-02-26).
- "fecha_vencimiento" es la fecha hasta la que el documento está vigente (suele
  decir "vence", "válido hasta" o "vigencia"); no la confundas con la fecha de
  emisión, de pago o de proceso. Si el documento solo indica un mes de
  vencimiento (como la revisión técnica, que vence el último día del mes), usa
  el último día de ese mes.
- Textos (compañía, números de póliza o informe): cópialos tal como aparecen,
  sin traducir ni abreviar.

Si el documento tiene varias fechas o varias patentes, elige las que
correspondan al vehículo y a la vigencia del propio documento.$avisoOcr''';
}

/// Interpreta la respuesta JSON de la IA contra los tipos permitidos.
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
