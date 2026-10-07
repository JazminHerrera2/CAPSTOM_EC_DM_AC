import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Esperas entre los reintentos de un mismo modelo ante un 503 (1s, 2s, 4s):
/// una llamada inicial + hasta 3 reintentos.
const List<Duration> esperasReintento503 = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

/// `true` si [error] es un 503 de Gemini ("UNAVAILABLE" / "high demand"): un
/// problema temporal del servidor que suele resolverse solo. La librería lo
/// lanza como `GenerativeAIException('Server Error [503]: {...}')`.
///
/// Los demás errores (401, 400, 404, etc.) no se resuelven reintentando.
bool esErrorNoDisponible503(Object error) {
  if (error is! GenerativeAIException) return false;

  final texto = error.toString();
  return texto.contains('[503]') ||
      RegExp(r'"code"\s*:\s*503').hasMatch(texto) ||
      texto.contains('UNAVAILABLE');
}

/// Ejecuta [accion] y, si falla con un 503, la reintenta esperando
/// [esperas] entre intentos (backoff exponencial). Cualquier otro error se
/// relanza de inmediato, sin reintentar. Si se agotan los reintentos, relanza
/// el último 503.
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

/// Generaliza el patrón de fallback en cascada de modelos que ya existe en
/// `screens/audit_screen.dart` (`_generateContentWithFallback()`), para que
/// el componente de Registro Inteligente no reimplemente la integración con
/// Gemini desde cero. No se toca `audit_screen.dart` — sigue con su propia
/// copia por ahora (ver docs/05-arquitectura-tecnica.md).
///
/// Ante un 503 (servidor saturado) cada modelo se reintenta hasta 3 veces con
/// espera creciente (1s, 2s, 4s) antes de pasar al siguiente de la cascada.
/// Con cualquier otro error no se reintenta: se pasa de inmediato al siguiente
/// modelo y, si todos fallan, se lanza la excepción (el módulo ofrece entonces
/// el ingreso manual). Mientras reintenta, el llamador sigue esperando, así
/// que la pantalla mantiene "Analizando documento..." sin mostrar errores.
///
/// Sin timeout artificial a propósito: los modelos `gemini-3.5-flash` y
/// `gemini-3.6-flash` usan "thinking" y pueden demorar más de lo esperado;
/// cortar la espera con un timeout descarta respuestas que sí iban a llegar
/// bien (ver incidente documentado durante Sprint 1 con el mismo patrón en
/// audit_screen.dart).
class GeminiExtractionService {
  static const List<String> _modelsToTry = [
    'gemini-3.5-flash',
    'gemini-3.6-flash',
  ];

  Future<GenerateContentResponse> generateContentWithFallback({
    required Iterable<Part> parts,
    Schema? responseSchema,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('Clave de API de Gemini no configurada.');
    }

    final attemptErrors = <String>[];

    for (final modelName in _modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: responseSchema,
          ),
        );
        return await reintentarSiNoDisponible(
          () => model.generateContent([Content.multi(parts)]),
          alReintentar: (reintento, error) => debugPrint(
            'GeminiExtractionService: [$modelName] 503, reintento '
            '$reintento/${esperasReintento503.length}...',
          ),
        );
      } catch (e) {
        final attemptSummary = '[$modelName] $e';
        debugPrint(
          'GeminiExtractionService: $attemptSummary. Intentando siguiente modelo...',
        );
        attemptErrors.add(attemptSummary);
      }
    }

    throw Exception(
      'Todos los modelos de Gemini fallaron:\n${attemptErrors.join('\n')}',
    );
  }
}
