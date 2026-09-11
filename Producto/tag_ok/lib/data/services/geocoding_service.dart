import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

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
    return dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
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
}
