import 'dart:convert';
import 'dart:typed_data';

import 'openai_extraction_service.dart';
import 'preparar_imagen.dart';

const String dudosoEstacionamientoLugar = 'lugar';
const String dudosoEstacionamientoFecha = 'fecha';
const String dudosoEstacionamientoTotal = 'total';

const List<String> _clavesDudosas = [
  dudosoEstacionamientoLugar,
  dudosoEstacionamientoFecha,
  dudosoEstacionamientoTotal,
];

class EstacionamientoExtraido {
  final String? lugar;
  final DateTime? fecha;
  final int? total;
  final Set<String> camposDudosos;
  final double? confianza;

  const EstacionamientoExtraido({
    this.lugar,
    this.fecha,
    this.total,
    this.camposDudosos = const {},
    this.confianza,
  });

  bool get vacia => lugar == null && fecha == null && total == null;
}

Map<String, dynamic> _esquemaEstacionamiento() {
  final propiedades = <String, dynamic>{
    'lugar': {
      'type': ['string', 'null'],
      'description': 'Nombre del estacionamiento o establecimiento que emitió el comprobante. Null si no se distingue.',
    },
    'fecha': {
      'type': ['string', 'null'],
      'description': 'Fecha de emisión del comprobante en formato YYYY-MM-DD. Null si no aparece o no se lee.',
    },
    'total': {
      'type': ['string', 'null'],
      'description': 'Monto total efectivamente pagado en pesos chilenos, sin símbolo monetario. Null si no se distingue.',
    },
    'campos_dudosos': {
      'type': 'array',
      'items': {'type': 'string', 'enum': _clavesDudosas},
      'description': 'Campos cuya lectura es incierta. Lista vacía si no hay dudas.',
    },
  };

  return {
    'type': 'object',
    'properties': propiedades,
    'required': propiedades.keys.toList(),
    'additionalProperties': false,
  };
}

String _promptEstacionamiento() => '''
Analiza esta boleta o factura de estacionamiento emitida en Chile.
Extrae exclusivamente el nombre del establecimiento emisor, la fecha de emisión y el total pagado.
Nunca inventes datos ni deduzcas un valor que no aparezca en el documento.
Si no puedes leer un campo, devuelve null. Si lo lees con dudas, inclúyelo en campos_dudosos.
Reglas:
- lugar: nombre del estacionamiento o establecimiento emisor; no el nombre del cliente.
- fecha: fecha de EMISIÓN, no la fecha de entrada o salida del vehículo. Devuelve YYYY-MM-DD. Interpreta DD/MM/YYYY como día/mes/año.
- total: monto TOTAL PAGADO en pesos chilenos, no subtotal, neto, IVA, tarifa por minuto, saldo o vuelto. En Chile el punto suele separar miles ("3.500" = 3500 pesos).
- Si el documento no corresponde claramente a un estacionamiento, devuelve null en los campos que no puedas respaldar.
- Ignora datos personales del cliente, RUT, patente, teléfonos y direcciones particulares.
''';

String? _texto(Object? valor, int maximo) {
  final texto = valor?.toString().trim() ?? '';
  if (texto.isEmpty) return null;
  return texto.length > maximo ? texto.substring(0, maximo) : texto;
}

int? _pesos(Object? valor) {
  if (valor == null) return null;
  var texto = valor.toString().trim().replaceAll(RegExp(r'[^0-9,.]'), '');
  if (texto.isEmpty) return null;
  // El monto en CLP se almacena como entero; elimina centavos explícitos.
  if (RegExp(r'[,.][0-9]{1,2}$').hasMatch(texto)) {
    texto = texto.replaceFirst(RegExp(r'[,.][0-9]{1,2}$'), '');
  }
  final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  return digitos.isEmpty ? null : int.tryParse(digitos);
}

DateTime? _fecha(Object? valor, DateTime ahora) {
  final texto = valor?.toString().trim() ?? '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(texto);
  if (match == null) return null;
  final anio = int.parse(match.group(1)!);
  final mes = int.parse(match.group(2)!);
  final dia = int.parse(match.group(3)!);
  final fecha = DateTime(anio, mes, dia);
  if (fecha.year != anio || fecha.month != mes || fecha.day != dia) return null;
  if (anio < 1990 || fecha.isAfter(DateTime(ahora.year, ahora.month, ahora.day).add(const Duration(days: 1)))) {
    return null;
  }
  return fecha;
}

EstacionamientoExtraido parseEstacionamientoExtraido(
  Map<String, dynamic> json, {
  DateTime? ahora,
}) {
  final lugar = _texto(json['lugar'], 120);
  final fecha = _fecha(json['fecha'], ahora ?? DateTime.now());
  final montoLeido = _pesos(json['total']);
  final total = montoLeido != null && montoLeido >= 0 && montoLeido <= 1000000000
      ? montoLeido
      : null;

  final dudosos = <String>{
    for (final campo in json['campos_dudosos'] is List
        ? json['campos_dudosos'] as List
        : const [])
      if (_clavesDudosas.contains(campo.toString())) campo.toString(),
  };

  if (json['fecha'] != null && fecha == null) dudosos.add(dudosoEstacionamientoFecha);
  if (json['total'] != null && total == null) dudosos.add(dudosoEstacionamientoTotal);

  final leidos = <String>[
    if (lugar != null) dudosoEstacionamientoLugar,
    if (fecha != null) dudosoEstacionamientoFecha,
    if (total != null) dudosoEstacionamientoTotal,
  ];
  final confianza = leidos.isEmpty
      ? null
      : leidos.where((campo) => !dudosos.contains(campo)).length / leidos.length;

  return EstacionamientoExtraido(
    lugar: lugar,
    fecha: fecha,
    total: total,
    camposDudosos: dudosos,
    confianza: confianza,
  );
}

Future<EstacionamientoExtraido> extraerEstacionamiento({
  required Uint8List bytes,
  required String mimeType,
  OpenAiExtractionService? servicio,
  void Function(String etapa)? alCambiarEtapa,
}) async {
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
          EvidenciaTexto(_promptEstacionamiento()),
        ],
        esquemaJson: _esquemaEstacionamiento(),
        nombreEsquema: 'estacionamiento',
      );

  final json = jsonDecode(respuesta);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Respuesta de la IA con formato inesperado.');
  }
  return parseEstacionamientoExtraido(json);
}
