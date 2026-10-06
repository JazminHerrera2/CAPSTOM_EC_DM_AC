import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// OCR local (ML Kit, script Latin) que se ejecuta ANTES de llamar a Gemini:
/// el OCR lee el texto crudo y Gemini solo lo valida/estructura.
///
/// Nunca lanza excepción: ante cualquier problema devuelve `null` para que el
/// controller caiga al comportamiento anterior (enviar la imagen a Gemini).
class OcrService {
  /// Mismo umbral que usa `SmartCaptureController` para detectar un PDF
  /// escaneado sin capa de texto.
  static const int minCaracteres = 30;

  /// ML Kit solo existe en Android e iOS. En web y escritorio no hay OCR local.
  static bool get disponible =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Devuelve el texto reconocido de una imagen JPEG/PNG, o `null` si el OCR no
  /// está disponible, falla, o el texto tiene menos de [minCaracteres].
  Future<String?> reconocerTexto(Uint8List bytes) async {
    if (!disponible || bytes.isEmpty) return null;

    File? archivoTemporal;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      // ML Kit solo acepta archivos o buffers crudos (NV21/BGRA), no JPEG/PNG
      // en memoria, así que se escribe a un archivo temporal.
      final dir = await getTemporaryDirectory();
      archivoTemporal = File(
        '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.img',
      );
      await archivoTemporal.writeAsBytes(bytes, flush: true);

      final resultado = await recognizer.processImage(
        InputImage.fromFilePath(archivoTemporal.path),
      );

      final texto = resultado.text.trim();
      return texto.length < minCaracteres ? null : texto;
    } catch (e) {
      debugPrint('OcrService: no se pudo reconocer el texto: $e');
      return null;
    } finally {
      await recognizer.close();
      try {
        await archivoTemporal?.delete();
      } catch (_) {}
    }
  }
}
