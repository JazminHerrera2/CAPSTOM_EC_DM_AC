import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/tipo_mantencion.dart';
import 'package:tag_ok/features/registro_inteligente/mantencion_extraction.dart';

void main() {
  test('interpreta una boleta completa', () {
    final m = parseMantencionExtraida({
      'tipo_mantencion': 'cambio_aceite',
      'fecha': '2026-09-15',
      'kilometraje': '72.450',
      'taller': '  Taller AutoPro ',
      'costo': r'$45.990',
      'descripcion': 'Aceite 5W30 y filtro',
      'observaciones': '',
    });
    expect(m.tipo, TipoMantencion.cambioAceite);
    expect(m.fecha, DateTime(2026, 9, 15));
    expect(m.kilometraje, 72450);
    expect(m.taller, 'Taller AutoPro');
    expect(m.costo, 45990);
    expect(m.descripcion, 'Aceite 5W30 y filtro');
    expect(m.observaciones, isNull);
    expect(m.vacia, isFalse);
  });

  test('acepta fecha dd/mm/aaaa, rechaza imposibles y descarta decimales', () {
    expect(parseMantencionExtraida({'fecha': '05/03/2026'}).fecha,
        DateTime(2026, 3, 5));
    expect(parseMantencionExtraida({'fecha': '2026-02-31'}).fecha, isNull);
    expect(parseMantencionExtraida({'costo': '45000,50'}).costo, 45000);
  });

  test('descarta valores fuera de rango o tipo desconocido', () {
    final m = parseMantencionExtraida({
      'tipo_mantencion': 'inventado',
      'kilometraje': '99999999',
      'costo': '99999999999',
    });
    expect(m.tipo, isNull);
    expect(m.kilometraje, isNull);
    expect(m.costo, isNull);
    expect(m.vacia, isTrue);
  });

  test('"otra" conserva tipo_otro, otros tipos lo ignoran y se recortan largos',
      () {
    final otra = parseMantencionExtraida(
        {'tipo_mantencion': 'otra', 'tipo_otro': 'Pulido'});
    expect(otra.tipoOtro, 'Pulido');
    final frenos = parseMantencionExtraida(
        {'tipo_mantencion': 'frenos', 'tipo_otro': 'x'});
    expect(frenos.tipoOtro, isNull);
    final largo = parseMantencionExtraida(
        {'descripcion': 'a' * 800, 'taller': 'b' * 200});
    expect(largo.descripcion!.length, 500);
    expect(largo.taller!.length, 100);
  });
}
