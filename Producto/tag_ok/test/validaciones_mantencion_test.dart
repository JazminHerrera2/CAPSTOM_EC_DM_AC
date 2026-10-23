import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/data/models/tipo_mantencion.dart';
import 'package:tag_ok/features/registro_inteligente/mantencion_extraction.dart';
import 'package:tag_ok/utils/validaciones_mantencion.dart';

MantencionModel _m({
  int? km,
  DateTime? fecha,
  String? numero,
  EstadoMantencion estado = EstadoMantencion.realizada,
}) =>
    MantencionModel(
      id: '',
      vehiculoId: 'v1',
      estado: estado,
      tipo: TipoMantencion.cambioAceite,
      kilometraje: km,
      fecha: fecha,
      numeroComprobante: numero,
    );

/// Lo que devolvería la IA para la factura electrónica N° 284479 (valores
/// escritos a mano: no hay imagen ni datos personales en las pruebas).
Map<String, dynamic> _facturaSigloXxi({Map<String, dynamic> cambios = const {}}) =>
    {
      'tipo_mantencion': 'cambio_aceite',
      'tipo_otro': null,
      'fecha': '2020-10-28',
      'kilometraje': null,
      'taller': 'Siglo XXI',
      'costo': '87.520',
      'neto': '73.546',
      'descripcion': 'Aceite de motor, filtro de aceite y mano de obra',
      'tipo_comprobante': 'factura',
      'numero_comprobante': 'N° 284479',
      'campos_dudosos': <String>[],
      'componentes': ['cambio_aceite_motor'],
      ...cambios,
    };

void main() {
  final hoy = DateTime(2026, 10, 22);

  group('factura 284479 (caso de prueba real)', () {
    test('se lee fecha de emisión, total, taller, tipo y número; km vacío', () {
      final m = parseMantencionExtraida(_facturaSigloXxi());

      expect(m.fecha, DateTime(2020, 10, 28));
      expect(m.costo, 87520);
      expect(m.taller, 'Siglo XXI');
      expect(m.tipo, TipoMantencion.cambioAceite);
      expect(m.tipoComprobante, TipoComprobante.factura);
      expect(m.numeroComprobante, '284479');
      expect(m.kilometraje, isNull);
      expect(m.camposDudosos, isEmpty);
      expect(m.confianza, 1.0);
    });

    test('el total cuadra con el neto (73.546 × 1,19 = 87.520)', () {
      expect(totalCuadraConNeto(total: 87520, neto: 73546), isTrue);
    });

    test('el documento es antiguo: advierte, no bloquea', () {
      final fecha = parseMantencionExtraida(_facturaSigloXxi()).fecha!;
      expect(estadoFechaMantencion(fecha, hoy), EstadoFechaMantencion.antigua);
      expect(mensajeFechaAntigua(fecha), 'Este documento es de 2020, ¿es correcto?');
    });

    test('la fecha se entiende con guiones y con el mes en palabras', () {
      for (final texto in [
        '28-10-2020',
        '28/10/2020',
        '28 de octubre de 2020',
        '2020-10-28',
      ]) {
        final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {'fecha': texto}));
        expect(m.fecha, DateTime(2020, 10, 28), reason: texto);
        expect(m.camposDudosos.contains(dudosoFecha), isFalse, reason: texto);
      }
    });
  });

  group('lo que no se lee queda vacío y resaltado, nunca inventado', () {
    test('sin fecha: queda vacía y marcada', () {
      final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {'fecha': null}));
      expect(m.fecha, isNull);
      expect(m.camposDudosos, contains(dudosoFecha));
    });

    test('fecha ilegible o imposible: vacía y marcada', () {
      for (final texto in ['ayer', '2026-02-31', '']) {
        final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {'fecha': texto}));
        expect(m.fecha, isNull, reason: texto);
        expect(m.camposDudosos, contains(dudosoFecha), reason: texto);
      }
    });

    test('fecha futura: se descarta y se marca', () {
      final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {'fecha': '2099-01-01'}));
      expect(m.fecha, isNull);
      expect(m.camposDudosos, contains(dudosoFecha));
    });

    test('total que no cuadra con el neto: se marca el costo, no se elige otro', () {
      final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {'costo': '87.000'}));
      expect(m.costo, 87000); // se conserva lo leído
      expect(m.camposDudosos, contains(dudosoCosto));
      expect(m.confianza, lessThan(1.0));
    });

    test('sin neto no se puede comprobar: no se marca por eso', () {
      final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {'neto': null}));
      expect(m.camposDudosos, isEmpty);
    });

    test('sin costo: queda marcado', () {
      final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {'costo': null}));
      expect(m.costo, isNull);
      expect(m.camposDudosos, contains(dudosoCosto));
    });

    test('los campos dudosos que reporta la IA se respetan; los inventados no', () {
      final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {
        'campos_dudosos': ['taller', 'no_existe'],
      }));
      expect(m.camposDudosos, {dudosoTaller});
    });

    test('las observaciones ya no se extraen (solo los campos pedidos)', () {
      final m = parseMantencionExtraida(_facturaSigloXxi(cambios: {
        'observaciones': 'Cliente: dato personal',
      }));
      expect(m.observaciones, isNull);
    });
  });

  group('fecha', () {
    test('vacía, futura, de hoy, de hace 12 meses y de hace más de 12 meses', () {
      expect(estadoFechaMantencion(null, hoy), EstadoFechaMantencion.vacia);
      expect(estadoFechaMantencion(DateTime(2026, 10, 23), hoy),
          EstadoFechaMantencion.futura);
      expect(estadoFechaMantencion(DateTime(2026, 10, 22, 23, 59), hoy),
          EstadoFechaMantencion.ok);
      expect(estadoFechaMantencion(DateTime(2025, 10, 22), hoy),
          EstadoFechaMantencion.ok); // exactamente 12 meses: no advierte
      expect(estadoFechaMantencion(DateTime(2025, 10, 21), hoy),
          EstadoFechaMantencion.antigua);
    });
  });

  group('kilometraje', () {
    final existentes = [
      _m(km: 70000, fecha: DateTime(2026, 3, 1)),
      _m(km: 72450, fecha: DateTime(2026, 9, 15)),
      _m(km: 90000, fecha: DateTime(2027, 1, 1)), // posterior: no cuenta
      _m(km: null, fecha: DateTime(2026, 6, 1)),
      _m(
        km: 99999,
        fecha: DateTime(2026, 8, 1),
        estado: EstadoMantencion.programada,
      ),
    ];

    test('menor al de una mantención anterior: advierte con la mayor', () {
      final r = kilometrajeMenorAlAnterior(
        km: 60000,
        fecha: DateTime(2026, 10, 1),
        existentes: existentes,
      );
      expect(r, isNotNull);
      expect(r!.km, 72450);
      expect(r.fecha, DateTime(2026, 9, 15));
    });

    test('igual o mayor: no advierte', () {
      for (final km in [72450, 80000]) {
        expect(
          kilometrajeMenorAlAnterior(
            km: km,
            fecha: DateTime(2026, 10, 1),
            existentes: existentes,
          ),
          isNull,
        );
      }
    });

    test('una mantención antigua (2020) se compara solo con las anteriores a ella', () {
      expect(
        kilometrajeMenorAlAnterior(
          km: 30000,
          fecha: DateTime(2020, 10, 28),
          existentes: existentes,
        ),
        isNull,
      );
    });

    test('sugerencia: el mayor entre el del vehículo y el de las mantenciones', () {
      final historial = [
        _m(km: 70000, fecha: DateTime(2026, 3, 1)),
        _m(km: 72450, fecha: DateTime(2026, 9, 15)),
        _m(km: null, fecha: DateTime(2026, 6, 1)),
        _m(
          km: 99999,
          fecha: DateTime(2026, 8, 1),
          estado: EstadoMantencion.programada, // no cuenta
        ),
      ];
      expect(kilometrajeSugerido(kmVehiculo: 75000, existentes: historial),
          75000); // el del vehículo es mayor
      expect(kilometrajeSugerido(kmVehiculo: 1000, existentes: historial),
          72450); // el de la última mantención es mayor
      expect(kilometrajeSugerido(kmVehiculo: null, existentes: historial),
          72450);
      expect(kilometrajeSugerido(kmVehiculo: null, existentes: const []),
          isNull);
    });
  });

  group('número de documento', () {
    final existentes = [
      _m(numero: '284479'),
      _m(numero: ' 100 '),
      _m(numero: '555', estado: EstadoMantencion.programada),
    ];

    test('ya registrado en el vehículo: posible duplicado', () {
      expect(numeroDocumentoDuplicado('284479', existentes), isTrue);
      expect(numeroDocumentoDuplicado(' 284479 ', existentes), isTrue);
      expect(numeroDocumentoDuplicado('100', existentes), isTrue);
    });

    test('número nuevo, vacío o de una programada: no es duplicado', () {
      expect(numeroDocumentoDuplicado('999', existentes), isFalse);
      expect(numeroDocumentoDuplicado('', existentes), isFalse);
      expect(numeroDocumentoDuplicado(null, existentes), isFalse);
      expect(numeroDocumentoDuplicado('555', existentes), isFalse);
    });
  });

  group('total contra neto', () {
    test('tolerancia: el mayor entre \$10 y el 0,5%', () {
      expect(totalCuadraConNeto(total: 119, neto: 100), isTrue);
      expect(totalCuadraConNeto(total: 125, neto: 100), isTrue); // dentro de $10
      expect(totalCuadraConNeto(total: 135, neto: 100), isFalse);
      // 0,5% de 1.000.000 = 5.000
      expect(totalCuadraConNeto(total: 1194000, neto: 1000000), isTrue);
      expect(totalCuadraConNeto(total: 1200000, neto: 1000000), isFalse);
    });
  });

  group('punto de extensión y compatibilidad', () {
    test('la próxima mantención sugerida está vacía: no se inventan intervalos', () {
      expect(
        sugerirProximaMantencion(
          tipo: TipoMantencion.cambioAceite,
          kilometraje: 72450,
          fecha: DateTime(2026, 10, 1),
        ),
        isNull,
      );
    });

    test('una mantención antigua, sin los campos nuevos, se lee sin errores', () {
      final vieja = MantencionModel.fromJson({
        'uid': 'u1',
        'vehiculo_id': 'v1',
        'estado': 'realizada',
        'tipo': 'frenos',
        'origen_registro': 'manual',
      }, 'id1');

      expect(vieja.componentes, isEmpty);
      expect(vieja.proximaFecha, isNull);
      expect(vieja.proximoKilometraje, isNull);
      expect(vieja.numeroComprobante, isNull);
      expect(vieja.confianzaIa, isNull);
      expect(numeroDocumentoDuplicado('1', [vieja]), isFalse);
    });
  });
}
