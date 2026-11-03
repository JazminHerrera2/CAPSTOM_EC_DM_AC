import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/utils/vehiculo_de_viaje.dart';

void main() {
  test('el viaje es del vehículo cuando su nombre lleva la patente', () {
    expect(viajeEsDeVehiculo('Toyota (ABCD12)', 'ABCD12'), isTrue);
  });

  test('no distingue mayúsculas ni espacios en la patente', () {
    expect(viajeEsDeVehiculo('Toyota (abcd12)', ' ABCD12 '), isTrue);
  });

  test('un viaje simulado (debug) sigue siendo del vehículo', () {
    expect(viajeEsDeVehiculo('Toyota (ABCD12) [SIMULADO]', 'ABCD12'), isTrue);
  });

  test('otro vehículo no coincide', () {
    expect(viajeEsDeVehiculo('Mazda (ZZZZ99)', 'ABCD12'), isFalse);
  });

  test('una patente que solo es parte de otra no coincide', () {
    expect(viajeEsDeVehiculo('Mazda (XABCD123)', 'ABCD12'), isFalse);
  });

  test('viaje sin patente ("Vehículo Principal") o patente vacía: no coincide', () {
    expect(viajeEsDeVehiculo('Vehículo Principal', 'ABCD12'), isFalse);
    expect(viajeEsDeVehiculo('Toyota (ABCD12)', ''), isFalse);
  });
}
