import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/geocoding_service.dart';

/// "¿Dónde está mi auto?" (HU-18): dirección escrita del lugar donde quedó el
/// vehículo, a partir del `place_name` de la búsqueda inversa de Mapbox.
void main() {
  test('deja calle, número y comuna; quita código postal, región y país', () {
    expect(
      direccionCorta(
          'Avenida Providencia 1234, 7500000 Providencia, Región Metropolitana, Chile'),
      'Avenida Providencia 1234, Providencia',
    );
  });

  test('formato real de Mapbox (código postal al final de la región)', () {
    // Respuesta real del 12-nov para la Plaza de Armas de Santiago.
    expect(
      direccionCorta(
          'Plaza de Armas 442, Santiago, Región Metropolitana de Santiago 8320000, Chile'),
      'Plaza de Armas 442, Santiago',
    );
  });

  test('un lugar (POI) conserva su nombre y la calle', () {
    expect(
      direccionCorta('Costanera Center, Avenida Andrés Bello 2425, 7510689 Providencia, '
          'Región Metropolitana de Santiago, Chile'),
      'Costanera Center, Avenida Andrés Bello 2425',
    );
  });

  test('sin datos útiles devuelve null', () {
    expect(direccionCorta('Chile'), isNull);
    expect(direccionCorta(''), isNull);
  });
}
