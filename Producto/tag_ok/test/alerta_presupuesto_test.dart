import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/utils/alerta_presupuesto.dart';

void main() {
  group('umbralDeAlerta', () {
    const limite = 100000.0;

    test('por debajo del 50 % no hay alerta', () {
      expect(umbralDeAlerta(0, limite), isNull);
      expect(umbralDeAlerta(49999.99, limite), isNull);
    });

    test('cada umbral se dispara justo en su valor (límites inclusivos)', () {
      expect(umbralDeAlerta(50000, limite), 50);
      expect(umbralDeAlerta(74999.99, limite), 50);
      expect(umbralDeAlerta(75000, limite), 75);
      expect(umbralDeAlerta(89999.99, limite), 75);
      expect(umbralDeAlerta(90000, limite), 90);
      expect(umbralDeAlerta(99999.99, limite), 90);
      expect(umbralDeAlerta(100000, limite), 100);
    });

    test('pasarse del límite sigue dando 100', () {
      expect(umbralDeAlerta(250000, limite), 100);
    });

    test('límite = 0: no divide por cero ni dispara el 100 %', () {
      expect(umbralDeAlerta(0, 0), isNull);
      expect(umbralDeAlerta(5000, 0), isNull);
      expect(umbralDeAlerta(1e12, 0), isNull);
    });

    test('límite negativo o no numérico: sin alerta', () {
      expect(umbralDeAlerta(5000, -1), isNull);
      expect(umbralDeAlerta(5000, double.nan), isNull);
      expect(umbralDeAlerta(5000, double.infinity), isNull);
    });

    test('gasto negativo o no numérico: sin alerta', () {
      expect(umbralDeAlerta(-100, limite), isNull);
      expect(umbralDeAlerta(double.nan, limite), isNull);
    });

    test('límite por defecto de la app (50.000): 25.000 -> 50, 50.000 -> 100', () {
      expect(umbralDeAlerta(25000, 50000), 50);
      expect(umbralDeAlerta(50000, 50000), 100);
    });

    test('los umbrales declarados son 100, 90, 75, 50 en orden', () {
      expect(umbralesAlertaPresupuesto, [100, 90, 75, 50]);
    });
  });
}
