import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tag_ok/data/mock/tolls_database.dart';
import 'package:tag_ok/data/services/simulated_toll_service.dart';

/// Protege el catálogo de pórticos de Fase 1 (`TollsDatabase.santiagoTolls`).
///
/// En el commit afae4e9 el archivo quedó reducido a 2 entradas sin sentido
/// porque `geocode_tolls_test.dart` (que lo sobrescribía) se ejecutaba con
/// `flutter test`. Estos tests fallan si el catálogo se vacía o se pisa de
/// nuevo. Son 100 % locales: no usan Mapbox ni red.
void main() {
  final catalogo = TollsDatabase.santiagoTolls;

  group('Catálogo de pórticos', () {
    test('tiene exactamente 104 pórticos (los de EXPORTACION_BASE_DE_DATOS.json)', () {
      expect(catalogo.length, 104);
    });

    test('no incluye pórticos de prueba', () {
      expect(catalogo.where((t) => t.group == 'Prueba'), isEmpty);
      expect(
        catalogo.where((t) => t.name.toLowerCase().contains('prueba')),
        isEmpty,
      );
    });

    test('todos tienen nombre, tarifa base y coordenadas válidas dentro de Chile', () {
      for (final t in catalogo) {
        expect(t.name.trim(), isNotEmpty, reason: 'pórtico sin nombre');
        expect(t.cost, greaterThan(0), reason: '${t.name}: tarifa base inválida');
        final lat = t.location.latitude;
        final lng = t.location.longitude;
        expect(lat.isFinite && lng.isFinite, isTrue, reason: '${t.name}: coordenada no numérica');
        // Chile continental: lat -56°..-17.5°, lng -76°..-66°.
        expect(lat, inInclusiveRange(-56.0, -17.5), reason: '${t.name}: latitud fuera de Chile ($lat)');
        expect(lng, inInclusiveRange(-76.0, -66.0), reason: '${t.name}: longitud fuera de Chile ($lng)');
      }
    });

    test('las tarifas de punta y saturación, cuando existen, no son menores que la base', () {
      for (final t in catalogo) {
        if (t.costPunta != null) {
          expect(t.costPunta, greaterThanOrEqualTo(t.cost), reason: t.name);
        }
        if (t.costSaturacion != null) {
          expect(t.costSaturacion, greaterThanOrEqualTo(t.cost), reason: t.name);
        }
      }
    });
  });

  group('Detección de pórticos (offline, ruta armada a mano)', () {
    final service = SimulatedTollService();

    test('una ruta N-S por PA32 detecta el pórtico', () async {
      final pa32 = catalogo.firstWhere((t) => t.name.startsWith('PA32'));
      expect(pa32.direction, 'N-S');

      final ruta = await service.calculateTolls(_rutaRecta(
        centro: pa32.location,
        haciaElNorte: false, // N → S, el sentido de PA32
      ));

      expect(ruta.tolls, isNotEmpty);
      expect(ruta.tolls.map((t) => t.name), contains(pa32.name));
    });

    test('el mismo tramo en sentido contrario (S-N) no cobra PA32', () async {
      final pa32 = catalogo.firstWhere((t) => t.name.startsWith('PA32'));
      final ruta = await service.calculateTolls(_rutaRecta(
        centro: pa32.location,
        haciaElNorte: true,
      ));
      expect(ruta.tolls.map((t) => t.name), isNot(contains(pa32.name)));
    });

    test('sin tarifa de punta/saturación se cobra siempre la tarifa base', () async {
      // Pórticos con ambas tarifas en null (hoy, 8 de Autopista Central). La
      // hora de la ruta es "ahora", así que este test no depende del horario:
      // con ambas en null, ni punta ni saturación pueden cambiar el costo.
      final sinTarifaVariable = catalogo.where((t) =>
          t.costPunta == null &&
          t.costSaturacion == null &&
          t.highway != null &&
          (t.direction == 'N-S' || t.direction == 'S-N'));
      expect(sinTarifaVariable, isNotEmpty);

      var detectados = 0;
      for (final t in sinTarifaVariable) {
        final ruta = await service.calculateTolls(_rutaRecta(
          centro: t.location,
          haciaElNorte: t.direction == 'S-N',
        ));
        for (final detectado in ruta.tolls.where((d) => d.name == t.name)) {
          detectados++;
          expect(detectado.cost, t.cost, reason: '${t.name}: no usó la tarifa base');
          expect(detectado.appliedFareMode, 'BASE', reason: t.name);
        }
      }
      expect(detectados, greaterThan(0),
          reason: 'ninguna ruta detectó un pórtico sin tarifa de punta/saturación');
    });
  });
}

/// Ruta recta de ~330 m en dirección norte-sur que pasa por [centro]
/// (misma longitud), con la forma que devuelve Mapbox (`geometry` codificada).
Map<String, dynamic> _rutaRecta({
  required LatLng centro,
  required bool haciaElNorte,
}) {
  const delta = 0.0015; // ~165 m a cada lado
  final sur = [centro.latitude - delta, centro.longitude];
  final norte = [centro.latitude + delta, centro.longitude];
  return {
    'geometry': _codificarPolyline(haciaElNorte ? [sur, norte] : [norte, sur]),
    'distance': 330.0,
    'duration': 40.0,
  };
}

/// Codifica puntos [lat, lng] con el algoritmo de Google Polyline (precisión 1e5).
String _codificarPolyline(List<List<double>> puntos) {
  final b = StringBuffer();
  var latPrev = 0, lngPrev = 0;
  void valor(int n) {
    n = n < 0 ? ~(n << 1) : n << 1;
    while (n >= 0x20) {
      b.writeCharCode((0x20 | (n & 0x1f)) + 63);
      n >>= 5;
    }
    b.writeCharCode(n + 63);
  }

  for (final p in puntos) {
    final lat = (p[0] * 1e5).round();
    final lng = (p[1] * 1e5).round();
    valor(lat - latPrev);
    valor(lng - lngPrev);
    latPrev = lat;
    lngPrev = lng;
  }
  return b.toString();
}
