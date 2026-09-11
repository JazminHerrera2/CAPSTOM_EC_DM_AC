import 'package:cloud_firestore/cloud_firestore.dart';
import '../mock/tolls_database.dart';
import '../models/route_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadTollsToFirebase() async {
    try {
      final tolls = TollsDatabase.santiagoTolls;
      final collection = _firestore.collection('porticos');

      // Verificamos si ya hay datos para no duplicar si el usuario re-ejecuta
      final existing = await collection.limit(1).get();
      if (existing.docs.isNotEmpty) {
        print('TAG_OK_ADMIN: La colección "porticos" ya tiene datos. Abortando para evitar duplicados.');
        return;
      }

      print('TAG_OK_ADMIN: Iniciando subida de ${tolls.length} pórticos...');
      
      int count = 0;
      for (var toll in tolls) {
        await collection.add({
          'nombre': toll.name,
          'lat': toll.location.latitude,
          'lng': toll.location.longitude,
          'costo': toll.cost,
          'costoPunta': toll.costPunta,
          'costoSaturacion': toll.costSaturacion,
          'sentido': toll.direction,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
        count++;
        print('TAG_OK_ADMIN: [$count/${tolls.length}] Subido: ${toll.name}');
      }
      print('TAG_OK_ADMIN: ¡Subida completada con éxito!');
    } catch (e) {
      print('TAG_OK_ADMIN: ERROR CRÍTICO: $e');
    }
  }
}
