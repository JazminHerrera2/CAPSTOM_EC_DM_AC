import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminOverview {
  const AdminOverview({
    required this.users,
    required this.vehicles,
    required this.porticos,
    required this.tariffs,
    required this.alerts,
  });

  final int users;
  final int vehicles;
  final int porticos;
  final int tariffs;
  final int alerts;
}

class ReportMetrics {
  const ReportMetrics({
    required this.totalUsers,
    required this.totalVehicles,
    required this.totalTrips,
    required this.totalTollCost,
    required this.averageCostPerTrip,
    required this.costByHighway,
  });

  final int totalUsers;
  final int totalVehicles;
  final int totalTrips;
  final double totalTollCost;
  final double averageCostPerTrip;
  final Map<String, double> costByHighway;
}

class AdminFirestoreService {
  AdminFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String _classifyHighway(String tollName) {
    final name = tollName.toLowerCase();
    if (name.contains('autopista de conexión') || name.contains('conexión')) {
      return 'Conexión / Otras';
    }
    if (name.startsWith('pa') ||
        name.contains('autopista central') ||
        name.contains('ruta 5')) {
      return 'Autopista Central';
    }
    if (name.contains('costanera') ||
        name.contains('vivaceta') ||
        name.contains('lo saldes') ||
        name.contains('la dehesa') ||
        name.contains('estoril') ||
        name.contains('padre arteaga') ||
        name.contains('tranqueras') ||
        name.contains('carrascal') ||
        name.contains('padre hurtado') ||
        name.startsWith('ev ') ||
        name.startsWith('sv ')) {
      return 'Costanera Norte';
    }
    if (name.contains('avo') ||
        name.contains('kennedy') ||
        name.contains('p101') ||
        name.contains('p102') ||
        name.contains('vespucio oriente')) {
      return 'Vespucio Oriente (AVO)';
    }
    if (name.contains('vespucio norte') ||
        name.contains('guanaco') ||
        name.contains('el salto') ||
        name.contains('lo boza') ||
        name.contains('recabal') ||
        name.contains('enea') ||
        name.contains('p14') ||
        name.contains('p13') ||
        name.contains('p12') ||
        name.contains('p15')) {
      return 'Vespucio Norte';
    }
    if (name.contains('vespucio sur') ||
        name.contains('pvs') ||
        name.contains('velásquez') ||
        name.contains('velasquez') ||
        name.contains('gran avenida') ||
        name.contains('santa rosa') ||
        name.contains('vicuña mackenna') ||
        name.contains('alderete') ||
        name.contains('2a transversal') ||
        name.contains('los mares') ||
        name.contains('coronel') ||
        name.contains('camino a melipilla')) {
      return 'Vespucio Sur';
    }
    if (name.contains('ruta 68')) {
      return 'Conexión / Otras';
    }
    if (name.contains('ruta 78') || name.contains('autopista del sol')) {
      return 'Conexión / Otras';
    }
    return 'Conexión / Otras';
  }

  Future<ReportMetrics> fetchReportMetrics() async {
    final usersSnapshot = await _firestore.collection('usuarios').get();
    final vehiclesSnapshot = await _firestore.collection('vehiculos').get();
    final tripsSnapshot = await _firestore.collectionGroup('trips').get();

    final int totalUsers = usersSnapshot.size;
    final int totalVehicles = vehiclesSnapshot.size;
    final int totalTrips = tripsSnapshot.size;

    double totalTollCost = 0.0;
    final Map<String, double> costByHighway = {
      'Autopista Central': 0.0,
      'Costanera Norte': 0.0,
      'Vespucio Norte': 0.0,
      'Vespucio Sur': 0.0,
      'Vespucio Oriente (AVO)': 0.0,
      'Conexión / Otras': 0.0,
    };

    for (var doc in tripsSnapshot.docs) {
      final data = doc.data();
      final double tripCost =
          double.tryParse(data['totalCost']?.toString() ?? '0') ?? 0.0;
      totalTollCost += tripCost;

      final List<dynamic> tollsList = data['tolls'] as List<dynamic>? ?? [];
      for (var tollRaw in tollsList) {
        if (tollRaw is Map) {
          final String tollName = (tollRaw['name'] ?? '').toString();
          final double tollCost =
              double.tryParse(tollRaw['cost']?.toString() ?? '0') ?? 0.0;
          final String highway = _classifyHighway(tollName);

          if (costByHighway.containsKey(highway)) {
            costByHighway[highway] = costByHighway[highway]! + tollCost;
          } else {
            costByHighway['Conexión / Otras'] =
                costByHighway['Conexión / Otras']! + tollCost;
          }
        }
      }
    }

    final double averageCostPerTrip = totalTrips > 0
        ? (totalTollCost / totalTrips)
        : 0.0;

    return ReportMetrics(
      totalUsers: totalUsers,
      totalVehicles: totalVehicles,
      totalTrips: totalTrips,
      totalTollCost: totalTollCost,
      averageCostPerTrip: averageCostPerTrip,
      costByHighway: costByHighway,
    );
  }

  Future<AdminOverview> fetchOverview() async {
    final results = await Future.wait([
      _count('usuarios'),
      _count('vehiculos'),
      _count('porticos'),
      _count('tarifas'),
      _count('alertas'),
    ]);

    return AdminOverview(
      users: results[0],
      vehicles: results[1],
      porticos: results[2],
      tariffs: results[3],
      alerts: results[4],
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUsers() {
    return _firestore.collection('usuarios').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPorticos() {
    return _firestore.collection('porticos').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamTariffs() {
    return _firestore
        .collection('tarifas')
        .orderBy('fecha_actualizacion', descending: true)
        .snapshots();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamUserTrips() {
    return _firestore.collectionGroup('trips').snapshots().map((snapshot) {
      final list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
        snapshot.docs,
      );
      list.sort((a, b) {
        final aDate = a.data()['date']?.toString() ?? '';
        final bDate = b.data()['date']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });
      return list;
    });
  }

  Future<void> logAction({
    required String action,
    required String target,
    required String details,
  }) async {
    final String adminEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'admin_desconocido';
    await _firestore.collection('auditoria').add({
      'fecha': FieldValue.serverTimestamp(),
      'adminEmail': adminEmail,
      'action': action,
      'target': target,
      'details': details,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAuditLogs() {
    return _firestore
        .collection('auditoria')
        .orderBy('fecha', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAdministradores() {
    return _firestore.collection('administradores').snapshots();
  }

  Future<void> updateAdminRole(String docId, String role) async {
    await _firestore.collection('administradores').doc(docId).update({
      'rol': role,
    });
  }

  Future<void> deleteAdmin(String docId) async {
    await _firestore.collection('administradores').doc(docId).delete();
  }

  Future<int> _count(String collection) async {
    final snapshot = await _firestore.collection(collection).get();
    return snapshot.size;
  }
}
