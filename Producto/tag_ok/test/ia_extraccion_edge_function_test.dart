import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tag_ok/features/registro_inteligente/openai_extraction_service.dart';

/// La app ya no habla con OpenAI: llama a la Edge Function `ia-extraccion`
/// con el ID Token de Firebase, y la clave de OpenAI queda en el servidor.
void main() {
  final endpoint = Uri.parse(
    'https://proyecto.supabase.co/functions/v1/ia-extraccion',
  );

  String respuestaOpenAi(String contenido) => jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': contenido},
          },
        ],
      });

  group('endpointIaExtraccion', () {
    test('arma la URL de la función desde SUPABASE_URL', () {
      expect(
        endpointIaExtraccion('https://proyecto.supabase.co/'),
        endpoint,
      );
    });

    test('sin URL https no hay endpoint', () {
      expect(endpointIaExtraccion(null), isNull);
      expect(endpointIaExtraccion(''), isNull);
      expect(endpointIaExtraccion('http://proyecto.supabase.co'), isNull);
    });
  });

  group('OpenAiExtractionService vía Edge Function', () {
    test('llama a la función con el ID Token, nunca a api.openai.com', () async {
      late http.Request recibida;
      final servicio = OpenAiExtractionService(
        endpoint: endpoint,
        obtenerToken: () async => 'token-firebase',
        cliente: MockClient((request) async {
          recibida = request;
          return http.Response(respuestaOpenAi('{"ok":true}'), 200);
        }),
      );

      final texto = await servicio.generarJsonConFallback(
        partes: const [EvidenciaTexto('hola')],
      );

      expect(texto, '{"ok":true}');
      expect(recibida.url, endpoint);
      expect(recibida.url.host, isNot('api.openai.com'));
      expect(recibida.headers['Authorization'], 'Bearer token-firebase');

      final body = jsonDecode(recibida.body) as Map<String, dynamic>;
      expect(body['model'], OpenAiExtractionService.modelosEnOrden.first);
      expect(body['response_format'], {'type': 'json_object'});
      expect(servicio.ultimoModelo, OpenAiExtractionService.modelosEnOrden.first);
    });

    test('sin sesión no llama a la función', () async {
      var llamadas = 0;
      final servicio = OpenAiExtractionService(
        endpoint: endpoint,
        obtenerToken: () async => null,
        cliente: MockClient((_) async {
          llamadas++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        servicio.generarJsonConFallback(partes: const [EvidenciaTexto('x')]),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('iniciar sesión'),
        )),
      );
      expect(llamadas, 0);
    });

    test('si falta el secreto en el servidor corta sin reintentar', () async {
      var llamadas = 0;
      final servicio = OpenAiExtractionService(
        endpoint: endpoint,
        obtenerToken: () async => 'token-firebase',
        cliente: MockClient((_) async {
          llamadas++;
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'configuracion_servidor',
                'message': 'OPENAI_API_KEY no configurada',
              },
            }),
            500,
          );
        }),
      );

      await expectLater(
        servicio.generarJsonConFallback(partes: const [EvidenciaTexto('x')]),
        throwsA(isA<Exception>()),
      );
      expect(llamadas, 1);
    });

    test('un modelo rechazado pasa al siguiente de la cascada', () async {
      final modelos = <String>[];
      final servicio = OpenAiExtractionService(
        endpoint: endpoint,
        obtenerToken: () async => 'token-firebase',
        cliente: MockClient((request) async {
          final modelo = (jsonDecode(request.body) as Map)['model'] as String;
          modelos.add(modelo);
          if (modelos.length == 1) {
            return http.Response(
              jsonEncode({
                'error': {'code': 'model_not_found', 'message': 'no existe'},
              }),
              404,
            );
          }
          return http.Response(respuestaOpenAi('{"ok":true}'), 200);
        }),
      );

      final texto = await servicio.generarJsonConFallback(
        partes: const [EvidenciaTexto('x')],
      );

      expect(texto, '{"ok":true}');
      expect(modelos, OpenAiExtractionService.modelosEnOrden.take(2).toList());
    });
  });
}
