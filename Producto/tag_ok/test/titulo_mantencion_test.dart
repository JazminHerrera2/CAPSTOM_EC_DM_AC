import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/utils/titulo_mantencion.dart';

void main() {
  group('normalizarTituloMantencion', () {
    test('vacío o solo espacios es inválido', () {
      expect(normalizarTituloMantencion(null), isNull);
      expect(normalizarTituloMantencion(''), isNull);
      expect(normalizarTituloMantencion('   	 '), isNull);
    });

    test('recorta extremos y colapsa espacios, sin cambiar mayúsculas', () {
      expect(normalizarTituloMantencion('  Cambio   de  aceite '),
          'Cambio de aceite');
      expect(normalizarTituloMantencion('cambio de ACEITE'),
          'cambio de ACEITE');
    });

    test('"Cambio de aceite" se guarda tal cual', () {
      expect(normalizarTituloMantencion('Cambio de aceite'),
          'Cambio de aceite');
    });

    test('60 caracteres sí, más de 60 se rechaza', () {
      expect(normalizarTituloMantencion('a' * 60), 'a' * 60);
      expect(normalizarTituloMantencion('a' * 61), isNull);
    });
  });

  group('recortarTituloMantencion (sugerencia de la IA)', () {
    test('recorta en vez de rechazar y no deja espacio al final', () {
      expect(recortarTituloMantencion('a' * 90), 'a' * 60);
      expect(recortarTituloMantencion('${'a' * 59} bbb'), 'a' * 59);
      expect(recortarTituloMantencion('  '), isNull);
      expect(recortarTituloMantencion(null), isNull);
    });
  });

  group('tituloMantencion', () {
    test('valor de la lista anterior se muestra con su etiqueta', () {
      expect(tituloMantencion('cambio_aceite'), 'Cambio de aceite');
      expect(tituloMantencion('alineacion_balanceo'), 'Alineación y balanceo');
    });

    test('"otra" muestra tipo_otro, o "Otra" si no hay; nunca vacío', () {
      expect(tituloMantencion('otra', tipoOtro: 'Pulido'), 'Pulido');
      expect(tituloMantencion('otra'), 'Otra');
      expect(tituloMantencion('otra', tipoOtro: '  '), 'Otra');
      expect(tituloMantencion(''), 'Otra');
      expect(tituloMantencion(null), 'Otra');
    });

    test('un título libre se muestra tal cual', () {
      expect(tituloMantencion('Aceite y frenos'), 'Aceite y frenos');
    });
  });
}
