import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../mock/tolls_database.dart';
import '../../utils/polyline_decoder.dart';

class SimulatedTollService {
  final String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox/driving';

  Future<RouteData> calculateRouteAndTolls({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final String mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    
    if (mapboxToken.isEmpty) {
      throw Exception('Mapbox token no configurado en .env');
    }

    final String coordinates = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final url = Uri.parse('$_baseUrl/$coordinates?overview=full&geometries=polyline&access_token=$mapboxToken');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        return calculateTolls(data['routes'][0]);
      } else {
        throw Exception('No se encontró una ruta válida');
      }
    } else {
      throw Exception('Error al conectar con Mapbox: ${response.statusCode}');
    }
  }

  Future<RouteData> calculateTolls(Map<String, dynamic> routeGeometry) async {
    // 1. Decodificar polilínea (lista de puntos)
    final polylineStr = routeGeometry['geometry'] as String;
    final polylinePoints = PolylineDecoder.decode(polylineStr);

    // 2. Extraer distancia y duración (desde Mapbox API)
    final distanceMeters = routeGeometry['distance'] as num;
    final durationSeconds = routeGeometry['duration'] as num;

    final distanceKm = distanceMeters / 1000.0;

    // 3. Simular pórticos interceptados con Paso A, B y C
    final tolls = _calculateTollsForRoute(polylinePoints, distanceMeters, durationSeconds);

    // 4. Sentido genérico aproximado
    String direction = "Desconocido";
    if (polylinePoints.isNotEmpty) {
      final origin = polylinePoints.first;
      final destination = polylinePoints.last;
      
      if (origin.longitude < destination.longitude) {
        direction = "Sentido Santiago (Oriente)";
      } else if (origin.longitude > destination.longitude) {
        direction = "Sentido San Antonio (Poniente)";
      }
    }

    // Calcular costo total
    double totalCost = 0;
    for (var toll in tolls) {
      totalCost += toll.cost;
    }

    // Formatear tiempo
    final durationText = _formatDuration(durationSeconds);

    return RouteData(
      polyline: polylinePoints,
      tolls: tolls,
      totalCost: totalCost, 
      distanceKm: distanceKm,
      durationText: durationText,
      direction: direction,
    );
  }

  List<TollData> _calculateTollsForRoute(List<LatLng> routePoints, num totalDistanceMeters, num durationSeconds) {
    if (routePoints.isEmpty) return [];

    // Precalcular distancias acumuladas de la polilínea
    List<double> cumulativeDistances = [0.0];
    for (int i = 0; i < routePoints.length - 1; i++) {
      double dist = _calculateDistance(routePoints[i], routePoints[i+1]);
      cumulativeDistances.add(cumulativeDistances.last + dist);
    }

    final List<_CandidateToll> candidateTolls = [];
    final double thresholdMeters = 150.0;
    final knownTolls = TollsDatabase.santiagoTolls;

    for (var knownToll in knownTolls) {
      LatLng? bestSnappedPoint;
      double minDistance = double.infinity;
      double? segmentBearing;
      double? bestRouteDistance;

      for (int i = 0; i < routePoints.length - 1; i++) {
        final snapResult = _snapToSegment(
          knownToll.location, 
          routePoints[i], 
          routePoints[i+1]
        );
        
        if (snapResult.distance <= thresholdMeters) {
          if (snapResult.distance < minDistance) {
            minDistance = snapResult.distance;
            bestSnappedPoint = snapResult.point;
            segmentBearing = _calculateBearing(routePoints[i], routePoints[i+1]);
            double distToSnap = _calculateDistance(routePoints[i], snapResult.point);
            bestRouteDistance = cumulativeDistances[i] + distToSnap;
          }
        }
      }
      
      if (bestSnappedPoint != null && bestRouteDistance != null) {
        candidateTolls.add(_CandidateToll(
          toll: knownToll,
          snappedLocation: bestSnappedPoint,
          routeDistance: bestRouteDistance,
          segmentBearing: segmentBearing ?? 0.0,
        ));
      }
    }

    // Paso A: Ordenamiento Cronológico
    candidateTolls.sort((a, b) => a.routeDistance.compareTo(b.routeDistance));

    // Paso B: Lógica de Secuencias y Filtrado de Sentido (Topológica)
    Map<String, List<_CandidateToll>> tollsByHighway = {};
    for (var ct in candidateTolls) {
      if (ct.toll.highway != null) {
        tollsByHighway.putIfAbsent(ct.toll.highway!, () => []).add(ct);
      } else {
        tollsByHighway.putIfAbsent('Unknown', () => []).add(ct);
      }
    }

    List<_CandidateToll> filteredCandidates = [];

    for (var entry in tollsByHighway.entries) {
      final highwayCandidates = entry.value;

      if (highwayCandidates.length < 2 || entry.key == 'Unknown') {
        for (var ct in highwayCandidates) {
          if (ct.toll.direction != null) {
            bool isMatch = _checkDirectionMatch(
              ct.segmentBearing,
              ct.toll.direction!,
              highway: ct.toll.highway,
              location: ct.toll.location,
            );
            if (isMatch) filteredCandidates.add(ct);
          } else {
            filteredCandidates.add(ct);
          }
        }
      } else {
        Map<String, int> directionCounts = {};
        for (var ct in highwayCandidates) {
          if (ct.toll.direction != null) {
            directionCounts[ct.toll.direction!] = (directionCounts[ct.toll.direction!] ?? 0) + 1;
          }
        }
        
        String? dominantDirection;
        int maxCount = 0;
        directionCounts.forEach((dir, count) {
          if (count > maxCount) {
            maxCount = count;
            dominantDirection = dir;
          }
        });

        for (var ct in highwayCandidates) {
          if (ct.toll.direction == dominantDirection || ct.toll.direction == null) {
            filteredCandidates.add(ct);
          }
        }
      }
    }

    filteredCandidates.sort((a, b) => a.routeDistance.compareTo(b.routeDistance));

    final List<TollData> finalTolls = [];
    final Set<String> seenNames = {};
    final startTime = DateTime.now();

    for (var ct in filteredCandidates) {
      if (!seenNames.contains(ct.toll.name)) {
        bool tooClose = finalTolls.any((t) => 
          _calculateDistance(t.location, ct.snappedLocation) < 100);
        
        if (!tooClose) {
          // Paso C: Tarifas Dinámicas
          double proportion = ct.routeDistance / (totalDistanceMeters > 0 ? totalDistanceMeters : 1);
          if (proportion > 1.0) proportion = 1.0;
          
          DateTime eta = startTime.add(Duration(seconds: (durationSeconds * proportion).round()));
          
          double finalCost = ct.toll.cost;
          String mode = "BASE";

          if (_isHorarioSaturacion(eta)) {
            if (ct.toll.costSaturacion != null) {
              finalCost = ct.toll.costSaturacion!;
              mode = "SATURACION";
            } else if (ct.toll.costPunta != null) {
              finalCost = ct.toll.costPunta!;
              mode = "PUNTA";
            }
          } else if (_isHorarioPunta(eta)) {
            if (ct.toll.costPunta != null) {
              finalCost = ct.toll.costPunta!;
              mode = "PUNTA";
            }
          }

          final detectedToll = TollData(
            name: ct.toll.name,
            cost: finalCost,
            costPunta: ct.toll.costPunta,
            costSaturacion: ct.toll.costSaturacion,
            direction: ct.toll.direction,
            location: ct.snappedLocation,
            highway: ct.toll.highway,
            group: ct.toll.group,
            sequence: ct.toll.sequence,
            isCrossed: false,
            crossedAt: eta,
            appliedFareMode: mode,
          );
          
          finalTolls.add(detectedToll);
          seenNames.add(ct.toll.name);
          print("TAG_OK_DEBUG: Peaje ${ct.toll.name} ETA: \${eta.hour}:\${eta.minute.toString().padLeft(2,'0')} - Costo: \$$finalCost ($mode)");
        }
      }
    }

    return finalTolls;
  }

  /// Calcula el punto más cercano de la ruta a la ubicación aproximada del pórtico
  /// y devuelve la distancia y la coordenada matemática exacta sobre la ruta.
  _SnapResult _snapToSegment(LatLng p, LatLng a, LatLng b) {
    // Convertir grados a metros aproximadamente (válido para la latitud de Santiago)
    const double kLat = 111320.0;
    final double kLon = 111320.0 * math.cos(p.latitude * math.pi / 180.0);
    
    final double px = p.longitude * kLon;
    final double py = p.latitude * kLat;
    final double ax = a.longitude * kLon;
    final double ay = a.latitude * kLat;
    final double bx = b.longitude * kLon;
    final double by = b.latitude * kLat;
    
    final double dx = bx - ax;
    final double dy = by - ay;
    
    if (dx == 0 && dy == 0) {
      final dist = math.sqrt(math.pow(px - ax, 2) + math.pow(py - ay, 2));
      return _SnapResult(dist, a);
    }
    
    double t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    t = math.max(0.0, math.min(1.0, t));
    
    final double closestX = ax + t * dx;
    final double closestY = ay + t * dy;
    
    final dist = math.sqrt(math.pow(px - closestX, 2) + math.pow(py - closestY, 2));
    final snappedLatLng = LatLng(closestY / kLat, closestX / kLon);
    
    return _SnapResult(dist, snappedLatLng);
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180.0;
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = _toRadians(start.latitude);
    final lon1 = _toRadians(start.longitude);
    final lat2 = _toRadians(end.latitude);
    final lon2 = _toRadians(end.longitude);

    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
            math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x);
    bearing = (bearing * 180.0 / math.pi + 360.0) % 360.0;
    return bearing;
  }

  bool _checkDirectionMatch(double bearing, String tollDir, {String? highway, LatLng? location}) {
    // Para autopistas tipo anillo (como Vespucio Norte), la dirección física
    // cambia de Este-Oeste a Norte-Sur en la zona Poniente (longitud < -70.73).
    if (highway == "Vespucio Norte" && location != null && location.longitude < -70.73) {
      if (tollDir == "P-O") return bearing >= 315 || bearing < 45; // Sentido Norte
      if (tollDir == "O-P") return bearing >= 135 && bearing < 225; // Sentido Sur
    }

    // Cuadrantes estrictos de 90 grados (+/- 45 del eje)
    if (tollDir == "S-N") return bearing >= 315 || bearing < 45; // Norte
    if (tollDir == "P-O") return bearing >= 45 && bearing < 135; // Oriente
    if (tollDir == "N-S") return bearing >= 135 && bearing < 225; // Sur
    if (tollDir == "O-P") return bearing >= 225 && bearing < 315; // Poniente
    return true;
  }

  String _formatDuration(dynamic secondsRaw) {
    final int seconds = (secondsRaw as num).toInt();
    final int minutes = (seconds / 60).round();
    if (minutes > 60) {
      final int hours = minutes ~/ 60;
      final int mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes} min';
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double kLat = 111320.0;
    final double kLon = 111320.0 * math.cos(p1.latitude * math.pi / 180.0);
    final double dx = (p1.longitude - p2.longitude) * kLon;
    final double dy = (p1.latitude - p2.latitude) * kLat;
    return math.sqrt(dx * dx + dy * dy);
  }

  bool _isHorarioPunta(DateTime now) {
    if (now.weekday >= 1 && now.weekday <= 5) {
      if (now.hour >= 7 && now.hour < 9) return true;
      if ((now.hour == 17 && now.minute >= 30) || (now.hour >= 18 && now.hour < 20)) return true;
    }
    return false;
  }

  bool _isHorarioSaturacion(DateTime now) {
    if (now.weekday >= 1 && now.weekday <= 5) {
      // Definimos unas ventanas de saturación más críticas (ejemplo simulado)
      if (now.hour == 8) return true;
      if (now.hour == 18) return true;
    }
    return false;
  }
}

class _SnapResult {
  final double distance;
  final LatLng point;

  _SnapResult(this.distance, this.point);
}

class _CandidateToll {
  final TollData toll;
  final LatLng snappedLocation;
  final double routeDistance;
  final double segmentBearing;

  _CandidateToll({
    required this.toll,
    required this.snappedLocation,
    required this.routeDistance,
    required this.segmentBearing,
  });
}
