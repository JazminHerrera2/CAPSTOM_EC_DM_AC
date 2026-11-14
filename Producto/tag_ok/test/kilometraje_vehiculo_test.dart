import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/vehiculo_service.dart';

void main() {
  test('un kilometraje mayor actualiza el del vehículo', () {
    expect(kilometrajeNuevoDelVehiculo(actual: 60000, registrado: 74100), 74100);
  });

  test('si el vehículo no tenía kilometraje, se usa el registrado', () {
    expect(kilometrajeNuevoDelVehiculo(actual: null, registrado: 74100), 74100);
  });

  test('nunca baja: un registro antiguo con menos km no cambia nada', () {
    expect(kilometrajeNuevoDelVehiculo(actual: 74100, registrado: 60000), isNull);
    expect(kilometrajeNuevoDelVehiculo(actual: 74100, registrado: 74100), isNull);
  });

  test('sin kilometraje o con un valor inválido no cambia nada', () {
    expect(kilometrajeNuevoDelVehiculo(actual: 60000, registrado: null), isNull);
    expect(kilometrajeNuevoDelVehiculo(actual: null, registrado: 0), isNull);
    expect(kilometrajeNuevoDelVehiculo(actual: null, registrado: -5), isNull);
  });
}
