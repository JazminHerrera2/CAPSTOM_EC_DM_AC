import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:tag_ok/features/registro_inteligente/gemini_extraction_service.dart';

GenerativeAIException _error503() => GenerativeAIException(
      'Server Error [503]: {"error": {"code": 503, "message": "This model is '
      'currently experiencing high demand.", "status": "UNAVAILABLE"}}',
    );

void main() {
  group('esErrorNoDisponible503', () {
    test('detecta el 503 de Gemini', () {
      expect(esErrorNoDisponible503(_error503()), isTrue);
    });

    test('no confunde otros errores', () {
      expect(
        esErrorNoDisponible503(InvalidApiKey('API key not valid')),
        isFalse,
      );
      expect(
        esErrorNoDisponible503(ServerException('Invalid argument')),
        isFalse,
      );
      expect(esErrorNoDisponible503(Exception('503')), isFalse);
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
        throwsA(isA<GenerativeAIException>()),
      );

      expect(llamadas, 4);
      expect(esperas, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    });

    test('no reintenta errores que no son 503', () async {
      var llamadas = 0;
      var esperaron = false;

      await expectLater(
        reintentarSiNoDisponible<String>(
          () async {
            llamadas++;
            throw InvalidApiKey('API key not valid');
          },
          esperar: (_) async => esperaron = true,
        ),
        throwsA(isA<InvalidApiKey>()),
      );

      expect(llamadas, 1);
      expect(esperaron, isFalse);
    });
  });
}
