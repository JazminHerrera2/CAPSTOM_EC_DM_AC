import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/features/registro_inteligente/vehiculo_extraction.dart';

void main() {
  final hoy = DateTime(2026, 10, 22);

  test('interpreta el permiso de Buin (patente con dígito verificador)', () {
    final v = parseVehiculoExtraido({
      'patente': 'KZZZ60-0',
      'marca': ' Kia ',
      'modelo': 'RIO 4 LX 1.4L 6',
      'anio': '2019',
      'tipo_vehiculo': 'AUTO',
      'tipo_combustible': 'Gasolina',
    }, ahora: hoy);
    expect(v.patente, 'KZZZ60');
    expect(v.marca, 'Kia');
    expect(v.modelo, 'RIO 4 LX 1.4L 6');
    expect(v.anio, 2019);
    expect(v.tipoVehiculo, 'AUTO');
    expect(v.tipoCombustible, 'Gasolina');
    expect(v.vacio, isFalse);
  });

  test('año con separador de miles ("2.008") y año fuera de rango', () {
    expect(parseVehiculoExtraido({'anio': '2.008'}, ahora: hoy).anio, 2008);
    expect(parseVehiculoExtraido({'anio': '1850'}, ahora: hoy).anio, isNull);
    expect(parseVehiculoExtraido({'anio': '2040'}, ahora: hoy).anio, isNull);
    expect(parseVehiculoExtraido({'anio': 'abc'}, ahora: hoy).anio, isNull);
  });

  test('valores que no son del catálogo se descartan', () {
    final v = parseVehiculoExtraido({
      'tipo_vehiculo': 'CAMION',
      'tipo_combustible': 'Plutonio',
    }, ahora: hoy);
    expect(v.tipoVehiculo, isNull);
    expect(v.tipoCombustible, isNull);
  });

  test('sin datos: queda vacío', () {
    expect(parseVehiculoExtraido({}, ahora: hoy).vacio, isTrue);
    expect(
      parseVehiculoExtraido({'patente': '  ', 'marca': ''}, ahora: hoy).vacio,
      isTrue,
    );
  });
}
