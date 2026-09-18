import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'document_type.dart';
import 'extraction_schema_registry.dart';
import 'file_text_extractor.dart';
import 'gemini_extraction_service.dart';
import 'smart_capture_result.dart';

/// Orquesta CU33 (capturar evidencia) → CU34 (identificar tipo) → CU35
/// (extraer datos). No es un widget: cada módulo decide su propia UI de
/// captura y de revisión (CU36-CU38), este controller solo entrega el
/// `SmartCaptureResult`.
///
/// RNF-011: si la IA falla, este método propaga la excepción — el módulo
/// llamante debe capturarla y ofrecer el ingreso manual (CU40) sin bloquear
/// el flujo. Este controller no decide esa alternativa por sí mismo.
class SmartCaptureController {
  final GeminiExtractionService _geminiService;

  SmartCaptureController({GeminiExtractionService? geminiService})
      : _geminiService = geminiService ?? GeminiExtractionService();

  /// [bytes] es la evidencia capturada (CU33): una foto o un archivo.
  /// [mimeType] determina si se envía como imagen (multimodal) o si primero
  /// se le extrae texto (PDF/Excel). [tiposPermitidos] acota qué tipos de
  /// documento puede reconocer la IA para este módulo — Mi Vehículo pasa
  /// sus 4 tipos; Mantenciones/Estacionamientos/Combustible pasarán los
  /// suyos en Sprints siguientes sin tocar este archivo.
  Future<SmartCaptureResult> capturarYExtraer({
    required Uint8List bytes,
    required String mimeType,
    required String nombreArchivo,
    required List<DocumentType> tiposPermitidos,
  }) async {
    final prompt = buildExtractionPrompt(tiposPermitidos);
    final schema = buildCombinedSchema(tiposPermitidos);

    final Part evidenciaPart;
    final textoExtraido = mimeType.startsWith('image/')
        ? null
        : FileTextExtractor.extraerDeArchivo(nombreArchivo, bytes);

    // TEMP DEBUG (remover después de confirmar el bug): tamaño real de lo
    // que se va a adjuntar a la petición.
    debugPrint(
      'DEBUG SMART CAPTURE -> mimeType: $mimeType, bytes.length: ${bytes.length}, '
      'textoExtraido: ${textoExtraido == null ? "null (se manda DataPart)" : '"${textoExtraido.length} caracteres"'}',
    );

    if (textoExtraido != null) {
      evidenciaPart = TextPart(
        'Texto extraído del archivo "$nombreArchivo":\n"""\n$textoExtraido\n"""',
      );
    } else {
      evidenciaPart = DataPart(mimeType, bytes);
    }

    final response = await _geminiService.generateContentWithFallback(
      parts: [evidenciaPart, TextPart(prompt)],
      responseSchema: schema,
    );

    final responseText = response.text?.trim() ?? '';
    final json = jsonDecode(responseText) as Map<String, dynamic>;
    final parsed = parseExtractionResponse(json);

    final camposDudosos = <String>{};
    if (parsed.tipo != null) {
      for (final campo in extractionSchemas[parsed.tipo]!.campos) {
        if (!parsed.campos.containsKey(campo.clave)) {
          camposDudosos.add(campo.clave);
        }
      }
    }

    return SmartCaptureResult(
      tipoDetectado: parsed.tipo,
      campos: parsed.campos,
      camposDudosos: camposDudosos,
      fechaCaptura: DateTime.now(),
    );
  }
}
