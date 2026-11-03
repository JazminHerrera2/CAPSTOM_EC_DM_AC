import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tag_ok/data/models/route_model.dart';
import 'package:tag_ok/data/models/trip_history.dart';

TollData _peaje(
  String nombre,
  double costo, {
  bool cruzado = false,
  DateTime? cruzadoA,
}) =>
    TollData(
      location: const LatLng(-33.45, -70.66),
      name: nombre,
      cost: costo,
      isCrossed: cruzado,
      crossedAt: cruzadoA,
    );

void main() {
  final fecha = DateTime(2026, 10, 15, 8, 0);

  group('TripHistory.desdePeajes', () {
    test('con 2 pórticos cruzados: tolls[] tiene 2 y totalCost es la suma', () {
      final viaje = TripHistory.desdePeajes(
        peajes: [
          _peaje('PA32', 400, cruzado: true, cruzadoA: DateTime(2026, 10, 15, 8, 5)),
          _peaje('PA28', 612.5, cruzado: true, cruzadoA: DateTime(2026, 10, 15, 8, 20)),
        ],
        distanceKm: 12.5,
        duration: '25 min',
        vehicleName: 'Hyundai (JHGK50)',
        fecha: fecha,
      );

      expect(viaje.tolls.length, 2);
      expect(viaje.totalCost, 1012.5);
      expect(viaje.tolls.map((t) => t.name), ['PA32', 'PA28']);
      expect(viaje.tolls.map((t) => t.cost), [400, 612.5]);
      expect(viaje.tolls[0].timestamp, DateTime(2026, 10, 15, 8, 5));
      expect(viaje.date, fecha);
      expect(viaje.distanceKm, 12.5);
      expect(viaje.duration, '25 min');
      expect(viaje.vehicleName, 'Hyundai (JHGK50)');
      expect(viaje.id, isEmpty, reason: 'el id lo genera Firestore');
    });

    test('los pórticos sin cruzar NO entran a tolls[] ni a totalCost', () {
      final viaje = TripHistory.desdePeajes(
        peajes: [
          _peaje('PA32', 400, cruzado: true, cruzadoA: DateTime(2026, 10, 15, 8, 5)),
          _peaje('PA28', 600), // sin cruzar
          _peaje('PA24', 287.86), // sin cruzar
        ],
        distanceKm: 5,
        duration: '10 min',
        vehicleName: 'X',
        fecha: fecha,
      );

      expect(viaje.tolls.map((t) => t.name), ['PA32']);
      expect(viaje.totalCost, 400);
    });

    test('ningún pórtico cruzado: viaje sin peajes y costo 0', () {
      final viaje = TripHistory.desdePeajes(
        peajes: [_peaje('PA32', 400), _peaje('PA28', 600)],
        distanceKm: 5,
        duration: '10 min',
        vehicleName: 'X',
        fecha: fecha,
      );

      expect(viaje.tolls, isEmpty);
      expect(viaje.totalCost, 0);
    });

    test('lista de pórticos vacía: viaje sin peajes y costo 0', () {
      final viaje = TripHistory.desdePeajes(
        peajes: const [],
        distanceKm: 0,
        duration: '0 min',
        vehicleName: 'X',
        fecha: fecha,
      );

      expect(viaje.tolls, isEmpty);
      expect(viaje.totalCost, 0);
    });

    test('un pórtico cruzado sin hora de cruce usa la fecha del viaje', () {
      final viaje = TripHistory.desdePeajes(
        peajes: [_peaje('PA32', 400, cruzado: true)],
        distanceKm: 1,
        duration: '1 min',
        vehicleName: 'X',
        fecha: fecha,
      );

      expect(viaje.tolls.single.timestamp, fecha);
    });

    test('mantiene el orden de la ruta y no modifica la lista original', () {
      final peajes = [
        _peaje('A', 100, cruzado: true, cruzadoA: DateTime(2026, 10, 15, 8, 1)),
        _peaje('B', 200),
        _peaje('C', 300, cruzado: true, cruzadoA: DateTime(2026, 10, 15, 8, 3)),
      ];
      final viaje = TripHistory.desdePeajes(
        peajes: peajes,
        distanceKm: 1,
        duration: '1 min',
        vehicleName: 'X',
        fecha: fecha,
      );

      expect(viaje.tolls.map((t) => t.name), ['A', 'C']);
      expect(peajes.length, 3);
    });

    test('toMap deja el formato que validan las reglas (6 campos, tolls con name/cost/timestamp)', () {
      final mapa = TripHistory.desdePeajes(
        peajes: [_peaje('PA32', 400, cruzado: true, cruzadoA: DateTime(2026, 10, 15, 8, 5))],
        distanceKm: 3,
        duration: '5 min',
        vehicleName: 'Hyundai (JHGK50)',
        fecha: fecha,
      ).toMap();

      expect(mapa.keys.toSet(),
          {'date', 'totalCost', 'tolls', 'distanceKm', 'duration', 'vehicleName'});
      expect((mapa['tolls'] as List).single,
          {'name': 'PA32', 'cost': 400.0, 'timestamp': '2026-10-15T08:05:00.000'});
    });
  });
}
