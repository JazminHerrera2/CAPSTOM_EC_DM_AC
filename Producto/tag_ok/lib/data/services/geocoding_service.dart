import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import '../../entorno.dart';

class PlaceSuggestion {
  final String address;
  final LatLng location;

  PlaceSuggestion({required this.address, required this.location});

  @override
  String toString() {
    return address; // Para que el Autocomplete de Flutter muestre el nombre
  }
}

class GeocodingService {
  final String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  String get _accessToken {
    return Entorno.mapboxAccessToken;
  }

  /// Busca lugares basados en el texto ingresado.
  /// Limitamos los resultados a Chile (country=CL) para mayor precisión.
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      '$_baseUrl/${Uri.encodeComponent(query)}.json?access_token=$_accessToken&country=CL&autocomplete=true&limit=5',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List features = data['features'] ?? [];

        return features.map((feature) {
          final placeName = feature['place_name'] as String;
          // Mapbox devuelve coordenadas como [Longitud, Latitud]
          final center = feature['center'] as List;
          final lng = center[0] as double;
          final lat = center[1] as double;

          return PlaceSuggestion(
            address: placeName,
            location: LatLng(lat, lng),
          );
        }).toList();
      } else {
        debugPrint('Error Geocoding: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Excepción Geocoding: $e');
      return [];
    }
  }

  /// Obtiene una dirección completa a partir de coordenadas.
  /// Se utiliza al seleccionar un punto en el mapa o usar el GPS.
  Future<String?> obtenerDireccion({
    required double latitud,
    required double longitud,
  }) async {
    if (latitud < -90 || latitud > 90 || longitud < -180 || longitud > 180) {
      return null;
    }

    if (_accessToken.isEmpty) {
      debugPrint('Mapbox: falta configurar el token de acceso.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/$longitud,$latitud.json').replace(
      queryParameters: {
        'access_token': _accessToken,
        'language': 'es',
        'limit': '1',
      },
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List features = data['features'] ?? [];

        if (features.isEmpty) return null;

        final direccion = features.first['place_name']?.toString();

        if (direccion == null || direccion.trim().isEmpty) {
          return null;
        }

        return direccion.trim();
      }

      debugPrint('Error al obtener dirección: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error de geocodificación inversa: $e');
      return null;
    }
  }

  /// Obtiene una dirección corta para mostrar dónde está el auto.
  Future<String?> direccionDe(double latitud, double longitud) async {
    final direccion = await obtenerDireccion(
      latitud: latitud,
      longitud: longitud,
    );

    return direccion == null ? null : direccionCorta(direccion);
  }
}

/// Acorta una dirección de Mapbox para mostrar calle, número y comuna.
String? direccionCorta(String placeName) {
  final partes = placeName
      .split(',')
      .map((p) => p.trim().replaceFirst(RegExp(r'^\d{7}\s+'), ''))
      .where(
        (p) =>
            p.isNotEmpty &&
            p.toLowerCase() != 'chile' &&
            !p.toLowerCase().startsWith('región') &&
            !p.toLowerCase().startsWith('region'),
      )
      .take(2)
      .toList();

  return partes.isEmpty ? null : partes.join(', ');
}
