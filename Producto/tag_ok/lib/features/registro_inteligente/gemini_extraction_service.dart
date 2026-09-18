import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Generaliza el patrón de fallback en cascada de modelos que ya existe en
/// `screens/audit_screen.dart` (`_generateContentWithFallback()`), para que
/// el componente de Registro Inteligente no reimplemente la integración con
/// Gemini desde cero. No se toca `audit_screen.dart` — sigue con su propia
/// copia por ahora (ver docs/05-arquitectura-tecnica.md).
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
        return await model.generateContent([Content.multi(parts)]);
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
