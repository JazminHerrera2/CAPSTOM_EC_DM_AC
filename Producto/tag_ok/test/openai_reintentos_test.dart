import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/features/registro_inteligente/extraction_schema_registry.dart';
import 'package:tag_ok/features/registro_inteligente/document_type.dart';
import 'package:tag_ok/features/registro_inteligente/openai_extraction_service.dart';

OpenAiException _error503() => const OpenAiException(
      503,
      'server_error The server is overloaded or not ready yet.',
    );

void main() {
  group('esErrorNoDisponible503', () {
    test('detecta errores temporales de OpenAI', () {
      expect(esErrorNoDisponible503(_error503()), isTrue);
      expect(
        esErrorNoDisponible503(
          const OpenAiException(429, 'rate_limit_exceeded Too many requests'),
        ),
        isTrue,
      );
      expect(
        esErrorNoDisponible503(const OpenAiException(500, 'server_error')),
        isTrue,
      );
    });

    test('no confunde otros errores', () {
      expect(
        esErrorNoDisponible503(
          const OpenAiException(401, 'invalid_api_key Incorrect API key'),
        ),
        isFalse,
      );
      expect(
        esErrorNoDisponible503(const OpenAiException(400, 'invalid_request')),
        isFalse,
      );
      expect(
        esErrorNoDisponible503(
          const OpenAiException(429, 'insufficient_quota You exceeded quota'),
        ),
        isFalse,
      );
      expect(esErrorNoDisponible503(Exception('503')), isFalse);
    });
  });

  group('orden de modelos y errores fatales', () {
    test('prioridad: gpt-6-luna, gpt-5.6-luna, gpt-5.4-nano', () {
      expect(OpenAiExtractionService.modelosEnOrden, [
        'gpt-6-luna',
        'gpt-5.6-luna',
        'gpt-5.4-nano',
      ]);
    });

    test('clave inválida o cuota agotada cortan el ciclo', () {
      expect(esErrorFatalOpenAi(const OpenAiException(401, 'x')), isTrue);
      expect(esErrorFatalOpenAi(const OpenAiException(403, 'x')), isTrue);
      expect(
        esErrorFatalOpenAi(const OpenAiException(429, 'insufficient_quota')),
        isTrue,
      );
    });

    test('modelo caído o inexistente sigue con el siguiente', () {
      expect(esErrorFatalOpenAi(const OpenAiException(503, 'x')), isFalse);
      expect(esErrorFatalOpenAi(const OpenAiException(404, 'model_not_found')), isFalse);
      expect(esErrorFatalOpenAi(Exception('red')), isFalse);
    });
  });

  group('reintentarSiNoDisponible', () {
    test('reintenta con espera creciente y termina bien', () async {
      final esperas = <Duration>[];
      var llamadas = 0;

      final resultado = await reintentarSiNoDisponible<String>(
        () async {
          llamadas++;
          if (llamadas < 3) throw _error503();
          return 'ok';
        },
        esperar: (d) async => esperas.add(d),
      );

      expect(resultado, 'ok');
      expect(llamadas, 3);
      expect(esperas, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });

    test('hace 1 llamada + 3 reintentos y luego se rinde', () async {
      final esperas = <Duration>[];
      var llamadas = 0;

      await expectLater(
        reintentarSiNoDisponible<String>(
          () async {
            llamadas++;
            throw _error503();
          },
          esperar: (d) async => esperas.add(d),
        ),
        throwsA(isA<OpenAiException>()),
      );

      expect(llamadas, 4);
      expect(esperas, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    });

    test('no reintenta errores que no son temporales', () async {
      var llamadas = 0;
      var esperaron = false;

      await expectLater(
        reintentarSiNoDisponible<String>(
          () async {
            llamadas++;
            throw const OpenAiException(401, 'invalid_api_key');
          },
          esperar: (_) async => esperaron = true,
        ),
        throwsA(isA<OpenAiException>()),
      );

      expect(llamadas, 1);
      expect(esperaron, isFalse);
    });
  });

  group('construirContenido', () {
    test('imagen, PDF y texto al formato de OpenAI', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final b64 = base64Encode(bytes);
      final c = construirContenido([
        EvidenciaArchivo('image/jpeg', bytes),
        EvidenciaArchivo('application/pdf', bytes, nombre: 'boleta.pdf'),
        const EvidenciaTexto('hola'),
      ]);

      expect(c[0], {
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$b64', 'detail': 'high'},
      });
      expect(c[1], {
        'type': 'file',
        'file': {
          'filename': 'boleta.pdf',
          'file_data': 'data:application/pdf;base64,$b64',
        },
      });
      expect(c[2], {'type': 'text', 'text': 'hola'});
    });

    test('rechaza tipos que la IA no lee', () {
      expect(
        () => construirContenido([
          EvidenciaArchivo('application/zip', Uint8List(1)),
        ]),
        throwsUnsupportedError,
      );
    });
  });

  group('buildCombinedSchema (modo estricto)', () {
    test('todas las propiedades son requeridas y nulables', () {
      final s = buildCombinedSchema(
        DocumentType.values,
        conVerificacionOcr: true,
      );
      final props = s['properties'] as Map<String, dynamic>;

      expect(s['additionalProperties'], isFalse);
      expect(s['required'], props.keys.toList());
      expect(props.containsKey('patente_ocr_correcto'), isTrue);
      expect(
        (props['tipo_documento'] as Map)['enum'],
        contains(null),
      );
      for (final p in props.values) {
        expect((p as Map)['type'], contains('null'));
      }
    });

    test('sin OCR no pide los booleanos de verificación', () {
      final s = buildCombinedSchema(DocumentType.values);
      final props = s['properties'] as Map<String, dynamic>;
      expect(props.keys.any((k) => k.endsWith(sufijoOcrCorrecto)), isFalse);
    });
  });
}
