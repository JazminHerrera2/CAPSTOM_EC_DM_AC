import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../utils/permiso_circulacion.dart';
import 'document_type.dart';
import 'extraction_schema_registry.dart';
import 'file_text_extractor.dart';
import 'ocr_service.dart';
import 'openai_extraction_service.dart';
import 'preparar_imagen.dart';
import 'smart_capture_result.dart';
import 'validacion_campos.dart';

/// Orquesta CU33 (capturar evidencia) → CU34 (identificar tipo) → CU35
/// (extraer datos). No es un widget: cada módulo decide su propia UI de
/// captura y de revisión (CU36-CU38), este controller solo entrega el
/// `SmartCaptureResult`.
///
/// RNF-011: si la IA falla, este método propaga la excepción — el módulo
/// llamante debe capturarla y ofrecer el ingreso manual (CU40) sin bloquear
/// el flujo. Este controller no decide esa alternativa por sí mismo.
class SmartCaptureController {
  final OpenAiExtractionService _iaService;
  final OcrService _ocrService;

  SmartCaptureController({
    OpenAiExtractionService? iaService,
    OcrService? ocrService,
  })  : _iaService = iaService ?? OpenAiExtractionService(),
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
    void Function(String etapa)? alCambiarEtapa,
  }) async {
    // Momento en que el usuario ingresó el archivo: sirve de fecha de emisión
    // estimada cuando el permiso trae solo el año.
    final fechaIngreso = DateTime.now();
    final reloj = Stopwatch()..start();
    final esImagen = mimeType.startsWith('image/');

    var textoExtraido =
        esImagen ? null : FileTextExtractor.extraerDeArchivo(nombreArchivo, bytes);

    // Un PDF escaneado (o una foto guardada como PDF) no tiene capa de texto:
    // la extracción devuelve vacío y la IA recibiría un mensaje sin
    // contenido. En ese caso se envía el archivo original para que lo lea
    // como documento/imagen.
    if (textoExtraido != null &&
        textoExtraido.trim().length < OcrService.minCaracteres) {
      textoExtraido = null;
    }

    // Imágenes: la IA recibe SIEMPRE la imagen. Si el OCR local obtiene texto
    // suficiente, se envía además como texto y la IA lo verifica contra la
    // imagen (la imagen es la fuente de verdad). Sin OCR (web/escritorio) o
    // con texto insuficiente, se envía solo la imagen.
    String? textoOcr;
    if (esImagen) {
      textoOcr = await _ocrService.reconocerTexto(bytes);
    }
    final hayOcr = textoOcr != null;
    final msOcr = reloj.elapsedMilliseconds;

    // A la IA se le envía la imagen reducida, con la orientación corregida y
    // en JPEG de buena calidad (el OCR ya corrió sobre el original).
    var bytesIa = bytes;
    var mimeIa = mimeType;
    if (esImagen) {
      if (imagenRequierePreparacion(bytes, mimeType)) {
        alCambiarEtapa?.call(etapaPreparandoImagen);
        // Cede un cuadro para que la pantalla muestre el aviso antes de que
        // empiece el trabajo pesado.
        await Future.delayed(const Duration(milliseconds: 80));
      }
      final preparada = await prepararImagenParaIa(bytes, mimeType);
      bytesIa = preparada.bytes;
      mimeIa = preparada.mimeType;
    }
    final msPreparar = reloj.elapsedMilliseconds - msOcr;

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

    final List<EvidenciaIa> evidencia;
    if (hayOcr) {
      evidencia = [
        EvidenciaArchivo(mimeIa, bytesIa, nombre: nombreArchivo),
        EvidenciaTexto(
          'Texto reconocido por OCR de la imagen "$nombreArchivo":\n"""\n$textoOcr\n"""',
        ),
      ];
    } else if (textoExtraido != null) {
      evidencia = [
        EvidenciaTexto(
          'Texto extraído del archivo "$nombreArchivo":\n"""\n$textoExtraido\n"""',
        ),
      ];
    } else {
      evidencia = [EvidenciaArchivo(mimeIa, bytesIa, nombre: nombreArchivo)];
    }

    alCambiarEtapa?.call(etapaAnalizando);
    reloj.reset();
    final responseText = await _iaService.generarJsonConFallback(
      partes: [...evidencia, EvidenciaTexto(prompt)],
      esquemaJson: schema,
      nombreEsquema: 'extraccion_documento',
    );

    debugPrint(
      'TIEMPOS registro inteligente -> OCR: ${msOcr}ms, preparar imagen: '
      '${msPreparar}ms (${bytes.length} -> ${bytesIa.length} bytes), '
      'IA: ${reloj.elapsedMilliseconds}ms (modelo: ${_iaService.ultimoModelo})',
    );

    final json = jsonDecode(responseText) as Map<String, dynamic>;
    final parsed = parseExtractionResponse(json);

    // Normaliza y valida con reglas propias (formato de patente, fechas reales
    // y coherentes): lo que no pase queda resaltado para que el usuario lo
    // revise, aunque la IA lo haya devuelto con seguridad.
    final validados = validarCamposExtraidos(parsed.campos);
    final camposFinales = validados.campos;

    // Permiso de Circulación sin fecha de emisión pero con año: se completa
    // con la fecha de ingreso y se marca como estimada. El año auxiliar no se
    // muestra ni se guarda.
    final camposEstimados = <String>{};
    final anioRaw = camposFinales.remove(claveAnioPermiso);
    if (parsed.tipo == DocumentType.permisoCirculacion) {
      final emision = resolverFechaEmision(
        fechaLeida: camposFinales['fecha_emision'] == null
            ? null
            : interpretarFecha(camposFinales['fecha_emision'].toString()),
        anioLeido: int.tryParse(anioRaw?.toString().trim() ?? ''),
        fechaIngreso: fechaIngreso,
      );
      if (emision != null && emision.estimada) {
        camposFinales['fecha_emision'] = formatoIsoFecha(emision.fecha);
        camposEstimados.add('fecha_emision');
      }
    }

    final camposDudosos = <String>{...validados.dudosos};
    if (parsed.tipo != null) {
      for (final campo in extractionSchemas[parsed.tipo]!.campos) {
        // Solo se destacan los requeridos ausentes: un opcional que no
        // aparece en el documento es normal, no una duda de la IA.
        if (campo.requerido && !camposFinales.containsKey(campo.clave)) {
          camposDudosos.add(campo.clave);
        }
      }
    }

    return SmartCaptureResult(
      tipoDetectado: parsed.tipo,
      campos: camposFinales,
      camposDudosos: camposDudosos,
      confianzaIa: parsed.confianzaIa,
      camposEstimados: camposEstimados,
      fechaCaptura: fechaIngreso,
    );
  }
}
