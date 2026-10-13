import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tag_ok/features/registro_inteligente/mantencion_extraction.dart';
import 'package:tag_ok/features/registro_inteligente/preparar_imagen.dart';
import 'package:tag_ok/features/registro_inteligente/validacion_campos.dart';

final _hoy = DateTime(2026, 10, 13);

void main() {
  group('patente', () {
    test('se normaliza y valida el formato chileno', () {
      expect(normalizarPatente('bc·df-12 '), 'BCDF12');
      for (final p in ['BCDF12', 'AB1234', 'BCD12', 'AB123']) {
        expect(esPatenteChilena(p), isTrue, reason: p);
      }
      for (final p in ['BCDF1', 'ABC123', '123456', 'ABCDEF', 'B0DF1O']) {
        expect(esPatenteChilena(p), isFalse, reason: p);
      }
    });

    test('descarta el dígito verificador tras el guion', () {
      expect(normalizarPatente('KZZZ60-0'), 'KZZZ60');
      expect(normalizarPatente('kzzz60 - 0'), 'KZZZ60');
      expect(normalizarPatente('AB1234-K'), 'AB1234');
      expect(normalizarPatente('KZ-ZZ-60'), 'KZZZ60');
      final r = validarCamposExtraidos({'patente': 'KZZZ60-0'}, ahora: _hoy);
      expect(r.campos['patente'], 'KZZZ60');
      expect(r.dudosos, isEmpty);
    });

    test('una patente rara se conserva pero queda dudosa', () {
      final r = validarCamposExtraidos({'patente': 'ab-12'}, ahora: _hoy);
      expect(r.campos['patente'], 'AB12');
      expect(r.dudosos, contains('patente'));
    });

    test('una patente buena no es dudosa', () {
      final r = validarCamposExtraidos({'patente': ' bcdf12 '}, ahora: _hoy);
      expect(r.campos['patente'], 'BCDF12');
      expect(r.dudosos, isEmpty);
    });
  });

  group('fechas', () {
    test('acepta ISO y dd/mm/aaaa y las deja en ISO', () {
      final r = validarCamposExtraidos({
        'fecha_emision': '05/03/2026',
        'fecha_vencimiento': '2027-03-31',
      }, ahora: _hoy);
      expect(r.campos['fecha_emision'], '2026-03-05');
      expect(r.campos['fecha_vencimiento'], '2027-03-31');
      expect(r.dudosos, isEmpty);
    });

    test('entiende el mes escrito en palabras', () {
      expect(interpretarFecha('26 FEBRERO 2026'), DateTime(2026, 2, 26));
      expect(interpretarFecha('5 de marzo de 2026'), DateTime(2026, 3, 5));
      expect(interpretarFecha('31 febrero 2026'), isNull);
    });

    test('una fecha imposible se descarta y queda dudosa', () {
      final r = validarCamposExtraidos(
        {'fecha_vencimiento': '2026-02-31'},
        ahora: _hoy,
      );
      expect(r.campos.containsKey('fecha_vencimiento'), isFalse);
      expect(r.dudosos, contains('fecha_vencimiento'));
    });

    test('vencimiento anterior a la emisión marca ambas', () {
      final r = validarCamposExtraidos({
        'fecha_emision': '2026-06-01',
        'fecha_vencimiento': '2025-06-01',
      }, ahora: _hoy);
      expect(r.dudosos, containsAll(['fecha_emision', 'fecha_vencimiento']));
    });

    test('emisión futura, fechas absurdas', () {
      final futura = validarCamposExtraidos(
        {'fecha_emision': '2026-12-25'},
        ahora: _hoy,
      );
      expect(futura.dudosos, contains('fecha_emision'));

      final lejana = validarCamposExtraidos(
        {'fecha_vencimiento': '2090-01-01'},
        ahora: _hoy,
      );
      expect(lejana.dudosos, contains('fecha_vencimiento'));
    });
  });

  test('mantención con fecha futura o antigua se descarta', () {
    expect(parseMantencionExtraida({'fecha': '2099-01-01'}).fecha, isNull);
    expect(parseMantencionExtraida({'fecha': '1985-01-01'}).fecha, isNull);
    expect(
      parseMantencionExtraida({'fecha': '2026-09-15'}).fecha,
      DateTime(2026, 9, 15),
    );
  });

  group('prepararImagenParaIa', () {
    test('reduce una imagen grande a 2000 px y la deja en JPEG', () async {
      // Con ruido, como una foto real (una imagen lisa pesa casi nada).
      final grande = img.Image(width: 2400, height: 1200);
      var semilla = 7;
      for (final p in grande) {
        semilla = (semilla * 1103515245 + 12345) & 0x7fffffff;
        p
          ..r = semilla & 255
          ..g = (semilla >> 8) & 255
          ..b = (semilla >> 16) & 255;
      }
      final png = Uint8List.fromList(img.encodePng(grande));

      final r = await prepararImagenParaIa(png, 'image/png', umbralBytes: 0);
      final salida = img.decodeImage(r.bytes)!;

      expect(r.mimeType, 'image/jpeg');
      expect(salida.width, ladoMaximoImagenIa);
      expect(salida.height, 1000);
      expect(r.bytes.length, lessThan(png.length));
    });

    test('una imagen chica no se agranda', () async {
      final chica = img.Image(width: 400, height: 300);
      final r = await prepararImagenParaIa(
        Uint8List.fromList(img.encodePng(chica)),
        'image/png',
        umbralBytes: 0,
      );
      final salida = img.decodeImage(r.bytes)!;
      expect((salida.width, salida.height), (400, 300));
    });

    test('si no se puede leer devuelve el original', () async {
      final basura = Uint8List.fromList([1, 2, 3, 4]);
      final r = await prepararImagenParaIa(
        basura,
        'image/jpeg',
        umbralBytes: 0,
      );
      expect(r.bytes, basura);
      expect(r.mimeType, 'image/jpeg');
    });

    test('una imagen liviana se envía tal cual, sin procesar', () async {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 3000, height: 1500)),
      );
      final r = await prepararImagenParaIa(png, 'image/png');
      expect(r.bytes, same(png));
      expect(r.mimeType, 'image/png');
    });

    test('solo avisa "preparando" cuando hay trabajo real', () {
      final liviana = Uint8List(umbralPrepararBytes - 1);
      final pesada = Uint8List(umbralPrepararBytes);
      expect(imagenRequierePreparacion(liviana, 'image/jpeg'), isFalse);
      expect(imagenRequierePreparacion(pesada, 'image/jpeg'), isTrue);
      expect(imagenRequierePreparacion(pesada, 'application/pdf'), isFalse);
    });

    test('los PDF no se tocan', () async {
      final pdf = Uint8List.fromList([37, 80, 68, 70]);
      final r = await prepararImagenParaIa(pdf, 'application/pdf');
      expect(r.bytes, pdf);
      expect(r.mimeType, 'application/pdf');
    });
  });
}
