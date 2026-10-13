import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../data/models/tipo_mantencion.dart';
import 'gemini_extraction_service.dart';

/// Datos que la IA reconoció en una boleta o factura de mantención. Todos son
/// opcionales: lo que no se lee con certeza queda en null y el usuario lo
/// completa en el formulario de revisión.
class MantencionExtraida {
  final TipoMantencion? tipo;
  final String? tipoOtro;
  final DateTime? fecha;
  final int? kilometraje;
  final String? taller;
  final int? costo;
  final String? descripcion;
  final String? observaciones;

  const MantencionExtraida({
    this.tipo,
    this.tipoOtro,
    this.fecha,
    this.kilometraje,
    this.taller,
    this.costo,
    this.descripcion,
    this.observaciones,
  });

  /// `true` si la IA no logró leer ningún dato.
  bool get vacia =>
      tipo == null &&
      fecha == null &&
      kilometraje == null &&
      taller == null &&
      costo == null &&
      descripcion == null &&
      observaciones == null;
}

final Schema _esquemaMantencion = Schema.object(
  properties: {
    'tipo_mantencion': Schema.enumString(
      enumValues: TipoMantencion.values.map((t) => t.valorFirestore).toList(),
      description: 'Tipo de mantención que mejor describe el servicio.',
      nullable: true,
    ),
    'tipo_otro': Schema.string(
      description:
          'Nombre corto del servicio, solo si tipo_mantencion es "otra".',
      nullable: true,
    ),
    'fecha': Schema.string(
      description: 'Fecha del servicio en formato YYYY-MM-DD.',
      nullable: true,
    ),
    'kilometraje': Schema.string(
      description: 'Kilometraje del vehículo (solo el número).',
      nullable: true,
    ),
    'taller': Schema.string(
      description: 'Nombre del taller o proveedor que emite el documento.',
      nullable: true,
    ),
    'costo': Schema.string(
      description: 'Monto total pagado en pesos chilenos (solo el número).',
      nullable: true,
    ),
    'descripcion': Schema.string(
      description: 'Servicios realizados y repuestos o piezas, resumidos.',
      nullable: true,
    ),
    'observaciones': Schema.string(
      description: 'Observaciones o recomendaciones escritas en el documento.',
      nullable: true,
    ),
  },
);

String _promptMantencion() {
  final tipos = TipoMantencion.values
      .map((t) => '- ${t.valorFirestore}: ${t.etiqueta}')
      .join('\n');
  return '''
Eres un asistente experto en boletas y facturas de talleres mecánicos
chilenos. Analiza el comprobante recibido (imagen o PDF) de una mantención
vehicular y extrae sus datos.

Para "tipo_mantencion" elige la opción que mejor describa el servicio:

$tipos

Usa "otra" solo si ninguna aplica y en ese caso indica "tipo_otro". Si el
comprobante incluye varios servicios, elige el principal y detalla todos en
"descripcion".

Extrae únicamente lo que puedas reconocer con certeza. Si un dato no es
legible o no aparece, déjalo vacío: nunca inventes ni infieras un valor. La
fecha debe ir en formato "YYYY-MM-DD". "costo" es el monto total pagado en
pesos chilenos y "kilometraje" el del odómetro, ambos solo con números.''';
}

int? _entero(Object? valor) {
  if (valor == null) return null;
  var texto = valor.toString().trim();
  // Descarta decimales ("45000,50" / "45000.5") antes de quitar separadores
  // de miles ("45.000").
  texto = texto.replaceFirst(RegExp(r'[,.]\d{1,2}$'), '');
  final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  return digitos.isEmpty ? null : int.tryParse(digitos);
}

DateTime? _fechaValida(int anio, int mes, int dia) {
  final fecha = DateTime(anio, mes, dia);
  return (fecha.year == anio && fecha.month == mes && fecha.day == dia)
      ? fecha
      : null;
}

DateTime? _fecha(Object? valor) {
  final texto = valor?.toString().trim() ?? '';
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(texto);
  if (iso != null) {
    return _fechaValida(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final cl = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(texto);
  if (cl != null) {
    return _fechaValida(
      int.parse(cl.group(3)!),
      int.parse(cl.group(2)!),
      int.parse(cl.group(1)!),
    );
  }
  return null;
}

String? _texto(Object? valor, int maximo) {
  final t = valor?.toString().trim() ?? '';
  if (t.isEmpty) return null;
  return t.length > maximo ? t.substring(0, maximo) : t;
}

/// Interpreta el JSON de Gemini. Los largos máximos coinciden con las reglas
/// de Firestore (`mantencionValida`), para que lo extraído siempre se pueda
/// guardar. Un kilometraje o costo fuera de rango se descarta.
MantencionExtraida parseMantencionExtraida(Map<String, dynamic> json) {
  final tipoRaw = json['tipo_mantencion']?.toString();
  final tipo = TipoMantencion.values
      .where((t) => t.valorFirestore == tipoRaw)
      .firstOrNull;

  final km = _entero(json['kilometraje']);
  final costo = _entero(json['costo']);

  return MantencionExtraida(
    tipo: tipo,
    tipoOtro:
        tipo == TipoMantencion.otra ? _texto(json['tipo_otro'], 100) : null,
    fecha: _fecha(json['fecha']),
    kilometraje: (km != null && km <= 5000000) ? km : null,
    taller: _texto(json['taller'], 100),
    costo: (costo != null && costo <= 1000000000) ? costo : null,
    descripcion: _texto(json['descripcion'], 500),
    observaciones: _texto(json['observaciones'], 1000),
  );
}

/// Lee una boleta o factura de mantención con Gemini (misma cascada de
/// modelos y reintentos que el Registro Inteligente de documentos). Lanza la
/// excepción si la IA falla: el llamador debe ofrecer el ingreso manual.
Future<MantencionExtraida> extraerMantencion({
  required Uint8List bytes,
  required String mimeType,
  GeminiExtractionService? servicio,
}) async {
  final respuesta = await (servicio ?? GeminiExtractionService())
      .generateContentWithFallback(
    parts: [DataPart(mimeType, bytes), TextPart(_promptMantencion())],
    responseSchema: _esquemaMantencion,
  );

  final json = jsonDecode(respuesta.text?.trim() ?? '{}');
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Respuesta de la IA con formato inesperado.');
  }
  return parseMantencionExtraida(json);
}
