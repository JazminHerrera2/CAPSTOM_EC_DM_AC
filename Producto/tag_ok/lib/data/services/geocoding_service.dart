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
        '$_baseUrl/${Uri.encodeComponent(query)}.json?access_token=$_accessToken&country=CL&autocomplete=true&limit=5');

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

  /// Búsqueda inversa: la dirección escrita (calle, número y comuna) de un
  /// punto. La usa "¿Dónde está mi auto?" (HU-18) para mostrar dónde quedó el
  /// vehículo. Devuelve null si no hay conexión o Mapbox no encuentra nada:
  /// la dirección es un dato de ayuda, el mapa funciona igual sin ella.
  Future<String?> direccionDe(double latitud, double longitud) async {
    final url = Uri.parse(
        '$_baseUrl/$longitud,$latitud.json?access_token=$_accessToken'
        '&types=address,poi&language=es&limit=1');
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('Error Geocoding inverso: ${response.statusCode}');
        return null;
      }
      final features = jsonDecode(response.body)['features'];
      if (features is! List || features.isEmpty) return null;
      final nombre = features.first['place_name'];
      return nombre is String ? direccionCorta(nombre) : null;
    } catch (e) {
      debugPrint('Excepción Geocoding inverso: $e');
      return null;
    }
  }
}

/// Acorta el `place_name` de Mapbox a lo útil para encontrar el auto: calle,
/// número y comuna. Quita el país, la región y el código postal.
/// "Avenida Providencia 1234, 7500000 Providencia, Región Metropolitana,
/// Chile" → "Avenida Providencia 1234, Providencia".
String? direccionCorta(String placeName) {
  final partes = placeName
      .split(',')
      .map((p) => p.trim().replaceFirst(RegExp(r'^\d{7}\s+'), ''))
      .where((p) =>
          p.isNotEmpty &&
          p.toLowerCase() != 'chile' &&
          !p.toLowerCase().startsWith('región') &&
          !p.toLowerCase().startsWith('region'))
      .take(2)
      .toList();
  return partes.isEmpty ? null : partes.join(', ');
}
