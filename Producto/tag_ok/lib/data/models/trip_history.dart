import 'package:cloud_firestore/cloud_firestore.dart';

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
