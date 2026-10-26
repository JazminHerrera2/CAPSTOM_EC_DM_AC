import 'dart:convert';
import 'dart:typed_data';

import 'openai_extraction_service.dart';
import 'preparar_imagen.dart';
import 'validacion_campos.dart';

/// Tipos de vehículo del formulario de Mi Vehículo (mismos valores que usa
/// `RegistrarEditarVehiculoScreen`).
const List<String> tiposVehiculoExtraibles = ['AUTO', 'CAMIONETA', 'MOTO'];

/// Datos del vehículo que la IA reconoció en un documento (permiso de
/// circulación, certificado de inscripción, etc.). Todos son opcionales: lo
/// que no se lee con certeza queda en null y el usuario lo completa en el
/// formulario de revisión.
class VehiculoExtraido {
  final String? patente;
  final String? marca;
  final String? modelo;
  final int? anio;

  /// 'AUTO', 'CAMIONETA' o 'MOTO'.
  final String? tipoVehiculo;
  final String? tipoCombustible;

  const VehiculoExtraido({
    this.patente,
    this.marca,
    this.modelo,
    this.anio,
    this.tipoVehiculo,
    this.tipoCombustible,
  });

  /// `true` si la IA no logró leer ningún dato.
  bool get vacio =>
      patente == null &&
      marca == null &&
      modelo == null &&
      anio == null &&
      tipoVehiculo == null &&
      tipoCombustible == null;
}

/// Combustibles que se le piden a la IA (texto que ve el usuario).
const List<String> combustiblesExtraibles = [
  'Gasolina',
  'Diésel',
  'Eléctrico',
  'Híbrido',
  'Gas',
];

Map<String, dynamic> _campoTexto(String descripcion) => {
      'type': ['string', 'null'],
      'description': descripcion,
    };

/// JSON Schema estricto de OpenAI: todo va en `required` y lo que no se lee
/// con certeza se devuelve como null.
final Map<String, dynamic> _esquemaVehiculo = () {
  final properties = <String, dynamic>{
    'patente': _campoTexto(
      'Placa patente única del vehículo, en mayúsculas y sin guiones.',
    ),
    'marca': _campoTexto('Marca del vehículo (ej. Kia, Toyota).'),
    'modelo': _campoTexto('Modelo del vehículo, tal como aparece.'),
    'anio': _campoTexto(
      'Año de fabricación del vehículo (4 dígitos), no el año del permiso.',
    ),
    'tipo_vehiculo': {
      'type': ['string', 'null'],
      'enum': [...tiposVehiculoExtraibles, null],
      'description': 'Clase del vehículo.',
    },
    'tipo_combustible': {
      'type': ['string', 'null'],
      'enum': [...combustiblesExtraibles, null],
      'description': 'Combustible del vehículo.',
    },
  };
  return {
    'type': 'object',
    'properties': properties,
    'required': properties.keys.toList(),
    'additionalProperties': false,
  };
}();

const String _promptVehiculo = '''
Eres un asistente experto en documentos vehiculares chilenos. Analiza el
documento recibido (imagen o PDF) de un vehículo y extrae sus datos. Lo
habitual es el padrón (certificado de inscripción y anotaciones vigentes del
Registro Civil), pero también puede ser un permiso de circulación u otro
documento del vehículo.

Extrae únicamente lo que puedas reconocer con certeza. Si un dato no es
legible o no aparece, devuélvelo como null: nunca inventes ni infieras un
valor.

Reglas:
- "patente": la placa patente única en MAYÚSCULAS y sin guiones, puntos ni
  espacios. Si va seguida de un guion y un dígito verificador (ej. "KZZZ60-0"),
  ignora ese dígito: la patente es "KZZZ60". Ten cuidado de no confundir "0"
  con "O", "1" con "I", "5" con "S" ni "8" con "B".
- "marca": solo la marca, sin razón social ni "MOTORS" o "S.A." (ej.
  "KIA MOTORS" es "Kia", "MITSUBISHI" es "Mitsubishi").
- "modelo": el modelo tal como aparece (puede incluir la versión, ej.
  "RIO 4 LX 1.4L 6").
- "anio": el año del VEHÍCULO (año de fabricación o del modelo), con 4
  dígitos. En el padrón se rotula "Año"; los permisos de circulación traen además el "AÑO" del propio
  permiso (ej. "PERMISO DE CIRCULACION AÑO 2026"): ese NO es el año del
  vehículo. El del vehículo suele estar junto a la marca y el modelo.
- "tipo_vehiculo": "AUTO" para automóvil, station wagon, SUV, jeep o similares;
  "CAMIONETA" para camioneta, furgón o camión liviano; "MOTO" para motocicleta.
- "tipo_combustible": elige entre Gasolina, Diésel, Eléctrico, Híbrido o Gas.
  Los documentos suelen abreviarlo con una letra o palabra: "B", "Bencina" o
  "Gasolina" es Gasolina; "D", "Diesel" o "Petróleo" es Diésel; "E" o
  "Eléctrico" es Eléctrico; "H" o "Híbrido" es Híbrido; "G" o "Gas" es Gas.
- No extraigas datos del propietario (nombre, RUT ni dirección).''';

String? _texto(Object? valor, int maximo) {
  final t = valor?.toString().trim() ?? '';
  if (t.isEmpty) return null;
  return t.length > maximo ? t.substring(0, maximo) : t;
}

/// Interpreta el JSON de la IA. Lo que no sea válido se descarta (queda
/// vacío para que el usuario lo escriba): una patente sin formato chileno
/// igual se conserva para que pueda corregirla.
VehiculoExtraido parseVehiculoExtraido(
  Map<String, dynamic> json, {
  DateTime? ahora,
}) {
  final hoy = ahora ?? DateTime.now();

  final patenteRaw = _texto(json['patente'], 20);
  final patente = patenteRaw == null ? null : normalizarPatente(patenteRaw);

  final anioTexto = (json['anio']?.toString() ?? '').replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
  final anio = int.tryParse(anioTexto);

  final tipoRaw = json['tipo_vehiculo']?.toString().toUpperCase();
  final combustibleRaw = json['tipo_combustible']?.toString();

  return VehiculoExtraido(
    patente: (patente == null || patente.isEmpty) ? null : patente,
    marca: _texto(json['marca'], 100),
    modelo: _texto(json['modelo'], 100),
    anio: (anio != null && anio >= 1900 && anio <= hoy.year + 1) ? anio : null,
    tipoVehiculo: tiposVehiculoExtraibles.contains(tipoRaw) ? tipoRaw : null,
    tipoCombustible: combustiblesExtraibles.contains(combustibleRaw)
        ? combustibleRaw
        : null,
  );
}

/// Lee un documento del vehículo con OpenAI (misma cascada de modelos y
/// reintentos que el resto del Registro Inteligente). Lanza la excepción si la
/// IA falla: el llamador debe ofrecer el ingreso manual.
Future<VehiculoExtraido> extraerVehiculo({
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
      EvidenciaTexto(_promptVehiculo),
    ],
    esquemaJson: _esquemaVehiculo,
    nombreEsquema: 'vehiculo',
  );

  final json = jsonDecode(respuesta);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Respuesta de la IA con formato inesperado.');
  }
  return parseVehiculoExtraido(json);
}
