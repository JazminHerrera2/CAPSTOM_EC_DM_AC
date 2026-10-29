import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/utils/busqueda_mantencion.dart';

MantencionModel _m({
  String tipo = 'Cambio de aceite',
  String? taller,
  String? descripcion,
  String? observaciones,
  TipoComprobante? comprobante,
  String? numero,
  List<String> componentes = const [],
}) =>
    MantencionModel(
      id: 'm1',
      uid: 'u',
      vehiculoId: 'v1',
      estado: EstadoMantencion.realizada,
      tipo: tipo,
      taller: taller,
      descripcion: descripcion,
      observaciones: observaciones,
      tipoComprobante: comprobante,
      numeroComprobante: numero,
      componentes: componentes,
      origenRegistro: 'manual',
    );

void main() {
  final completa = _m(
    taller: 'Taller Los Andes',
    descripcion: 'Se cambió el filtro de aire y se revisó la presión',
    observaciones: 'Volver en 10.000 km',
    comprobante: TipoComprobante.factura,
    numero: 'F-12345',
    componentes: const ['frenos', 'filtro_aire'],
  );

  test('un buscador vacío coincide con todo', () {
    expect(coincideConBusqueda(completa, ''), isTrue);
    expect(coincideConBusqueda(completa, '   '), isTrue);
  });

  test('busca en cada campo de texto', () {
    for (final q in [
      'aceite', // tipo
      'los andes', // taller
      'presión', // descripción
      'volver', // observaciones
      'factura', // tipo de comprobante
      'f-12345', // número de comprobante
      'frenos', // componente por id
      'filtro de aire', // componente por nombre
    ]) {
      expect(coincideConBusqueda(completa, q), isTrue, reason: q);
    }
  });

  test('ignora mayúsculas y tildes', () {
    expect(coincideConBusqueda(completa, 'PRESION'), isTrue);
    expect(coincideConBusqueda(completa, 'se cambio'), isTrue);
    expect(coincideConBusqueda(_m(tipo: 'Revisión general'), 'revision'), isTrue);
  });

  test('varias palabras: todas deben aparecer, en cualquier orden', () {
    expect(coincideConBusqueda(completa, 'andes aceite'), isTrue);
    expect(coincideConBusqueda(completa, 'andes neumáticos'), isFalse);
  });

  test('lo que no está en ningún texto no coincide', () {
    expect(coincideConBusqueda(completa, 'bateria'), isFalse);
    expect(coincideConBusqueda(_m(), 'taller'), isFalse);
  });
}
