import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'document_type.dart';
import 'extraction_schema_registry.dart';
import 'file_text_extractor.dart';
import 'gemini_extraction_service.dart';
import 'ocr_service.dart';
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
  final OcrService _ocrService;

  SmartCaptureController({
    GeminiExtractionService? geminiService,
    OcrService? ocrService,
  })  : _geminiService = geminiService ?? GeminiExtractionService(),
        _ocrService = ocrService ?? OcrService();

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
    final esImagen = mimeType.startsWith('image/');

    var textoExtraido =
        esImagen ? null : FileTextExtractor.extraerDeArchivo(nombreArchivo, bytes);

    // Un PDF escaneado (o una foto guardada como PDF) no tiene capa de texto:
    // la extracción devuelve vacío y Gemini recibiría un mensaje sin
    // contenido. En ese caso se envía el archivo original para que lo lea
    // como documento/imagen.
    if (textoExtraido != null &&
        textoExtraido.trim().length < OcrService.minCaracteres) {
      textoExtraido = null;
    }

    // Imágenes: Gemini recibe SIEMPRE la imagen. Si el OCR local obtiene texto
    // suficiente, se envía además como TextPart y Gemini lo verifica contra la
    // imagen (la imagen es la fuente de verdad). Sin OCR (web/escritorio) o
    // con texto insuficiente, se envía solo la imagen.
    String? textoOcr;
    if (esImagen) {
      textoOcr = await _ocrService.reconocerTexto(bytes);
    }
    final hayOcr = textoOcr != null;

    final prompt = buildExtractionPrompt(
      tiposPermitidos,
      textoDesdeOcr: hayOcr,
    );
    final schema = buildCombinedSchema(
      tiposPermitidos,
      conVerificacionOcr: hayOcr,
    );

    // TEMP DEBUG (remover después de confirmar el bug): tamaño real de lo
    // que se va a adjuntar a la petición.
    debugPrint(
      'DEBUG SMART CAPTURE -> mimeType: $mimeType, bytes.length: ${bytes.length}, '
      'textoExtraido: ${textoExtraido == null ? "null (se manda DataPart)" : '"${textoExtraido.length} caracteres"'}, '
      'ocr: ${hayOcr ? "${textoOcr.length} caracteres (imagen + texto)" : "no"}',
    );

    final List<Part> evidencia;
    if (hayOcr) {
      evidencia = [
        DataPart(mimeType, bytes),
        TextPart(
          'Texto reconocido por OCR de la imagen "$nombreArchivo":\n"""\n$textoOcr\n"""',
        ),
      ];
    } else if (textoExtraido != null) {
      evidencia = [
        TextPart(
          'Texto extraído del archivo "$nombreArchivo":\n"""\n$textoExtraido\n"""',
        ),
      ];
    } else {
      evidencia = [DataPart(mimeType, bytes)];
    }

    final response = await _geminiService.generateContentWithFallback(
      parts: [...evidencia, TextPart(prompt)],
      responseSchema: schema,
    );

    final responseText = response.text?.trim() ?? '';
    final json = jsonDecode(responseText) as Map<String, dynamic>;
    final parsed = parseExtractionResponse(json);

    final camposDudosos = <String>{};
    if (parsed.tipo != null) {
      for (final campo in extractionSchemas[parsed.tipo]!.campos) {
        // Solo se destacan los requeridos ausentes: un opcional que no
        // aparece en el documento es normal, no una duda de la IA.
        if (campo.requerido && !parsed.campos.containsKey(campo.clave)) {
          camposDudosos.add(campo.clave);
        }
      }
    }

    return SmartCaptureResult(
      tipoDetectado: parsed.tipo,
      campos: parsed.campos,
      camposDudosos: camposDudosos,
      confianzaIa: parsed.confianzaIa,
      fechaCaptura: DateTime.now(),
    );
  }
}
