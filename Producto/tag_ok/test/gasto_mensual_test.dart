import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/trip_history.dart';
import 'package:tag_ok/utils/alerta_presupuesto.dart';

TripHistory _viaje(DateTime fecha, double costo) => TripHistory(
      id: '',
      date: fecha,
      totalCost: costo,
      tolls: const [],
      distanceKm: 1,
      duration: '1 min',
      vehicleName: 'Hyundai (JHGK50)',
    );

void main() {
  final octubre = DateTime(2026, 10, 15, 12);

  group('gastoDelMes', () {
    test('suma solo los viajes del mes en curso', () {
      final viajes = [
        _viaje(DateTime(2026, 10, 1, 8), 10000),
        _viaje(DateTime(2026, 10, 31, 23, 59), 5000),
        _viaje(DateTime(2026, 9, 30, 23, 59), 90000), // mes anterior
        _viaje(DateTime(2026, 11, 1, 0, 0), 70000), // mes siguiente
      ];
      expect(gastoDelMes(viajes, octubre), 15000);
    });

    test('un viaje de otro mes NO suma', () {
      expect(gastoDelMes([_viaje(DateTime(2026, 9, 20), 80000)], octubre), 0);
    });

    test('el mismo mes de otro año NO suma (compara año y mes)', () {
      expect(gastoDelMes([_viaje(DateTime(2025, 10, 15), 80000)], octubre), 0);
    });

    test('sin viajes el gasto es 0', () {
      expect(gastoDelMes(const [], octubre), 0);
    });

    test('cambio de mes reinicia el gasto', () {
      final viajes = [_viaje(DateTime(2026, 10, 28), 60000)];
      expect(gastoDelMes(viajes, DateTime(2026, 10, 30)), 60000);
      expect(gastoDelMes(viajes, DateTime(2026, 11, 1)), 0);
      // y también al cambiar de año (diciembre -> enero)
      final dic = [_viaje(DateTime(2026, 12, 20), 40000)];
      expect(gastoDelMes(dic, DateTime(2026, 12, 31)), 40000);
      expect(gastoDelMes(dic, DateTime(2027, 1, 1)), 0);
    });
  });

  group('alerta con el gasto del mes', () {
    test('el historial de meses anteriores ya no dispara la alerta', () {
      // Antes: 90.000 (sep) + 20.000 (oct) = 110.000 -> alerta del 100 %.
      final viajes = [
        _viaje(DateTime(2026, 9, 10), 90000),
        _viaje(DateTime(2026, 10, 10), 20000),
      ];
      const limite = 50000.0;
      expect(umbralDeAlerta(gastoDelMes(viajes, octubre), limite), isNull);
    });

    test('el gasto del mes que supera el límite sí dispara la alerta', () {
      final viajes = [
        _viaje(DateTime(2026, 10, 2), 30000),
        _viaje(DateTime(2026, 10, 9), 25000),
      ];
      expect(umbralDeAlerta(gastoDelMes(viajes, octubre), 50000), 100);
    });

    test('límite 0 no dispara alerta aunque haya gasto del mes', () {
      final viajes = [_viaje(DateTime(2026, 10, 2), 30000)];
      expect(umbralDeAlerta(gastoDelMes(viajes, octubre), 0), isNull);
    });

    test('cambio de mes reinicia: lo gastado en octubre no cuenta en noviembre', () {
      final viajes = [_viaje(DateTime(2026, 10, 28), 60000)];
      expect(umbralDeAlerta(gastoDelMes(viajes, DateTime(2026, 10, 29)), 50000), 100);
      expect(umbralDeAlerta(gastoDelMes(viajes, DateTime(2026, 11, 2)), 50000), isNull);
    });
  });

  group('claveAlertaMensual (la clave de "alerta ya vista")', () {
    test('mantiene el formato histórico año-mes_umbral, sin cero a la izquierda', () {
      expect(claveAlertaMensual(DateTime(2026, 10, 5), 75), '2026-10_75');
      expect(claveAlertaMensual(DateTime(2026, 3, 5), 50), '2026-3_50');
    });

    test('es la misma durante todo el mes y cambia al cambiar de mes o año', () {
      final a = claveAlertaMensual(DateTime(2026, 10, 1), 100);
      expect(claveAlertaMensual(DateTime(2026, 10, 31, 23, 59), 100), a);
      expect(claveAlertaMensual(DateTime(2026, 11, 1), 100), isNot(a));
      expect(claveAlertaMensual(DateTime(2027, 10, 1), 100), isNot(a));
    });

    test('mismo criterio de mes que gastoDelMes: clave igual <=> mismo mes calendario', () {
      final fechas = [
        DateTime(2026, 10, 1), DateTime(2026, 10, 31), DateTime(2026, 11, 1),
        DateTime(2025, 10, 15), DateTime(2027, 1, 1), DateTime(2026, 12, 31),
      ];
      for (final x in fechas) {
        for (final y in fechas) {
          final mismoMes = x.year == y.year && x.month == y.month;
          expect(claveAlertaMensual(x, 90) == claveAlertaMensual(y, 90), mismoMes, reason: '$x vs $y');
          expect(gastoDelMes([_viaje(x, 100)], y) > 0, mismoMes, reason: '$x vs $y');
        }
      }
    });
  });
}
