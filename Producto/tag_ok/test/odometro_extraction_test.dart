import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/features/registro_inteligente/odometro_extraction.dart';

void main() {
  test('lee solo los dígitos del odómetro', () {
    expect(parseOdometro({'kilometraje': '72450', 'unidad': 'km'}).kilometraje,
        72450);
    expect(parseOdometro({'kilometraje': '72.450 km', 'unidad': 'km'}).kilometraje,
        72450);
    expect(parseOdometro({'kilometraje': '123456.7', 'unidad': 'km'}).kilometraje,
        123456);
    expect(parseOdometro({'kilometraje': '123,456', 'unidad': null}).kilometraje,
        123456);
  });

  test('sin lectura o fuera de rango: null', () {
    expect(parseOdometro({'kilometraje': null, 'unidad': null}).kilometraje,
        isNull);
    expect(parseOdometro({'kilometraje': 'ilegible'}).kilometraje, isNull);
    expect(parseOdometro({'kilometraje': '99999999'}).kilometraje, isNull);
  });

  test('detecta el tablero en millas', () {
    final r = parseOdometro({'kilometraje': '40000', 'unidad': 'mi'});
    expect(r.enMillas, isTrue);
    expect(parseOdometro({'kilometraje': '40000', 'unidad': 'km'}).enMillas,
        isFalse);
  });
}
