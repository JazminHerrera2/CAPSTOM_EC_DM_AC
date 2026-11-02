import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/abastecimiento_model.dart';
import 'openai_extraction_service.dart';
import 'preparar_imagen.dart';
import 'validacion_campos.dart';

/// Claves de los campos que pueden quedar marcados como dudosos en la revisión.
const String dudosoCargaFecha = 'fecha';
const String dudosoCargaKilometraje = 'kilometraje';
const String dudosoCargaEstacion = 'estacion';
const String dudosoCargaCombustible = 'tipo_combustible';
const String dudosoCargaCantidad = 'cantidad';
const String dudosoCargaPrecio = 'precio_unitario';
const String dudosoCargaTotal = 'total';

const List<String> _clavesDudosas = [
  dudosoCargaFecha,
  dudosoCargaKilometraje,
  dudosoCargaEstacion,
  dudosoCargaCombustible,
  dudosoCargaCantidad,
  dudosoCargaPrecio,
  dudosoCargaTotal,
];

/// Combustibles que se le piden a la IA: los de la boleta de una bencinera, más
/// el eléctrico (un cargador también emite comprobante).
const List<String> _combustiblesIa = [
  ...combustiblesDeCarga,
  combustibleElectrico,
];

/// Datos que la IA reconoció en una boleta o factura de una estación de
/// servicio. Todos son opcionales: lo que no se lee con certeza queda en null y
/// el usuario lo completa en el formulario de revisión.
class AbastecimientoExtraido {
  final String? estacion;
  final DateTime? fecha;
  final TipoAbastecimiento? tipoAbastecimiento;
  final String? tipoCombustible;

  /// Litros o kWh, según [tipoAbastecimiento].
  final double? cantidad;
  final double? precioUnitario;
  final int? total;
  final int? kilometraje;

  /// Campos que la revisión debe resaltar: los que la IA leyó con dudas, el
  /// total si no cuadra con litros × precio y la fecha si no se pudo leer.
  final Set<String> camposDudosos;

  /// Proporción (0 a 1) de campos leídos sin duda. Null si no se leyó ninguno.
  final double? confianza;

  const AbastecimientoExtraido({
    this.estacion,
    this.fecha,
    this.tipoAbastecimiento,
    this.tipoCombustible,
    this.cantidad,
    this.precioUnitario,
    this.total,
    this.kilometraje,
    this.camposDudosos = const {},
    this.confianza,
  });

  /// `true` si la IA no logró leer ningún dato.
  bool get vacia =>
      estacion == null &&
      fecha == null &&
      tipoCombustible == null &&
      cantidad == null &&
      precioUnitario == null &&
      total == null &&
      kilometraje == null;
}

Map<String, dynamic> _campoTexto(String descripcion) => {
  'type': ['string', 'null'],
  'description': descripcion,
};

/// JSON Schema estricto de OpenAI: todo va en `required` y lo que no se lee
/// con certeza se devuelve como null.
Map<String, dynamic> _esquemaCombustible() {
  final properties = <String, dynamic>{
    'estacion_servicio': _campoTexto(
      'Nombre de la estación de servicio o marca (Copec, Shell, Petrobras, '
      'Aramco...), con la sucursal si aparece. Null si no se lee.',
    ),
    'fecha': _campoTexto(
      'Fecha de emisión del documento en formato YYYY-MM-DD.',
    ),
    'tipo_abastecimiento': {
      'type': ['string', 'null'],
      'enum': [...TipoAbastecimiento.values.map((t) => t.valorFirestore), null],
      'description':
          'combustible si se cargó en litros; carga_electrica si se cargó '
          'energía en kWh.',
    },
    'tipo_combustible': {
      'type': ['string', 'null'],
      'enum': [..._combustiblesIa, null],
      'description': 'Combustible cargado.',
    },
    'cantidad': _campoTexto(
      'Litros (o kWh en una carga eléctrica) cargados, como número decimal '
      'con punto, sin unidad (por ejemplo "32.451").',
    ),
    'precio_unitario': _campoTexto(
      'Precio por litro (o por kWh) en pesos chilenos, solo el número, con '
      'punto si tiene decimales (por ejemplo "1289" o "1289.9").',
    ),
    'total': _campoTexto(
      'Monto TOTAL pagado en pesos chilenos (solo el número).',
    ),
    'kilometraje': _campoTexto(
      'Kilometraje del vehículo si aparece (solo el número).',
    ),
    'campos_dudosos': {
      'type': 'array',
      'items': {'type': 'string', 'enum': _clavesDudosas},
      'description':
          'Campos que leíste pero de los que dudas. Lista vacía si no hay.',
    },
  };
  return {
    'type': 'object',
    'properties': properties,
    'required': properties.keys.toList(),
    'additionalProperties': false,
  };
}

String _promptCombustible() => '''
Eres un asistente experto en boletas y facturas de estaciones de servicio
(bencineras) chilenas. Analiza el comprobante recibido (imagen o PDF) de una
carga de combustible y extrae solo los campos que se piden.

Extrae únicamente lo que puedas reconocer con certeza. Si un dato no es
legible o no aparece, devuélvelo como null: nunca inventes ni infieras un
valor. Si lees un dato pero dudas de él (foto torcida o borrosa, cifras que no
cuadran), devuélvelo igual e inclúyelo en "campos_dudosos".

Reglas:
- "estacion_servicio": el nombre de la estación o de la marca del membrete (la
  que emite el documento), no el del cliente.
- "fecha": la fecha de EMISIÓN del documento (no la de hoy), en formato
  "YYYY-MM-DD". Los documentos chilenos escriben día/mes/año ("05/03/2026" o
  "05-03-2026" es el 5 de marzo de 2026, no el 3 de mayo).
- "tipo_combustible": elige el de la lista según lo que dice la boleta
  ("93", "95", "97", "Diésel", "GLP"). Si solo dice "Bencina" o "Gasolina" sin
  octanaje, devuelve null.
- "tipo_abastecimiento": "combustible" para litros; "carga_electrica" solo si
  la cantidad está en kWh.
- "cantidad": los litros cargados (o kWh), como número decimal con PUNTO como
  separador decimal y sin separador de miles. En Chile los litros suelen
  llevar decimales: "32,451 lts" o "32.451 L" es 32.451 litros (nunca treinta y
  dos mil). Si el documento muestra "45,00 L", es 45.00.
- "precio_unitario": el precio por litro (o por kWh) en pesos chilenos, solo
  números ("1.289" o "\$1289 / L" es 1289). Es el valor por unidad, no el total.
- "total": el TOTAL pagado en pesos chilenos, solo con números. En Chile el
  punto separa los miles ("45.990" son cuarenta y cinco mil novecientos
  noventa pesos). No uses un subtotal, el neto ni el IVA.
- "kilometraje": solo si aparece explícito ("KM", "Kilometraje", "Odómetro"),
  solo con números. No lo confundas con el número de surtidor, el folio, la
  patente ni el RUT. Casi nunca viene: en ese caso, null.
- "campos_dudosos": los campos que leíste pero de los que dudas (puede ser una
  lista vacía).
- Privacidad: ignora y no devuelvas datos personales del cliente (nombre, RUT,
  domicilio, teléfono ni patente). Solo se extraen los campos de esta lista.''';

int? _entero(Object? valor) {
  if (valor == null) return null;
  var texto = valor.toString().trim();
  // Descarta decimales ("45000,50" / "45000.5") antes de quitar separadores
  // de miles ("45.000").
  texto = texto.replaceFirst(RegExp(r'[,.]\d{1,2}$'), '');
  final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  return digitos.isEmpty ? null : int.tryParse(digitos);
}

/// Número decimal tal como lo pide el prompt (punto decimal), tolerando que la
/// IA devuelva coma decimal ("32,451") o miles con punto y decimales con coma
/// ("1.289,9").
double? decimalDeTexto(Object? valor) {
  if (valor == null) return null;
  var t = valor.toString().trim().replaceAll(RegExp(r'[^0-9.,]'), '');
  if (t.isEmpty) return null;
  final ultimaComa = t.lastIndexOf(',');
  final ultimoPunto = t.lastIndexOf('.');
  if (ultimaComa >= 0 && ultimoPunto >= 0) {
    // Los dos separadores: el último es el decimal, el otro agrupa miles.
    final decimal = ultimaComa > ultimoPunto ? ',' : '.';
    final miles = decimal == ',' ? '.' : ',';
    t = t.replaceAll(miles, '').replaceAll(decimal, '.');
  } else if (ultimaComa >= 0) {
    t = t.replaceAll(',', '.');
  }
  // Varios puntos solos: son separadores de miles ("1.234.567").
  if (RegExp(r'\..*\.').hasMatch(t)) t = t.replaceAll('.', '');
  return double.tryParse(t);
}

/// Una carga no puede ser futura (se tolera 1 día por la zona horaria) ni
/// anterior a 1990: una fecha así es casi seguro un error de lectura.
DateTime? _fechaPlausible(DateTime? fecha, {DateTime? ahora}) {
  if (fecha == null) return null;
  final hoy = ahora ?? DateTime.now();
  final limite = DateTime(
    hoy.year,
    hoy.month,
    hoy.day,
  ).add(const Duration(days: 1));
  return (fecha.year < 1990 || fecha.isAfter(limite)) ? null : fecha;
}

String? _texto(Object? valor, int maximo) {
  final t = valor?.toString().trim() ?? '';
  if (t.isEmpty) return null;
  return t.length > maximo ? t.substring(0, maximo) : t;
}

/// `true` si litros × precio ≈ total. La tolerancia es la mayor entre $10 y el
/// 1% del total, para no alertar por el redondeo del precio por litro.
bool totalCuadraConCantidad({
  required double cantidad,
  required double precioUnitario,
  required int total,
}) {
  final tolerancia = total * 0.01 > 10 ? total * 0.01 : 10;
  return (cantidad * precioUnitario - total).abs() <= tolerancia;
}

/// Interpreta el JSON de la IA. Los rangos coinciden con las reglas de
/// Firestore (`abastecimientoValido`), para que lo extraído siempre se pueda
/// guardar. Un valor fuera de rango se descarta.
AbastecimientoExtraido parseAbastecimientoExtraido(
  Map<String, dynamic> json, {
  DateTime? ahora,
}) {
  final fechaTexto = json['fecha']?.toString().trim() ?? '';
  final fecha = _fechaPlausible(
    fechaTexto.isEmpty ? null : interpretarFecha(fechaTexto),
    ahora: ahora,
  );

  final cantidadLeida = decimalDeTexto(json['cantidad']);
  final cantidad =
      (cantidadLeida != null && cantidadLeida > 0 && cantidadLeida <= 100000)
      ? cantidadLeida
      : null;
  final precioLeido = decimalDeTexto(json['precio_unitario']);
  final precio =
      (precioLeido != null && precioLeido > 0 && precioLeido <= 1000000)
      ? precioLeido
      : null;
  final totalLeido = _entero(json['total']);
  final total = (totalLeido != null && totalLeido <= 1000000000)
      ? totalLeido
      : null;
  final km = _entero(json['kilometraje']);
  final kilometraje = (km != null && km <= 5000000) ? km : null;

  final estacion = _texto(json['estacion_servicio'], 100);

  final combustibleRaw = json['tipo_combustible']?.toString();
  final combustible = _combustiblesIa.contains(combustibleRaw)
      ? combustibleRaw
      : null;

  // El tipo lo dice la IA; si no, se deduce del combustible (eléctrico o no).
  final tipoRaw = json['tipo_abastecimiento']?.toString();
  final tipo =
      TipoAbastecimiento.values
          .where((t) => t.valorFirestore == tipoRaw)
          .firstOrNull ??
      (combustible == null
          ? null
          : (combustible == combustibleElectrico
                ? TipoAbastecimiento.cargaElectrica
                : TipoAbastecimiento.combustible));

  // Campos que la revisión debe resaltar.
  final dudosos = <String>{
    for (final c
        in json['campos_dudosos'] is List
            ? json['campos_dudosos'] as List
            : const [])
      if (_clavesDudosas.contains(c.toString())) c.toString(),
  };
  // La fecha es obligatoria: si no se pudo leer, se destaca.
  if (fecha == null) dudosos.add(dudosoCargaFecha);
  // Litros × precio no cuadran con el total: no se elige uno, se marca.
  if (cantidad != null &&
      precio != null &&
      total != null &&
      !totalCuadraConCantidad(
        cantidad: cantidad,
        precioUnitario: precio,
        total: total,
      )) {
    dudosos.add(dudosoCargaTotal);
  }

  // Confianza: proporción de campos leídos que no quedaron dudosos.
  final leidos = <String>[
    if (fecha != null) dudosoCargaFecha,
    if (kilometraje != null) dudosoCargaKilometraje,
    if (estacion != null) dudosoCargaEstacion,
    if (combustible != null) dudosoCargaCombustible,
    if (cantidad != null) dudosoCargaCantidad,
    if (precio != null) dudosoCargaPrecio,
    if (total != null) dudosoCargaTotal,
  ];
  final confianza = leidos.isEmpty
      ? null
      : leidos.where((c) => !dudosos.contains(c)).length / leidos.length;

  return AbastecimientoExtraido(
    estacion: estacion,
    fecha: fecha,
    tipoAbastecimiento: tipo,
    tipoCombustible: combustible,
    cantidad: cantidad,
    precioUnitario: precio,
    total: total,
    kilometraje: kilometraje,
    camposDudosos: dudosos,
    confianza: confianza,
  );
}

/// Lee una boleta o factura de una estación de servicio con OpenAI (misma
/// cascada de modelos y reintentos que el Registro Inteligente de documentos).
/// Lanza la excepción si la IA falla: el llamador debe ofrecer el ingreso
/// manual.
Future<AbastecimientoExtraido> extraerAbastecimiento({
  required Uint8List bytes,
  required String mimeType,
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
          EvidenciaTexto(_promptCombustible()),
        ],
        esquemaJson: _esquemaCombustible(),
        nombreEsquema: 'abastecimiento',
      );

  final json = jsonDecode(respuesta);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Respuesta de la IA con formato inesperado.');
  }
  return parseAbastecimientoExtraido(json);
}
