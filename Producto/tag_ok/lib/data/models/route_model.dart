import 'package:latlong2/latlong.dart';

class RouteData {
  final List<LatLng> polyline;
  final List<TollData> tolls;
  final double totalCost;
  final double distanceKm;
  final String durationText;
  final String direction; // ej: "Sentido Santiago" o "Sentido San Antonio"

  RouteData({
    required this.polyline,
    required this.tolls,
    required this.totalCost,
    required this.distanceKm,
    required this.durationText,
    required this.direction,
  });

  Map<String, dynamic> toJson() {
    return {
      'polyline': polyline.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'tolls': tolls.map((t) => t.toJson()).toList(),
      'totalCost': totalCost,
      'distanceKm': distanceKm,
      'durationText': durationText,
      'direction': direction,
    };
  }

  factory RouteData.fromJson(Map<String, dynamic> json) {
    return RouteData(
      polyline: (json['polyline'] as List).map((p) => LatLng(p['lat'] as double, p['lng'] as double)).toList(),
      tolls: (json['tolls'] as List).map((t) => TollData.fromJson(t as Map<String, dynamic>)).toList(),
      totalCost: json['totalCost'] as double,
      distanceKm: json['distanceKm'] as double,
      durationText: json['durationText'] as String,
      direction: json['direction'] as String,
    );
  }
}

class TollData {
  final LatLng location;
  final String name;
  final double cost; // TBFP
  final double? costPunta; // TBP
  final double? costSaturacion; // TS
  final String? direction; // "N-S", "S-N", "P-O", "O-P"
  final String? highway;
  final String? group;
  final int? sequence;
  
  // Active Navigation Fields
  bool isCrossed;
  DateTime? crossedAt;
  String? appliedFareMode;

  TollData({
    required this.location,
    required this.name,
    required this.cost,
    this.costPunta,
    this.costSaturacion,
    this.direction,
    this.highway,
    this.group,
    this.sequence,
    this.isCrossed = false,
    this.crossedAt,
    this.appliedFareMode,
  });

  Map<String, dynamic> toJson() {
    return {
      'location': {'lat': location.latitude, 'lng': location.longitude},
      'name': name,
      'cost': cost,
      'costPunta': costPunta,
      'costSaturacion': costSaturacion,
      'direction': direction,
      'highway': highway,
      'group': group,
      'sequence': sequence,
      'isCrossed': isCrossed,
      'crossedAt': crossedAt?.toIso8601String(),
      'appliedFareMode': appliedFareMode,
    };
  }

  factory TollData.fromJson(Map<String, dynamic> json) {
    return TollData(
      location: LatLng(json['location']['lat'] as double, json['location']['lng'] as double),
      name: json['name'] as String,
      cost: json['cost'] as double,
      costPunta: json['costPunta'] as double?,
      costSaturacion: json['costSaturacion'] as double?,
      direction: json['direction'] as String?,
      highway: json['highway'] as String?,
      group: json['group'] as String?,
      sequence: json['sequence'] as int?,
      isCrossed: json['isCrossed'] as bool? ?? false,
      crossedAt: json['crossedAt'] != null ? DateTime.parse(json['crossedAt'] as String) : null,
      appliedFareMode: json['appliedFareMode'] as String?,
    );
  }
}
