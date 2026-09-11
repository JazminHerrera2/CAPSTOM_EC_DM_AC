import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_history.dart';

class HistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? 'anonymous';

  Future<void> saveTrip(TripHistory trip) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(_userId)
          .collection('trips')
          .add(trip.toMap());
    } catch (e) {
      print('Error saving trip: $e');
      rethrow;
    }
  }

  Future<void> updateMonthlyLimit(double limit) async {
    await _firestore.collection('usuarios').doc(_userId).set({
      'limite_presupuesto_mensual': limit.toInt(),
    }, SetOptions(merge: true));
  }

  Stream<double> getMonthlyLimit() {
    return _firestore.collection('usuarios').doc(_userId).snapshots().map((doc) {
      if (doc.exists && doc.data()!.containsKey('limite_presupuesto_mensual')) {
        final val = doc.data()!['limite_presupuesto_mensual'];
        if (val is num) return val.toDouble();
      }
      return 50000.0; // Valor por defecto
    });
  }

  Stream<List<TripHistory>> getTripHistory() {
    return _firestore
        .collection('usuarios')
        .doc(_userId)
        .collection('trips')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TripHistory.fromFirestore(doc)).toList();
    });
  }

  Future<Map<String, dynamic>?> getPrincipalVehicleInfo() async {
    final userDoc = await _firestore.collection('usuarios').doc(_userId).get();
    if (!userDoc.exists) return null;
    
    final patente = userDoc.data()?['vehiculo_principal_id'];
    if (patente == null) return null;

    final query = await _firestore
        .collection('vehiculos')
        .where('id_usuario', isEqualTo: _firestore.collection('usuarios').doc(_userId))
        .where('patente', isEqualTo: patente)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return {'patente': patente, 'marca': 'Vehículo Principal'};
  }

  Future<List<Map<String, dynamic>>> getUserVehicles() async {
    final query = await _firestore
        .collection('vehiculos')
        .where('id_usuario', isEqualTo: _firestore.collection('usuarios').doc(_userId))
        .get();
    
    return query.docs.map((doc) => doc.data()).toList();
  }

  // --- GESTIÓN DE ALERTAS (Para evitar spam) ---
  
  Future<bool> hasAlertBeenNotified(int threshold) async {
    final now = DateTime.now();
    final monthKey = "${now.year}-${now.month}_$threshold";
    
    final doc = await _firestore.collection('usuarios').doc(_userId).get();
    if (!doc.exists) return false;
    
    final alertas = doc.data()?['alertas_vistas'] as Map<String, dynamic>? ?? {};
    return alertas.containsKey(monthKey);
  }

  Future<void> markAlertAsNotified(int threshold) async {
    final now = DateTime.now();
    final monthKey = "${now.year}-${now.month}_$threshold";
    
    await _firestore.collection('usuarios').doc(_userId).set({
      'alertas_vistas': {
        monthKey: true,
      }
    }, SetOptions(merge: true));
  }
}
