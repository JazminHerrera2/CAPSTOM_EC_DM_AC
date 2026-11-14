import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../entorno.dart';

/// Esperas entre los reintentos de un mismo modelo ante un error temporal del
/// servidor (1s, 2s, 4s): una llamada inicial + hasta 3 reintentos.
const List<Duration> esperasReintento503 = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

/// Error devuelto por la API de OpenAI (respuesta HTTP distinta de 200).
class OpenAiException implements Exception {
  final int statusCode;
  final String message;

  const OpenAiException(this.statusCode, this.message);

  @override
  String toString() => 'OpenAiException [$statusCode]: $message';
}

/// `true` si [error] es un problema temporal de OpenAI que suele resolverse
/// solo: servidor saturado o caído (500/502/503/504) o límite de velocidad
/// (429). Un 429 por cuota agotada (`insufficient_quota`) NO es temporal, ni
/// un 500 de la Edge Function por un secreto faltante (`configuracion_servidor`).
///
/// Los demás errores (401, 400, 404, etc.) no se resuelven reintentando.
bool esErrorNoDisponible503(Object error) {
  if (error is! OpenAiException) return false;
  if (error.message.contains('insufficient_quota') ||
      error.message.contains('configuracion_servidor')) {
    return false;
  }

  const temporales = {429, 500, 502, 503, 504};
  return temporales.contains(error.statusCode);
}

/// `true` si [error] no se arregla probando otro modelo ni repitiendo el ciclo:
/// clave inválida, sesión vencida o sin permisos (401/403), cuota agotada o
/// falta un secreto en la Edge Function (`configuracion_servidor`). Ahí se
/// corta de inmediato en vez de insistir.
bool esErrorFatalOpenAi(Object error) {
  if (error is! OpenAiException) return false;
  return error.statusCode == 401 ||
      error.statusCode == 403 ||
      error.message.contains('insufficient_quota') ||
      error.message.contains('configuracion_servidor');
}

/// URL de la Edge Function `ia-extraccion` a partir de [supabaseUrl], o null
/// si no es una URL https.
Uri? endpointIaExtraccion(String? supabaseUrl) {
  final base = (supabaseUrl ?? '').trim().replaceAll(RegExp(r'/+$'), '');
  if (!base.startsWith('https://')) return null;
  return Uri.parse('$base/functions/v1/ia-extraccion');
}

/// Ejecuta [accion] y, si falla con un error temporal, la reintenta esperando
/// [esperas] entre intentos (backoff exponencial). Cualquier otro error se
/// relanza de inmediato, sin reintentar. Si se agotan los reintentos, relanza
/// el último error.
///
/// [esperar] solo existe para poder probarlo sin demorar de verdad.
Future<T> reintentarSiNoDisponible<T>(
  Future<T> Function() accion, {
  List<Duration> esperas = esperasReintento503,
  Future<void> Function(Duration) esperar = _esperarReal,
  void Function(int reintento, Object error)? alReintentar,
}) async {
  for (var reintento = 0;; reintento++) {
    try {
      return await accion();
    } catch (e) {
      if (!esErrorNoDisponible503(e) || reintento >= esperas.length) {
        rethrow;
      }
      alReintentar?.call(reintento + 1, e);
      await esperar(esperas[reintento]);
    }
  }
}

Future<void> _esperarReal(Duration duracion) => Future.delayed(duracion);

/// Una pieza de evidencia que se envía a la IA: texto, imagen o archivo PDF.
sealed class EvidenciaIa {
  const EvidenciaIa();
}

class EvidenciaTexto extends EvidenciaIa {
  final String texto;
  const EvidenciaTexto(this.texto);
}

/// Archivo adjunto (imagen o PDF). Cualquier otro tipo no lo lee la IA.
class EvidenciaArchivo extends EvidenciaIa {
  final String mimeType;
  final Uint8List bytes;
  final String nombre;

  const EvidenciaArchivo(this.mimeType, this.bytes, {this.nombre = 'documento.pdf'});
}

/// Convierte la evidencia al formato `content` de la API Chat Completions.
List<Map<String, dynamic>> construirContenido(Iterable<EvidenciaIa> partes) {
  return [
    for (final parte in partes)
      switch (parte) {
        EvidenciaTexto(:final texto) => {'type': 'text', 'text': texto},
        EvidenciaArchivo(:final mimeType, :final bytes, :final nombre) =>
          _archivoAContenido(mimeType, bytes, nombre),
      },
  ];
}

Map<String, dynamic> _archivoAContenido(
  String mimeType,
  Uint8List bytes,
  String nombre,
) {
  final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
  if (mimeType.startsWith('image/')) {
    return {
      'type': 'image_url',
      // `high`: lee letra pequeña (patentes, números de póliza, montos).
      'image_url': {'url': dataUri, 'detail': 'high'},
    };
  }
  if (mimeType == 'application/pdf') {
    return {
      'type': 'file',
      'file': {'filename': nombre, 'file_data': dataUri},
    };
  }
  throw UnsupportedError(
    'La IA solo puede leer imágenes y PDF (recibido: $mimeType).',
  );
}

/// Motor de IA del Registro Inteligente: pide a OpenAI (Chat Completions) una
/// respuesta JSON que cumpla un esquema estricto.
///
/// La app NO tiene la clave de OpenAI: llama a la Edge Function de Supabase
/// `ia-extraccion` con el ID Token de Firebase del usuario, y es la función la
/// que llama a OpenAI con la clave guardada como secreto del servidor. La
/// función devuelve la respuesta de OpenAI tal cual (mismo status y cuerpo),
/// así que los reintentos y la cascada de modelos funcionan igual que antes.
/// Solo necesita `SUPABASE_URL` en el `.env` (ver `entorno.dart`).
///
/// Cascada de modelos, en este orden de prioridad ([modelosEnOrden]):
/// `gpt-6-luna` → `gpt-5.6-luna` → `gpt-5.4-nano`. Si un modelo falla (caído,
/// saturado o inexistente para la cuenta) se pasa al siguiente; si fallan los
/// tres, se repite el ciclo completo desde el primero, hasta [ciclosMaximos]
/// veces con una pausa entre ciclos. Ante un error temporal cada modelo se
/// reintenta antes hasta 3 veces con espera creciente (1s, 2s, 4s).
///
/// El ciclo NO se repite sin fin a propósito: una clave inválida o una cuota
/// agotada (ver [esErrorFatalOpenAi]) cortan de inmediato, y agotados los
/// ciclos se lanza la excepción para que el módulo ofrezca el ingreso manual.
/// Mientras tanto el llamador sigue esperando ("Analizando documento...").
///
/// Lo usan también las auditorías de boletas (`audit_screen.dart`), que no
/// tienen esquema fijo: pasan `esquemaJson: null` y se usa el modo JSON simple.
class OpenAiExtractionService {
  /// Modelos en orden de prioridad. Si OpenAI publica el modelo con otro
  /// identificador, se cambia aquí y en `MODELOS_PERMITIDOS` de
  /// `supabase/functions/ia-extraccion/validate.ts` (la función rechaza los
  /// modelos que no estén en su lista).
  static const List<String> modelosEnOrden = [
    'gpt-6-luna',
    'gpt-5.6-luna',
    'gpt-5.4-nano',
  ];

  /// Veces que se recorre la lista completa antes de rendirse.
  static const int ciclosMaximos = 3;

  /// Pausa entre un ciclo fallido y el siguiente.
  static const Duration pausaEntreCiclos = Duration(seconds: 5);

  /// Tiempo máximo de espera por intento. Corta una conexión colgada; es lo
  /// bastante amplio para respuestas lentas con imágenes grandes.
  static const Duration _timeout = Duration(seconds: 120);

  final http.Client _cliente;
  final Uri? _endpoint;
  final Future<String?> Function() _obtenerToken;

  /// Modelo que respondió en la última llamada exitosa (null si aún ninguna).
  String? ultimoModelo;

  /// [endpoint] y [obtenerToken] solo existen para las pruebas: por defecto se
  /// usa la Edge Function de `SUPABASE_URL` y el ID Token del usuario actual.
  OpenAiExtractionService({
    http.Client? cliente,
    Uri? endpoint,
    Future<String?> Function()? obtenerToken,
  })  : _cliente = cliente ?? http.Client(),
        _endpoint = endpoint,
        _obtenerToken = obtenerToken ?? _idTokenActual;

  static Future<String?> _idTokenActual() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  /// Envía [partes] y devuelve el texto JSON de la respuesta, validado contra
  /// [esquemaJson] (JSON Schema en modo estricto). Si [esquemaJson] es null se
  /// usa el modo JSON simple (el prompt debe pedir JSON explícitamente).
  Future<String> generarJsonConFallback({
    required Iterable<EvidenciaIa> partes,
    Map<String, dynamic>? esquemaJson,
    String nombreEsquema = 'extraccion',
  }) async {
    final endpoint = _endpoint ?? endpointIaExtraccion(Entorno.supabaseUrl);
    if (endpoint == null) {
      throw Exception('Servicio de IA no configurado (falta SUPABASE_URL).');
    }
    final token = await _obtenerToken();
    if (token == null || token.isEmpty) {
      throw Exception('Debes iniciar sesión para usar la IA.');
    }

    final contenido = construirContenido(partes);
    final errores = <String>[];

    for (var ciclo = 1; ciclo <= ciclosMaximos; ciclo++) {
      for (final modelo in modelosEnOrden) {
        final reloj = Stopwatch()..start();
        try {
          final texto = await reintentarSiNoDisponible(
            () => _llamar(
              endpoint,
              token,
              modelo,
              contenido,
              esquemaJson,
              nombreEsquema,
            ),
            alReintentar: (reintento, error) => debugPrint(
              'OpenAiExtractionService: [$modelo] error temporal, reintento '
              '$reintento/${esperasReintento503.length}...',
            ),
          );
          ultimoModelo = modelo;
          debugPrint(
            'OpenAiExtractionService: [$modelo] respondió en '
            '${reloj.elapsedMilliseconds}ms (ciclo $ciclo)',
          );
          return texto;
        } catch (e) {
          final resumen =
              '[ciclo $ciclo][$modelo] falló a los ${reloj.elapsedMilliseconds}ms: $e';
          debugPrint(
            'OpenAiExtractionService: $resumen. Intentando siguiente modelo...',
          );
          errores.add(resumen);
          if (esErrorFatalOpenAi(e)) {
            throw Exception(
              'OpenAI no disponible:\n${errores.join('\n')}',
            );
          }
        }
      }
      if (ciclo < ciclosMaximos) await Future.delayed(pausaEntreCiclos);
    }

    throw Exception(
      'Todos los modelos de OpenAI fallaron tras $ciclosMaximos ciclos:\n'
      '${errores.join('\n')}',
    );
  }

  Future<String> _llamar(
    Uri endpoint,
    String idToken,
    String modelo,
    List<Map<String, dynamic>> contenido,
    Map<String, dynamic>? esquemaJson,
    String nombreEsquema,
  ) async {
    final respuesta = await _cliente
        .post(
          endpoint,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'model': modelo,
            'messages': [
              {'role': 'user', 'content': contenido},
            ],
            'response_format': esquemaJson == null
                ? {'type': 'json_object'}
                : {
                    'type': 'json_schema',
                    'json_schema': {
                      'name': nombreEsquema,
                      'strict': true,
                      'schema': esquemaJson,
                    },
                  },
          }),
        )
        .timeout(_timeout);

    final cuerpo = utf8.decode(respuesta.bodyBytes);
    if (respuesta.statusCode != 200) {
      throw OpenAiException(respuesta.statusCode, _mensajeDeError(cuerpo));
    }

    final json = jsonDecode(cuerpo) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    final mensaje = (choices != null && choices.isNotEmpty)
        ? (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?
        : null;

    final rechazo = mensaje?['refusal'];
    if (rechazo is String && rechazo.isNotEmpty) {
      throw Exception('OpenAI rechazó la solicitud: $rechazo');
    }

    final texto = (mensaje?['content'] as String?)?.trim() ?? '';
    if (texto.isEmpty) {
      throw const FormatException('OpenAI devolvió una respuesta vacía.');
    }
    return texto;
  }

  String _mensajeDeError(String cuerpo) {
    try {
      final error = (jsonDecode(cuerpo) as Map<String, dynamic>)['error'];
      if (error is Map<String, dynamic>) {
        final codigo = error['code'] ?? error['type'] ?? '';
        return '$codigo ${error['message'] ?? ''}'.trim();
      }
    } catch (_) {
      // El cuerpo no era JSON: se devuelve tal cual (acotado).
    }
    return cuerpo.length > 300 ? cuerpo.substring(0, 300) : cuerpo;
  }
}
