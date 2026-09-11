import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class PolylineDecoder {
  /// Decodifica un string codificado usando el algoritmo de Google Polyline
  /// en una lista de coordenadas LatLng. (Versión 100% segura para Web)
  static List<LatLng> decode(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          if (index >= len) break;
          b = encoded.codeUnitAt(index++) - 63;
          result += (b & 0x1f) * math.pow(2, shift).toInt();
          shift += 5;
        } while (b >= 0x20);
        
        int dlat = (result % 2 != 0) ? -(result ~/ 2) - 1 : (result ~/ 2);
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          if (index >= len) break;
          b = encoded.codeUnitAt(index++) - 63;
          result += (b & 0x1f) * math.pow(2, shift).toInt();
          shift += 5;
        } while (b >= 0x20);
        
        int dlng = (result % 2 != 0) ? -(result ~/ 2) - 1 : (result ~/ 2);
        lng += dlng;

        final p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
        // Filtrar puntos duplicados que pueden romper el renderizado en Web
        if (poly.isEmpty || poly.last.latitude != p.latitude || poly.last.longitude != p.longitude) {
          poly.add(p);
        }
      }
    } catch (e) {
      // Si el string polilyne está mal formado, retornamos lo que se haya decodificado con éxito
      return poly;
    }

    return poly;
  }
}
