import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/documento_vehicular_model.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/screens/dashboard/dashboard_logica.dart';

GastoRegistro _g(DateTime fecha, int monto, [String? v, String titulo = 'Gasto']) =>
    (vehiculoId: v, fecha: fecha, monto: monto, titulo: titulo, detalle: null);

DocumentoVehicularModel _doc(String id, DateTime? vence) =>
    DocumentoVehicularModel(
      id: id,
      vehiculoId: 'v1',
      tipoDocumento: TipoDocumentoVehicular.soap,
      fechaVencimiento: vence,
      origenRegistro: 'manual',
      fechaRegistro: DateTime(2026, 1, 1),
    );

MantencionModel _mant(
  String id, {
  EstadoMantencion estado = EstadoMantencion.realizada,
  int? costo,
  DateTime? fecha,
  DateTime? proxima,
  int? proximoKm,
}) =>
    MantencionModel(
      id: id,
      uid: 'u',
      vehiculoId: 'v1',
      estado: estado,
      tipo: 'cambio_aceite',
      costo: costo,
      fecha: fecha,
      proximaFecha: proxima,
      proximoKilometraje: proximoKm,
      origenRegistro: 'manual',
    );

void main() {
  final hoy = DateTime(2026, 10, 28);

  group('calcularResumenGastos', () {
    test('sin datos: siempre 5 meses en \$0 y variación null', () {
      final r = calcularResumenGastos(const {}, ahora: hoy);
      expect(r.meses.length, 5);
      expect(r.totales, [0, 0, 0, 0, 0]);
      expect(r.totalMes, 0);
      expect(r.variacionPct, isNull);
      expect(r.desglose.keys.length, 4);
      expect(r.desglose.values.every((v) => v == 0), isTrue);
    });

    test('los meses van del más antiguo (junio) al actual (octubre)', () {
      final r = calcularResumenGastos(const {}, ahora: hoy);
      expect(r.meses.first, DateTime(2026, 6));
      expect(r.meses.last, DateTime(2026, 10));
    });

    test('cruza el cambio de año', () {
      final r = calcularResumenGastos(const {}, ahora: DateTime(2026, 2, 10));
      expect(r.meses.first, DateTime(2025, 10));
      expect(r.meses.last, DateTime(2026, 2));
    });

    test('suma por mes y categoría; ignora fuera de los 5 meses', () {
      final r = calcularResumenGastos({
        CategoriaGasto.tag: [_g(DateTime(2026, 10, 3), 1000)],
        CategoriaGasto.mantenciones: [
          _g(DateTime(2026, 10, 20), 5000),
          _g(DateTime(2026, 9, 1), 2000),
          _g(DateTime(2026, 5, 31), 9999), // antes de los 5 meses
          _g(DateTime(2026, 11, 1), 9999), // futuro
        ],
      }, ahora: hoy);
      expect(r.totalMes, 6000);
      expect(r.totalMesAnterior, 2000);
      expect(r.totales[1], 0); // julio
      expect(r.desglose[CategoriaGasto.tag], 1000);
      expect(r.desglose[CategoriaGasto.mantenciones], 5000);
      expect(r.desglose[CategoriaGasto.combustible], 0);
    });

    test('variación porcentual', () {
      final sube = calcularResumenGastos({
        CategoriaGasto.tag: [_g(DateTime(2026, 10, 1), 112), _g(DateTime(2026, 9, 1), 100)],
      }, ahora: hoy);
      expect(sube.variacionPct, closeTo(12, 0.001));
      final baja = calcularResumenGastos({
        CategoriaGasto.tag: [_g(DateTime(2026, 10, 1), 50), _g(DateTime(2026, 9, 1), 100)],
      }, ahora: hoy);
      expect(baja.variacionPct, closeTo(-50, 0.001));
    });
  });

  group('alturasPorPosicion (gráfico)', () {
    test('el mes que más gastó llega al tope y los demás bajan por puesto', () {
      expect(alturasPorPosicion([10, 50, 30, 0, 40]), [0.4, 1.0, 0.6, 0.0, 0.8]);
    });

    test('no importa cuánto más gastó: solo el orden', () {
      // Mismo orden de gasto, montos muy distintos: mismas alturas.
      expect(alturasPorPosicion([1, 1000000, 2, 3, 4]),
          alturasPorPosicion([10, 50, 20, 30, 40]));
      final alturas = alturasPorPosicion([1, 1000000, 2, 3, 4]);
      const esperadas = [0.2, 1.0, 0.4, 0.6, 0.8];
      for (var i = 0; i < esperadas.length; i++) {
        expect(alturas[i], closeTo(esperadas[i], 1e-9));
      }
    });

    test('gastos iguales comparten altura; sin gastos, 0', () {
      expect(alturasPorPosicion([20, 20, 5, 0, 0]), [1.0, 1.0, 0.8, 0.0, 0.0]);
      expect(alturasPorPosicion([0, 0, 0, 0, 0]), [0.0, 0.0, 0.0, 0.0, 0.0]);
    });
  });

  group('historial de gastos', () {
    final regs = {
      CategoriaGasto.mantenciones: [
        _g(DateTime(2026, 10, 20), 5000, 'v1', 'Cambio de aceite'),
        _g(DateTime(2026, 9, 5), 2000, 'v1', 'Frenos'),
      ],
      CategoriaGasto.tag: [_g(DateTime(2026, 10, 20), 8000, null, 'Viaje con peajes')],
      CategoriaGasto.combustible: [_g(DateTime(2026, 8, 1), 30000, 'v1', 'Carga de combustible')],
    };

    test('junta todo, del más reciente al más antiguo (a igual fecha, el mayor primero)', () {
      final m = movimientosDeGasto(regs);
      expect(m.map((x) => x.titulo), [
        'Viaje con peajes',
        'Cambio de aceite',
        'Frenos',
        'Carga de combustible',
      ]);
    });

    test('filtra por año y por mes', () {
      final m = movimientosDeGasto(regs);
      expect(filtrarMovimientos(m).length, 4);
      expect(filtrarMovimientos(m, anio: 2026, mes: 10).length, 2);
      expect(filtrarMovimientos(m, mes: 9).single.titulo, 'Frenos');
      expect(filtrarMovimientos(m, anio: 2025), isEmpty);
      expect(filtrarMovimientos(m, anio: 2026).length, 4);
      // Mismo mes de otro año no se mezcla.
      final conOtroAnio = movimientosDeGasto({
        ...regs,
        CategoriaGasto.estacionamientos: [_g(DateTime(2025, 10, 2), 700, null, 'Estacionamiento')],
      });
      expect(filtrarMovimientos(conOtroAnio, anio: 2026, mes: 10).length, 2);
      expect(filtrarMovimientos(conOtroAnio, anio: 2025, mes: 10).single.monto, 700);
    });

    test('años con gastos (recientes primero), suma y nombres', () {
      final m = movimientosDeGasto({
        ...regs,
        CategoriaGasto.estacionamientos: [_g(DateTime(2025, 3, 2), 700)],
      });
      expect(aniosConMovimientos(m), [2026, 2025]);
      expect(sumarMovimientos(movimientosDeGasto(regs)), 45000);
      expect(sumarMovimientos(const []), 0);
      expect(nombreMes(DateTime(2026, 10, 3)), 'Octubre 2026');
      expect(nombreDelMes(1), 'Enero');
      expect(nombreDelMes(12), 'Diciembre');
    });

    test('totales por categoría incluyen las cuatro', () {
      final t = totalesPorCategoria(movimientosDeGasto(regs));
      expect(t[CategoriaGasto.combustible], 30000);
      expect(t[CategoriaGasto.tag], 8000);
      expect(t[CategoriaGasto.mantenciones], 7000);
      expect(t[CategoriaGasto.estacionamientos], 0);
      expect(t.length, 4);
      expect(totalesPorCategoria(const []).values.every((v) => v == 0), isTrue);
    });

    test('sin gastos: todo vacío', () {
      expect(movimientosDeGasto(const {}), isEmpty);
      expect(aniosConMovimientos(const []), isEmpty);
    });
  });

  group('próxima mantención por kilometraje', () {
    test('suma 10.000 km al kilometraje del vehículo', () {
      expect(kilometrajeProximaMantencion(64500), 74500);
      expect(kilometrajeProximaMantencion(0), 10000);
      expect(intervaloMantencionKm, 10000);
    });

    test('sin kilometraje no hay cálculo', () {
      expect(kilometrajeProximaMantencion(null), isNull);
      expect(kilometrajeProximaMantencion(-5), isNull);
    });

    test('el intervalo se puede cambiar', () {
      expect(kilometrajeProximaMantencion(1000, intervalo: 5000), 6000);
    });
  });

  group('gastosDeMantenciones', () {
    test('solo realizadas con costo y fecha', () {
      final r = gastosDeMantenciones([
        _mant('ok', costo: 100, fecha: DateTime(2026, 10, 1)),
        _mant('sinCosto', fecha: DateTime(2026, 10, 1)),
        _mant('sinFecha', costo: 100),
        _mant('prog', estado: EstadoMantencion.programada, costo: 100, fecha: DateTime(2026, 10, 1)),
      ]);
      expect(r.length, 1);
      expect(r.single.monto, 100);
    });
  });

  group('formato', () {
    test('pesos con separador de miles', () {
      expect(formatearPesos(0), '\$ 0');
      expect(formatearPesos(999), '\$ 999');
      expect(formatearPesos(178500), '\$ 178.500');
      expect(formatearPesos(1234567), '\$ 1.234.567');
    });

    test('fecha dd/MM/yyyy', () {
      expect(formatearFecha(DateTime(2027, 3, 5)), '05/03/2027');
    });
  });

  group('calcularProximoVencimiento', () {
    test('sin documentos o sin fechas es null', () {
      expect(calcularProximoVencimiento(const [], ahora: hoy), isNull);
      expect(calcularProximoVencimiento([_doc('a', null)], ahora: hoy), isNull);
    });

    test('elige el más cercano y cuenta los días', () {
      final r = calcularProximoVencimiento([
        _doc('lejos', DateTime(2027, 3, 15)),
        _doc('cerca', DateTime(2026, 12, 12)),
      ], ahora: hoy)!;
      expect(r.documento.id, 'cerca');
      expect(r.dias, 45);
    });

    test('vencido da días negativos; hoy da 0', () {
      expect(calcularProximoVencimiento([_doc('a', DateTime(2026, 10, 20))], ahora: hoy)!.dias, -8);
      expect(calcularProximoVencimiento([_doc('a', DateTime(2026, 10, 28, 23))], ahora: hoy)!.dias, 0);
    });
  });

  group('calcularProximaMantencion', () {
    test('null si no hay programadas', () {
      expect(calcularProximaMantencion([_mant('a', costo: 1)]), isNull);
    });

    test('prefiere la de fecha más cercana; luego las de solo kilometraje', () {
      final soloKm = _mant('km', estado: EstadoMantencion.programada, proximoKm: 70000);
      final tarde = _mant('tarde', estado: EstadoMantencion.programada, proxima: DateTime(2027, 1, 1));
      final pronto = _mant('pronto', estado: EstadoMantencion.programada, proxima: DateTime(2026, 11, 1));
      expect(calcularProximaMantencion([soloKm, tarde, pronto])!.id, 'pronto');
      expect(calcularProximaMantencion([soloKm])!.id, 'km');
    });
  });

  group('estado global', () {
    test('peorEstado elige el más urgente', () {
      expect(peorEstado(['Todo al día', 'Atención requerida', 'Próximo vencimiento']),
          'Atención requerida');
      expect(peorEstado(['Todo al día', 'Sin información']), 'Todo al día');
      expect(peorEstado(const []), 'Sin información');
    });

    test('subtítulo según estado', () {
      expect(subtituloGlobal('Todo al día', hayVehiculos: true), 'Todo en orden, sigamos así.');
      expect(subtituloGlobal('Todo al día', hayVehiculos: false), contains('Registra'));
    });
  });
}
