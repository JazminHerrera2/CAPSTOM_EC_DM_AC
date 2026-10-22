import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/componente_mantencion_model.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/data/models/tipo_mantencion.dart';
import 'package:tag_ok/features/registro_inteligente/mantencion_extraction.dart';

void main() {
  mainComponentes();
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

  test('lee el comprobante y limpia el prefijo del folio', () {
    final m = parseMantencionExtraida({
      'tipo_comprobante': 'boleta',
      'numero_comprobante': 'N° 458123',
    });
    expect(m.tipoComprobante, TipoComprobante.boleta);
    expect(m.numeroComprobante, '458123');
    expect(m.vacia, isFalse);

    expect(parseMantencionExtraida({'numero_comprobante': 'Folio: 10234'})
        .numeroComprobante, '10234');
    expect(parseMantencionExtraida({'numero_comprobante': 'No. 77801'})
        .numeroComprobante, '77801');
    expect(parseMantencionExtraida({'tipo_comprobante': 'recibo'})
        .tipoComprobante, isNull);
    expect(parseMantencionExtraida({'numero_comprobante': '9' * 80})
        .numeroComprobante!.length, 50);
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

void mainComponentes() {
  test('lee los componentes, ignora ids desconocidos y repetidos', () {
    final m = parseMantencionExtraida({
      'componentes': ['cambio_aceite_motor', 'frenos', 'inventado', 'frenos'],
    });
    expect(m.componentes, ['cambio_aceite_motor', 'frenos']);
    expect(m.vacia, isFalse);
    expect(parseMantencionExtraida({}).componentes, isEmpty);
    expect(parseMantencionExtraida({'componentes': 'frenos'}).componentes,
        isEmpty);
  });

  test('usa la lista de componentes recibida (la tabla es editable)', () {
    final m = parseMantencionExtraida(
      {'componentes': ['alineacion', 'frenos']},
      componentesValidos: const [
        ComponenteMantencion(id: 'alineacion', nombre: 'Alineación', orden: 1),
      ],
    );
    expect(m.componentes, ['alineacion']);
  });

  test('la mantención guarda y lee sus componentes', () {
    final m = MantencionModel(
      id: '',
      vehiculoId: 'v1',
      estado: EstadoMantencion.realizada,
      tipo: TipoMantencion.cambioAceite,
      componentes: const ['bateria', 'frenos'],
    );
    expect(m.toJson()['componentes'], ['bateria', 'frenos']);
    expect(MantencionModel.fromJson(m.toJson(), 'x').componentes,
        ['bateria', 'frenos']);
    expect(MantencionModel.fromJson({'vehiculo_id': 'v1'}, 'y').componentes,
        isEmpty);
  });

  test('la próxima mantención es a un año de la última', () {
    expect(proximaMantencionAnual(DateTime(2026, 3, 5)), DateTime(2027, 3, 5));
    expect(proximaMantencionAnual(DateTime(2024, 2, 29)), DateTime(2025, 2, 28));
  });
}
