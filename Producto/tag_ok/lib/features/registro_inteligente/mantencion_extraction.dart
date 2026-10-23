import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/componente_mantencion_model.dart';
import '../../data/models/mantencion_model.dart';
import '../../data/models/tipo_mantencion.dart';
import '../../utils/validaciones_mantencion.dart';
import 'openai_extraction_service.dart';
import 'preparar_imagen.dart';
import 'validacion_campos.dart';

/// Claves de los campos que pueden quedar marcados como dudosos en la revisión.
const String dudosoFecha = 'fecha';
const String dudosoKilometraje = 'kilometraje';
const String dudosoTaller = 'taller';
const String dudosoCosto = 'costo';
const String dudosoTipo = 'tipo';
const String dudosoNumero = 'numero_comprobante';
const String dudosoDescripcion = 'descripcion';

const List<String> _clavesDudosas = [
  dudosoFecha,
  dudosoKilometraje,
  dudosoTaller,
  dudosoCosto,
  dudosoTipo,
  dudosoNumero,
  dudosoDescripcion,
];

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

  /// Campos que la revisión debe resaltar: los que la IA leyó con dudas, el
  /// costo si no cuadra con el neto, y la fecha o el costo si no se pudieron
  /// leer (son obligatorios).
  final Set<String> camposDudosos;

  /// Proporción (0 a 1) de campos leídos sin duda, igual que en documentos.
  /// Null si no se leyó ninguno.
  final double? confianza;

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
    this.camposDudosos = const {},
    this.confianza,
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
    'fecha': _campoTexto('Fecha de emisión del documento en formato YYYY-MM-DD.'),
    'kilometraje': _campoTexto('Kilometraje del vehículo (solo el número).'),
    'taller': _campoTexto('Nombre del taller o proveedor que emite el documento.'),
    'costo': _campoTexto('Monto TOTAL con IVA en pesos chilenos (solo el número).'),
    'neto': _campoTexto(
      'Monto neto (antes de IVA) en pesos chilenos, solo para verificar el total.',
    ),
    'descripcion': _campoTexto(
      'Resumen corto (máximo 200 caracteres) de los trabajos y repuestos.',
    ),
    'tipo_comprobante': {
      'type': ['string', 'null'],
      'enum': [...TipoComprobante.values.map((t) => t.valorFirestore), null],
      'description': 'Tipo de documento tributario: boleta, factura u otro.',
    },
    'numero_comprobante': _campoTexto(
      'Número (folio) del comprobante, solo el número.',
    ),
    'campos_dudosos': {
      'type': 'array',
      'items': {'type': 'string', 'enum': _clavesDudosas},
      'description':
          'Campos que leíste pero de los que dudas. Lista vacía si no hay.',
    },
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
vehicular y extrae solo los campos que se piden.

Extrae únicamente lo que puedas reconocer con certeza. Si un dato no es
legible o no aparece, devuélvelo como null: nunca inventes ni infieras un
valor. Si lees un dato pero dudas de él (foto torcida o borrosa, cifras que no
cuadran), devuélvelo igual e inclúyelo en "campos_dudosos".

Reglas:
- "fecha": la fecha de EMISIÓN del documento (no la de hoy), en formato
  "YYYY-MM-DD". Los documentos chilenos escriben día/mes/año ("05/03/2026" o
  "05-03-2026" es el 5 de marzo de 2026, no el 3 de mayo) o con el mes en
  palabras ("28 de octubre de 2020" es 2020-10-28).
- "costo": el TOTAL pagado, con IVA incluido (la línea "Total"), en pesos
  chilenos, solo con números. En Chile el punto separa los miles ("45.990" son
  cuarenta y cinco mil novecientos noventa pesos). No uses un subtotal, el neto
  ni el IVA. Si el total también está escrito en letras ("SON: ..."), úsalo
  solo para verificar la cifra.
- "neto": el monto NETO (antes de IVA), si aparece. Solo se usa para verificar
  el total.
- "taller": el nombre de la empresa del membrete (la que emite el documento),
  no el del cliente. Una línea del detalle como "Mecánica Ford Liviano" o "Mano
  de obra" es un servicio, no el taller.
- "tipo_mantencion": elige la opción que mejor describa el servicio:

$tipos

  Clasifica por el insumo o repuesto principal: el de mayor valor, sin contar
  la mano de obra. Los productos de limpieza o accesorios ("limpia frenos",
  "limpia parabrisas", "agua desmineralizada") no definen el tipo: "limpia
  frenos" NO es "frenos". Si hay varios trabajos de naturaleza distinta, usa
  "revision_general". Usa "otra" solo si ninguna aplica e indica "tipo_otro".
- "descripcion": un resumen corto (máximo 200 caracteres) de los trabajos y
  repuestos principales. No reconstruyas los ítems línea por línea.
- "kilometraje": solo si aparece explícito en el documento ("KM",
  "Kilometraje"), solo con números. No lo confundas con el folio, la patente,
  el RUT ni la orden de trabajo. Casi nunca viene: en ese caso, null.
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
- "campos_dudosos": los campos que leíste pero de los que dudas (puede ser una
  lista vacía).
- Privacidad: ignora y no devuelvas datos personales del cliente (nombre, RUT,
  domicilio ni teléfono). Solo se extraen los campos de esta lista.''';
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
  final costoLeido = _entero(json['costo']);
  final costo =
      (costoLeido != null && costoLeido <= 1000000000) ? costoLeido : null;
  final neto = _entero(json['neto']);

  // Lector común de fechas: entiende "2020-10-28", "28/10/2020",
  // "28-10-2020" y "28 de octubre de 2020".
  final fechaTexto = json['fecha']?.toString().trim() ?? '';
  final fecha = _fechaPlausible(
    fechaTexto.isEmpty ? null : interpretarFecha(fechaTexto),
  );

  final kilometraje = (km != null && km <= 5000000) ? km : null;
  final taller = _texto(json['taller'], 100);
  final descripcion = _texto(json['descripcion'], 500);
  final numero = _folio(json['numero_comprobante']);

  // Campos que la revisión debe resaltar.
  final dudosos = <String>{
    for (final c in json['campos_dudosos'] is List
        ? json['campos_dudosos'] as List
        : const [])
      if (_clavesDudosas.contains(c.toString())) c.toString(),
  };
  // Fecha y costo son obligatorios: si no se pudieron leer, se destacan.
  if (fecha == null) dudosos.add(dudosoFecha);
  if (costo == null) dudosos.add(dudosoCosto);
  // El total no cuadra con el neto: no se elige uno, se marca para revisar.
  if (costo != null &&
      neto != null &&
      !totalCuadraConNeto(total: costo, neto: neto)) {
    dudosos.add(dudosoCosto);
  }

  // Confianza: proporción de campos leídos que no quedaron dudosos.
  final leidos = <String>[
    if (fecha != null) dudosoFecha,
    if (kilometraje != null) dudosoKilometraje,
    if (taller != null) dudosoTaller,
    if (costo != null) dudosoCosto,
    if (tipo != null) dudosoTipo,
    if (numero != null) dudosoNumero,
    if (descripcion != null) dudosoDescripcion,
  ];
  final confianza = leidos.isEmpty
      ? null
      : leidos.where((c) => !dudosos.contains(c)).length / leidos.length;

  return MantencionExtraida(
    tipo: tipo,
    tipoOtro:
        tipo == TipoMantencion.otra ? _texto(json['tipo_otro'], 100) : null,
    fecha: fecha,
    kilometraje: kilometraje,
    taller: taller,
    costo: costo,
    descripcion: descripcion,
    tipoComprobante:
        TipoComprobante.fromFirestore(json['tipo_comprobante']?.toString()),
    numeroComprobante: numero,
    componentes: componentes,
    camposDudosos: dudosos,
    confianza: confianza,
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
