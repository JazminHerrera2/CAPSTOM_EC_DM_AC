import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tag_ok/data/mock/tolls_database.dart';
import 'package:tag_ok/data/models/route_model.dart';
import 'package:tag_ok/data/services/simulated_toll_service.dart';

/// Un pórtico se cobra solo si la ruta va EN SU SENTIDO. En el catálogo hay
/// muchos pórticos "de ida" y "de vuelta" casi en el mismo punto (uno por
/// calzada); una ruta que va hacia el norte no debe cobrar el de la calzada
/// que va hacia el sur, y al revés. Son tests locales: la ruta se arma a mano,
/// sin Mapbox ni red.
void main() {
  final service = SimulatedTollService();
  final catalogo = TollsDatabase.santiagoTolls;
  const distancia = Distance();

  const opuesto = {'N-S': 'S-N', 'S-N': 'N-S', 'O-P': 'P-O', 'P-O': 'O-P'};

  /// Hacia dónde se mueve alguien que circula en el sentido [t.direction].
  /// (En el tramo poniente de Vespucio Norte, que es un anillo, la etiqueta
  /// "P-O" significa ir hacia el norte y "O-P" hacia el sur: misma excepción
  /// que usa el servicio.)
  String rumbo(TollData t) {
    final anilloPoniente =
        t.highway == 'Vespucio Norte' && t.location.longitude < -70.73;
    switch (t.direction) {
      case 'S-N':
        return 'norte';
      case 'N-S':
        return 'sur';
      case 'P-O':
        return anilloPoniente ? 'norte' : 'este';
      case 'O-P':
        return anilloPoniente ? 'sur' : 'oeste';
    }
    throw StateError('${t.name}: sin sentido');
  }

  /// Ruta recta de ~280 m que pasa por [t] yendo hacia [rumbo].
  Map<String, dynamic> rutaPor(TollData t, String rumbo) {
    const d = 0.0013; // ~145 m a cada lado
    final la = t.location.latitude, lo = t.location.longitude;
    final puntos = switch (rumbo) {
      'norte' => [[la - d, lo], [la + d, lo]],
      'sur' => [[la + d, lo], [la - d, lo]],
      'este' => [[la, lo - d], [la, lo + d]],
      'oeste' => [[la, lo + d], [la, lo - d]],
      _ => throw ArgumentError(rumbo),
    };
    return {
      'geometry': _codificar(puntos),
      'distance': 290.0,
      'duration': 35.0,
    };
  }

  // Pares de pórticos de sentido contrario a menos de 150 m (misma autopista).
  final pares = <(TollData, TollData)>[];
  for (var i = 0; i < catalogo.length; i++) {
    for (var j = i + 1; j < catalogo.length; j++) {
      final a = catalogo[i], b = catalogo[j];
      if (a.direction != null &&
          opuesto[a.direction] == b.direction &&
          a.highway == b.highway &&
          distancia(a.location, b.location) <= 150) {
        pares.add((a, b));
      }
    }
  }

  test('el catálogo tiene pares de pórticos ida/vuelta casi en el mismo punto', () {
    expect(pares.length, greaterThanOrEqualTo(30));
  });

  group('una ruta cobra solo los pórticos de su sentido', () {
    for (final (a, b) in pares) {
      for (final (propio, ajeno) in [(a, b), (b, a)]) {
        test('${rumbo(propio)}: cobra "${propio.name}" [${propio.direction}] '
            'y no "${ajeno.name}" [${ajeno.direction}]', () async {
          final ruta = await service.calculateTolls(rutaPor(propio, rumbo(propio)));
          final cobrados = ruta.tolls;

          expect(
            cobrados.any((c) =>
                c.name == propio.name && c.direction == propio.direction),
            isTrue,
            reason: 'no cobró el pórtico de su propio sentido',
          );
          expect(
            cobrados.where((c) =>
                c.direction == ajeno.direction &&
                distancia(c.location, propio.location) <= 200),
            isEmpty,
            reason: 'cobró un pórtico de la calzada contraria',
          );
        });
      }
    }
  });

  group('caso puntual: PA21 (S-N) y PA22 (N-S), mismo punto de Autopista Central', () {
    final pa21 = catalogo.firstWhere((t) => t.name.startsWith('PA21 '));
    final pa22 = catalogo.firstWhere((t) => t.name.startsWith('PA22 '));

    test('yendo hacia el norte solo cobra PA21', () async {
      final ruta = await service.calculateTolls(rutaPor(pa21, 'norte'));
      final nombres = ruta.tolls.map((t) => t.name.split(' ').first).toList();
      expect(nombres, contains('PA21'));
      expect(nombres, isNot(contains('PA22')));
    });

    test('yendo hacia el sur solo cobra PA22', () async {
      final ruta = await service.calculateTolls(rutaPor(pa22, 'sur'));
      final nombres = ruta.tolls.map((t) => t.name.split(' ').first).toList();
      expect(nombres, contains('PA22'));
      expect(nombres, isNot(contains('PA21')));
    });
  });
}

/// Codifica puntos [lat, lng] como polyline de Google (precisión 1e5), como
/// la que devuelve Mapbox.
String _codificar(List<List<double>> puntos) {
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
