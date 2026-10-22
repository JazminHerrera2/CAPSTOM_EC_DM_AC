import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/componente_mantencion_model.dart';
import '../../data/models/mantencion_model.dart';
import '../../data/models/tipo_mantencion.dart';
import 'openai_extraction_service.dart';
import 'preparar_imagen.dart';

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
  final TipoComprobante? tipoComprobante;
  final String? numeroComprobante;

  /// Ids de los componentes (`componentes_mantencion`) que el documento indica
  /// como revisados o cambiados.
  final List<String> componentes;

  const MantencionExtraida({
    this.tipo,
    this.tipoOtro,
    this.fecha,
    this.kilometraje,
    this.taller,
    this.costo,
    this.descripcion,
    this.observaciones,
    this.tipoComprobante,
    this.numeroComprobante,
    this.componentes = const [],
  });

  /// `true` si la IA no logró leer ningún dato.
  bool get vacia =>
      tipo == null &&
      fecha == null &&
      kilometraje == null &&
      taller == null &&
      costo == null &&
      descripcion == null &&
      observaciones == null &&
      tipoComprobante == null &&
      numeroComprobante == null &&
      componentes.isEmpty;
}

Map<String, dynamic> _campoTexto(String descripcion) => {
      'type': ['string', 'null'],
      'description': descripcion,
    };

/// JSON Schema estricto de OpenAI: todo va en `required` y lo que no se lee
/// con certeza se devuelve como null.
Map<String, dynamic> _esquemaMantencion(List<ComponenteMantencion> componentes) {
  final properties = <String, dynamic>{
    'tipo_mantencion': {
      'type': ['string', 'null'],
      'enum': [...TipoMantencion.values.map((t) => t.valorFirestore), null],
      'description': 'Tipo de mantención que mejor describe el servicio.',
    },
    'tipo_otro': _campoTexto(
      'Nombre corto del servicio, solo si tipo_mantencion es "otra".',
    ),
    'fecha': _campoTexto('Fecha del servicio en formato YYYY-MM-DD.'),
    'kilometraje': _campoTexto('Kilometraje del vehículo (solo el número).'),
    'taller': _campoTexto('Nombre del taller o proveedor que emite el documento.'),
    'costo': _campoTexto('Monto total pagado en pesos chilenos (solo el número).'),
    'descripcion':
        _campoTexto('Servicios realizados y repuestos o piezas, resumidos.'),
    'observaciones':
        _campoTexto('Observaciones o recomendaciones escritas en el documento.'),
    'tipo_comprobante': {
      'type': ['string', 'null'],
      'enum': [...TipoComprobante.values.map((t) => t.valorFirestore), null],
      'description': 'Tipo de documento tributario: boleta, factura u otro.',
    },
    'numero_comprobante': _campoTexto(
      'Número (folio) del comprobante, solo el número.',
    ),
    'componentes': {
      'type': 'array',
      'items': {
        'type': 'string',
        'enum': componentes.map((c) => c.id).toList(),
      },
      'description':
          'Ids de los componentes a los que el documento indica que se les '
          'realizó mantención. Lista vacía si no hay ninguno.',
    },
  };
  return {
    'type': 'object',
    'properties': properties,
    'required': properties.keys.toList(),
    'additionalProperties': false,
  };
}

String _promptMantencion(List<ComponenteMantencion> componentes) {
  final listaComponentes =
      componentes.map((c) => '- ${c.id}: ${c.nombre}').join('\n');
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
legible o no aparece, devuélvelo como null: nunca inventes ni infieras un
valor.

Reglas de formato:
- "fecha": la fecha del servicio o de emisión del comprobante, en formato
  "YYYY-MM-DD". Los documentos chilenos escriben día/mes/año ("05/03/2026" es
  el 5 de marzo de 2026, no el 3 de mayo).
- "costo": el monto TOTAL pagado (con IVA incluido, el que aparece como
  "Total"), en pesos chilenos, solo con números. En Chile el punto separa los
  miles ("45.990" son cuarenta y cinco mil novecientos noventa pesos). No uses
  un subtotal, el neto ni el IVA.
- "kilometraje": el del odómetro del vehículo (suele decir "KM" o "Kilometraje"),
  solo con números; no lo confundas con el número de boleta, la patente ni el
  RUT.
- "taller": el nombre del taller o proveedor que emite el documento, no el del
  cliente.
- "descripcion": resume los servicios y repuestos tal como aparecen.
- "tipo_comprobante" y "numero_comprobante": búscalos en el recuadro del
  emisor (en documentos electrónicos del SII, el recuadro con el RUT del
  taller, el tipo de documento y "N°"). "BOLETA ELECTRÓNICA" o "BOLETA" es
  "boleta"; "FACTURA ELECTRÓNICA" o "FACTURA" es "factura"; cualquier otro
  comprobante (voucher, comprobante de venta, orden de trabajo) es "otro".
  El número es el folio del documento, solo con números: no lo confundas
  con el RUT, la patente, el kilometraje ni el número de orden de trabajo.
- "componentes": ids de los componentes de esta lista a los que el documento
  indica que se les hizo mantención, cambio o revisión:

$listaComponentes

  Marca un componente solo si el servicio aparece escrito en el documento
  (por ejemplo "aceite motor" o "filtro de aceite" es "cambio_aceite_motor").
  Un insumo suelto (por ejemplo un aerosol "limpia frenos" o "agua
  desmineralizada") no cuenta como mantención del componente. Si no hay
  ninguno, devuelve una lista vacía.
- No extraigas datos del cliente (nombre, RUT ni dirección del comprador).''';
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

/// Una mantención no puede ser futura (se tolera 1 día por la zona horaria) ni
/// anterior a 1990: una fecha así es casi seguro un error de lectura.
DateTime? _fechaPlausible(DateTime? fecha, {DateTime? ahora}) {
  if (fecha == null) return null;
  final hoy = ahora ?? DateTime.now();
  final limite = DateTime(hoy.year, hoy.month, hoy.day).add(
    const Duration(days: 1),
  );
  return (fecha.year < 1990 || fecha.isAfter(limite)) ? null : fecha;
}

String? _texto(Object? valor, int maximo) {
  final t = valor?.toString().trim() ?? '';
  if (t.isEmpty) return null;
  return t.length > maximo ? t.substring(0, maximo) : t;
}

/// Folio del comprobante sin el prefijo que a veces copia la IA
/// ("N° 458123", "No. 458123", "Nro. 458123", "Folio: 458123" -> "458123").
String? _folio(Object? valor) {
  final t = valor?.toString().trim().replaceFirst(
            RegExp(r'^(n\s*[°º.]|no\.|nro\.?|folio)\s*:?\s*',
                caseSensitive: false),
            '',
          ) ??
      '';
  return _texto(t, 50);
}

/// Interpreta el JSON de la IA. Los largos máximos coinciden con las reglas
/// de Firestore (`mantencionValida`), para que lo extraído siempre se pueda
/// guardar. Un kilometraje o costo fuera de rango se descarta.
MantencionExtraida parseMantencionExtraida(
  Map<String, dynamic> json, {
  List<ComponenteMantencion> componentesValidos = componentesPorDefecto,
}) {
  final idsValidos = componentesValidos.map((c) => c.id).toSet();
  final componentes = <String>[
    for (final id in json['componentes'] is List ? json['componentes'] as List : const [])
      if (idsValidos.contains(id.toString())) id.toString(),
  ].toSet().toList();

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
    fecha: _fechaPlausible(_fecha(json['fecha'])),
    kilometraje: (km != null && km <= 5000000) ? km : null,
    taller: _texto(json['taller'], 100),
    costo: (costo != null && costo <= 1000000000) ? costo : null,
    descripcion: _texto(json['descripcion'], 500),
    observaciones: _texto(json['observaciones'], 1000),
    tipoComprobante:
        TipoComprobante.fromFirestore(json['tipo_comprobante']?.toString()),
    numeroComprobante: _folio(json['numero_comprobante']),
    componentes: componentes,
  );
}

/// Lee una boleta o factura de mantención con OpenAI (misma cascada de
/// modelos y reintentos que el Registro Inteligente de documentos). Lanza la
/// excepción si la IA falla: el llamador debe ofrecer el ingreso manual.
Future<MantencionExtraida> extraerMantencion({
  required Uint8List bytes,
  required String mimeType,
  List<ComponenteMantencion> componentes = componentesPorDefecto,
  OpenAiExtractionService? servicio,
  void Function(String etapa)? alCambiarEtapa,
}) async {
  // Imagen reducida, con orientación corregida y en JPEG de buena calidad.
  if (imagenRequierePreparacion(bytes, mimeType)) {
    alCambiarEtapa?.call(etapaPreparandoImagen);
    await Future.delayed(const Duration(milliseconds: 80));
  }
  final preparada = await prepararImagenParaIa(bytes, mimeType);
  alCambiarEtapa?.call(etapaAnalizando);

  final respuesta = await (servicio ?? OpenAiExtractionService())
      .generarJsonConFallback(
    partes: [
      EvidenciaArchivo(preparada.mimeType, preparada.bytes),
      EvidenciaTexto(_promptMantencion(componentes)),
    ],
    esquemaJson: _esquemaMantencion(componentes),
    nombreEsquema: 'mantencion',
  );

  final json = jsonDecode(respuesta);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Respuesta de la IA con formato inesperado.');
  }
  return parseMantencionExtraida(json, componentesValidos: componentes);
}
