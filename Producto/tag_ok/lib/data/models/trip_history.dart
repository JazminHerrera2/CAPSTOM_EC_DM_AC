import 'package:cloud_firestore/cloud_firestore.dart';
import 'route_model.dart';

class TollRecord {
  final String name;
  final double cost;
  final DateTime timestamp;

  TollRecord({
    required this.name,
    required this.cost,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cost': cost,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TollRecord.fromMap(Map<String, dynamic> map) {
    return TollRecord(
      name: map['name'] ?? '',
      cost: (map['cost'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class TripHistory {
  final String id;
  final DateTime date;
  final double totalCost;
  final List<TollRecord> tolls;
  final double distanceKm;
  final String duration;
  final String vehicleName;

  TripHistory({
    required this.id,
    required this.date,
    required this.totalCost,
    required this.tolls,
    required this.distanceKm,
    required this.duration,
    required this.vehicleName,
  });

  /// Arma el viaje que se guarda al finalizar: solo cuenta los pórticos
  /// efectivamente cruzados ([TollData.isCrossed]); `totalCost` es la suma de
  /// sus costos y cada pórtico lleva su hora de cruce (o [fecha] si no hay).
  /// Los no cruzados no entran ni a `tolls` ni a `totalCost`.
  ///
  /// [fecha] es la fecha del viaje (por defecto, ahora). El `id` queda vacío:
  /// lo genera Firestore.
  factory TripHistory.desdePeajes({
    required List<TollData> peajes,
    required double distanceKm,
    required String duration,
    required String vehicleName,
    DateTime? fecha,
  }) {
    final ahora = fecha ?? DateTime.now();
    final cruzados = peajes.where((t) => t.isCrossed).toList();
    return TripHistory(
      id: '',
      date: ahora,
      totalCost: cruzados.fold(0.0, (suma, t) => suma + t.cost),
      distanceKm: distanceKm,
      duration: duration,
      vehicleName: vehicleName,
      tolls: cruzados
          .map((t) => TollRecord(
                name: t.name,
                cost: t.cost, // el costo base o el que se haya aplicado
                timestamp: t.crossedAt ?? ahora,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'totalCost': totalCost,
      'tolls': tolls.map((t) => t.toMap()).toList(),
      'distanceKm': distanceKm,
      'duration': duration,
      'vehicleName': vehicleName,
    };
  }

  factory TripHistory.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return TripHistory(
      id: doc.id,
      date: DateTime.parse(map['date']),
      totalCost: (map['totalCost'] as num).toDouble(),
      tolls: (map['tolls'] as List).map((t) => TollRecord.fromMap(t)).toList(),
      distanceKm: (map['distanceKm'] as num).toDouble(),
      duration: map['duration'] ?? '',
      vehicleName: map['vehicleName'] ?? 'Desconocido',
    );
  }
}
