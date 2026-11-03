import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/utils/simulacion_recorrido.dart';

void main() {
  // Radio con el que _checkTollCrossings (live_map_screen.dart) da por cruzado
  // un pórtico. Si alguien lo cambia allí, hay que revisar estos tests.
  const radioCruceMetros = 45.0;

  group('simulación de recorrido', () {
    test('ningún multiplicador avanza más que el radio de cruce por paso', () {
      // _simulateMovement solo revisa los cruces al final de cada paso: un paso
      // mayor que el radio podría saltarse un pórtico.
      for (final m in multiplicadoresSimulacion) {
        expect(metrosPorPasoSimulacion(m), lessThanOrEqualTo(radioCruceMetros),
            reason: '${m}x se saltaría pórticos');
      }
    });

    test('1x avanza ~1,7 m por paso (60 km/h, 100 ms) y 20x ~33 m', () {
      expect(metrosPorPasoSimulacion(1), closeTo(1.667, 0.001));
      expect(metrosPorPasoSimulacion(5), closeTo(8.333, 0.001));
      expect(metrosPorPasoSimulacion(20), closeTo(33.333, 0.001));
    });

    test('ofrece 1x, 5x y 20x', () {
      expect(multiplicadoresSimulacion, [1, 5, 20]);
    });

    test('el viaje simulado se identifica con el sufijo [SIMULADO]', () {
      expect(nombreVehiculoSimulado('Hyundai (JHGK50)'), 'Hyundai (JHGK50) [SIMULADO]');
      expect(nombreVehiculoSimulado('Vehículo Principal').endsWith(sufijoViajeSimulado), isTrue);
      // cabe en lo que permiten las reglas (vehicleName <= 100 caracteres)
      expect(nombreVehiculoSimulado('x' * 60).length, lessThanOrEqualTo(100));
    });
  });
}
