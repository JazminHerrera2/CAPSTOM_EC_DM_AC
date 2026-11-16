import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tag_ok/data/services/posicion_compartida.dart';

void main() {
  setUp(PosicionCompartida.olvidar);

  test('sin posición del mapa de rutas no hay nada que usar', () {
    expect(PosicionCompartida.reciente(), isNull);
  });

  test('una posición reciente se entrega tal cual', () {
    final ahora = DateTime(2026, 11, 15, 12);
    PosicionCompartida.actualizar(const LatLng(-33.45, -70.66), ahora: ahora);
    final p = PosicionCompartida.reciente(
      ahora: ahora.add(const Duration(seconds: 30)),
    );
    expect(p?.latitude, -33.45);
    expect(p?.longitude, -70.66);
  });

  test('una posición muy antigua se descarta', () {
    final ahora = DateTime(2026, 11, 15, 12);
    PosicionCompartida.actualizar(const LatLng(-33.45, -70.66), ahora: ahora);
    expect(
      PosicionCompartida.reciente(ahora: ahora.add(const Duration(minutes: 10))),
      isNull,
    );
  });
}
