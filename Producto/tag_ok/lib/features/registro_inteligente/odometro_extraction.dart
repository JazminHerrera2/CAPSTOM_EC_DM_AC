import 'dart:convert';
import 'dart:typed_data';

import 'openai_extraction_service.dart';
import 'preparar_imagen.dart';

/// Kilometraje máximo que se acepta (mismo tope que las reglas de Firestore
/// para el vehículo: 10.000.000; acá se es más estricto con lo que lee la IA).
const int kilometrajeMaximoLeido = 5000000;

Map<String, dynamic> get _esquemaOdometro => {
      'type': 'object',
      'properties': {
        'kilometraje': {
          'type': ['string', 'null'],
          'description':
              'Kilometraje total del odómetro (solo dígitos), o null si no se lee.',
        },
        'unidad': {
          'type': ['string', 'null'],
          'enum': ['km', 'mi', null],
          'description': 'Unidad que indica el tablero: km o mi (millas).',
        },
      },
      'required': ['kilometraje', 'unidad'],
      'additionalProperties': false,
    };

const String _promptOdometro = '''
Recibes la foto del tablero (velocímetro) de un vehículo. Lee el KILOMETRAJE
TOTAL del odómetro.

Reglas:
- Es el contador acumulado del vehículo, normalmente de 5 a 7 dígitos, con la
  etiqueta "ODO" o la unidad "km". Puede ser una pantalla digital o un
  contador de rodillos.
- NO uses el cuentakilómetros parcial ("TRIP", "TRIP A", "TRIP B", "A", "B"),
  ni la velocidad actual, ni la autonomía, ni el nivel de combustible, ni la
  hora ni la temperatura.
- Devuelve solo los dígitos del kilometraje, sin puntos, comas ni unidad. Si
  hay un decimal separado (ej. "123456.7"), descártalo y devuelve "123456".
- "unidad": "km" o "mi" según lo que indique el tablero. Si no se ve, null.
- Si la foto no muestra un odómetro legible, o hay varias cifras y no puedes
  saber cuál es el total, devuelve null: nunca inventes un valor.''';

/// Resultado de leer el odómetro.
typedef LecturaOdometro = ({int? kilometraje, bool enMillas});

/// Interpreta el JSON de la IA. Descarta lo que no sea un número plausible.
LecturaOdometro parseOdometro(Map<String, dynamic> json) {
  final enMillas = json['unidad']?.toString() == 'mi';
  var texto = (json['kilometraje']?.toString() ?? '').trim();
  // Decimal separado ("123456.7" / "123456,7"): se descarta antes de quitar
  // separadores de miles ("123.456").
  texto = texto.replaceFirst(RegExp(r'[,.]\d{1}$'), '');
  final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  final km = digitos.isEmpty ? null : int.tryParse(digitos);
  return (
    kilometraje: (km != null && km <= kilometrajeMaximoLeido) ? km : null,
    enMillas: enMillas,
  );
}

/// Lee el kilometraje de la foto de un velocímetro con OpenAI. Devuelve null
/// si no se pudo leer, o si el tablero está en millas (el usuario debe
/// ingresarlo a mano). Lanza la excepción si la IA falla.
Future<int?> extraerKilometraje({
  required Uint8List bytes,
  required String mimeType,
  OpenAiExtractionService? servicio,
}) async {
  final preparada = await prepararImagenParaIa(bytes, mimeType);

  final respuesta = await (servicio ?? OpenAiExtractionService())
      .generarJsonConFallback(
    partes: [
      EvidenciaArchivo(preparada.mimeType, preparada.bytes),
      EvidenciaTexto(_promptOdometro),
    ],
    esquemaJson: _esquemaOdometro,
    nombreEsquema: 'odometro',
  );

  final json = jsonDecode(respuesta);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Respuesta de la IA con formato inesperado.');
  }
  final lectura = parseOdometro(json);
  return lectura.enMillas ? null : lectura.kilometraje;
}
