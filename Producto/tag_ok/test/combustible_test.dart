import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/abastecimiento_model.dart';
import 'package:tag_ok/features/registro_inteligente/combustible_extraction.dart';
import 'package:tag_ok/screens/combustible/gasto_combustible.dart';

AbastecimientoModel carga({
  required DateTime fecha,
  int? total,
  double? cantidad,
  TipoAbastecimiento tipo = TipoAbastecimiento.combustible,
}) =>
    AbastecimientoModel(
      id: 'x',
      vehiculoId: 'v',
      fecha: fecha,
      total: total,
      cantidad: cantidad,
      tipoAbastecimiento: tipo,
    );

void main() {
  group('decimalDeTexto', () {
    test('entiende punto o coma decimal y miles', () {
      expect(decimalDeTexto('32.451'), 32.451);
      expect(decimalDeTexto('32,451'), 32.451);
      expect(decimalDeTexto('1.289,9'), 1289.9);
      expect(decimalDeTexto('1,289.9'), 1289.9);
      expect(decimalDeTexto('1.234.567'), 1234567);
      expect(decimalDeTexto('45 L'), 45);
      expect(decimalDeTexto(''), isNull);
      expect(decimalDeTexto(null), isNull);
    });
  });

  group('parseAbastecimientoExtraido', () {
    final ahora = DateTime(2026, 11, 1);

    test('lee una boleta completa y cuadra el total', () {
      final d = parseAbastecimientoExtraido({
        'estacion_servicio': 'Copec Providencia',
        'fecha': '2026-10-28',
        'tipo_abastecimiento': 'combustible',
        'tipo_combustible': 'Gasolina 95',
        'cantidad': '32.451',
        'precio_unitario': '1289',
        'total': '41.839',
        'kilometraje': null,
        'campos_dudosos': <String>[],
      }, ahora: ahora);
      expect(d.estacion, 'Copec Providencia');
      expect(d.fecha, DateTime(2026, 10, 28));
      expect(d.tipoCombustible, 'Gasolina 95');
      expect(d.cantidad, 32.451);
      expect(d.precioUnitario, 1289);
      expect(d.total, 41839);
      expect(d.camposDudosos, isEmpty);
      expect(d.confianza, 1.0);
      expect(d.vacia, isFalse);
    });

    test('marca dudoso el total que no cuadra y la fecha ilegible', () {
      final d = parseAbastecimientoExtraido({
        'fecha': null,
        'cantidad': '30',
        'precio_unitario': '1000',
        'total': '50000',
        'campos_dudosos': <String>[],
      }, ahora: ahora);
      expect(d.camposDudosos, containsAll([dudosoCargaTotal, dudosoCargaFecha]));
    });

    test('descarta fecha futura y valores fuera de rango', () {
      final d = parseAbastecimientoExtraido({
        'fecha': '2027-05-01',
        'cantidad': '9999999',
        'precio_unitario': '0',
        'total': '99999999999',
        'kilometraje': '99999999',
        'campos_dudosos': <String>[],
      }, ahora: ahora);
      expect(d.fecha, isNull);
      expect(d.cantidad, isNull);
      expect(d.precioUnitario, isNull);
      expect(d.total, isNull);
      expect(d.kilometraje, isNull);
      expect(d.vacia, isTrue);
    });

    test('deduce carga eléctrica desde el combustible', () {
      final d = parseAbastecimientoExtraido({
        'tipo_combustible': 'Eléctrico',
        'campos_dudosos': <String>[],
      }, ahora: ahora);
      expect(d.tipoAbastecimiento, TipoAbastecimiento.cargaElectrica);
    });
  });

  group('completarCarga', () {
    test('calcula el dato que falta', () {
      expect(completarCarga(cantidad: 30, precioUnitario: 1000).total, 30000);
      expect(completarCarga(total: 30000, precioUnitario: 1000).cantidad, 30);
      expect(completarCarga(total: 30000, cantidad: 30).precioUnitario, 1000);
    });

    test('con menos de dos datos no inventa nada', () {
      final r = completarCarga(total: 30000);
      expect(r.cantidad, isNull);
      expect(r.precioUnitario, isNull);
    });

    test('respeta los datos que ya venían', () {
      final r = completarCarga(cantidad: 10, precioUnitario: 1000, total: 9000);
      expect(r.total, 9000);
    });
  });

  group('calcularResumenMes', () {
    final mes = DateTime(2026, 11, 15);

    test('suma solo el mes pedido y separa litros de kWh', () {
      final r = calcularResumenMes([
        carga(fecha: DateTime(2026, 11, 2), total: 40000, cantidad: 30),
        carga(fecha: DateTime(2026, 11, 20), total: 10000, cantidad: 8.5),
        carga(
          fecha: DateTime(2026, 11, 21),
          total: 5000,
          cantidad: 20,
          tipo: TipoAbastecimiento.cargaElectrica,
        ),
        carga(fecha: DateTime(2026, 10, 30), total: 99999, cantidad: 99),
      ], mes);
      expect(r.total, 55000);
      expect(r.cantidad, 3);
      expect(r.litros, 38.5);
      expect(r.kwh, 20);
    });

    test('un registro parcial cuenta como carga pero no suma dinero', () {
      final r = calcularResumenMes([carga(fecha: DateTime(2026, 11, 3))], mes);
      expect(r.cantidad, 1);
      expect(r.total, 0);
    });
  });

  test('formatoCantidad usa coma y quita ceros sobrantes', () {
    expect(formatoCantidad(32.451), '32,451');
    expect(formatoCantidad(45), '45');
    expect(formatoCantidad(12.5), '12,5');
  });
}
