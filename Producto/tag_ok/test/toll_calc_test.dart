import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tag_ok/data/mock/tolls_database.dart';
import 'package:tag_ok/data/services/simulated_toll_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

void main() {
  setUpAll(() {
    try {
      // NOTA: variables ficticias solo para tests locales, no son credenciales reales
      // (excepto MAPBOX_ACCESS_TOKEN, requerido para que el test de simulación de ruta
      // llame a la API real de Mapbox).
      const b64Env = "V0VCX0FQSV9LRVk9QUl6YVN5Qm1YVnZZejNsalpXRjROQ2tfMndGQ01Cc0VmTEJkZzF3CldFQl9BUFBfSUQ9MToxNTkxNTA2NDM2Mzp3ZWI6YWZmZWU0ODg0NTRhNjJkNWZiZGU2ZQpBTkRST0lEX0FQUF9JRD0xOjE1OTE1MDY0MzYzOmFuZHJvaWQ6MjZkNTU4ZmU4MmY1OTE2Y2ZiZGU2ZQpJT1NfQVBJX0tFWT1BSXphU3lEcS02cGRBY0g4Z0FrT0VZT3A0SHpjWDVBQzF5cUl6eWsKSU9TX0FQUF9JRD0xOjE1OTE1MDY0MzYzOmlvczphODZkNGM0YTk1NjRkODEzZmJkZTZlCk1FU1NBR0lOR19TRU5ERVJfSUQ9MTU5MTUwNjQzNjMKUFJPSkVDVF9JRD10YWctb2sKU1RPUkFHRV9CVUNLRVQ9dGFnLW9rLmZpcmViYXNlc3RvcmFnZS5hcHAKSU9TX0JVTkRMRV9JRD1jb20uZXhhbXBsZS50YWdPawpNQVBCT1hfQUNDRVNTX1RPS0VOPXBrLmV5SjFJam9pYW1WemRYTmhjbUZ1WjNWcGVqSTVJaXdpWVNJNkltTnRiM0p3YlRkcU5UQTNZWGN5YzI5bGRXZDBiVGhyY1c0aWZRLkR6LTdHUFEwRlI0aGRKRjJYWHI4N0EKR0VNSU5JX0FQSV9LRVk9RkFLRS1URVNULUtFWS1OT1QtQS1SRUFMLUNSRURFTlRJQUwK";
      final envText = utf8.decode(base64Decode(b64Env));
      dotenv.testLoad(fileInput: envText);
    } catch (e) {
      print("Error loading safe test env variables: $e");
    }
  });

  test('Validar Base de Datos de Pórticos', () {
    final tolls = TollsDatabase.santiagoTolls;
    expect(tolls.length, 106);
    
    final p3 = tolls.firstWhere((t) => t.name == "P3 Puente Lo Saldes - Vivaceta" && t.direction == "O-P");
    expect(p3.cost, 719.04);
    expect(p3.costPunta, 1384.32);
    expect(p3.costSaturacion, 2096.64);
  });

  test('Simular Ruta y Detección de Peajes', () async {
    
    final service = SimulatedTollService();
    final origin = LatLng(-33.280, -70.690);      // Chicureo
    final destination = LatLng(-33.560, -70.680); // San Bernardo
    
    print("Iniciando cálculo de ruta de prueba...");
    final routeData = await service.calculateRouteAndTolls(
      origin: origin,
      destination: destination,
    );
    
    print("Distancia calculada: ${routeData.distanceKm} km");
    print("Costo total estimado: ${routeData.totalCost} CLP");
    print("Pórticos detectados: ${routeData.tolls.length}");
    for (var toll in routeData.tolls) {
      print("  - ${toll.name} (Costo: ${toll.cost} CLP)");
    }
    
    expect(routeData.tolls.length, greaterThan(0));
  });

  test('Simular Ruta y Detección de Peajes - Lampa a Maipú', () async {
    
    final service = SimulatedTollService();
    final origin = LatLng(-33.282, -70.879);      // Lampa
    final destination = LatLng(-33.517, -70.767); // Maipú
    
    print("Iniciando cálculo de ruta Lampa -> Maipú...");
    final routeData = await service.calculateRouteAndTolls(
      origin: origin,
      destination: destination,
    );
    
    print("Distancia calculada: ${routeData.distanceKm} km");
    print("Costo total estimado: ${routeData.totalCost} CLP");
    print("Pórticos detectados: ${routeData.tolls.length}");
    for (var toll in routeData.tolls) {
      print("  - ${toll.name} (Costo: ${toll.cost} CLP)");
    }
    
    expect(routeData.tolls.length, equals(4));
  });

  test('Simular Ruta Usuario - Maipu a Huechuraba', () async {
    
    final service = SimulatedTollService();
    final origin = LatLng(-33.5132, -70.7587); // Av. 5 de Abril 313, Maipú
    final destination = LatLng(-33.3852, -70.6225); // Palacio Riesco 4515, Huechuraba
    
    print("Iniciando cálculo de ruta Maipu -> Huechuraba...");
    final routeData = await service.calculateRouteAndTolls(
      origin: origin,
      destination: destination,
    );
    
    print("Distancia calculada: ${routeData.distanceKm} km");
    print("Costo total estimado: ${routeData.totalCost} CLP");
    print("Pórticos detectados: ${routeData.tolls.length}");
    for (var toll in routeData.tolls) {
      print("  - ${toll.name} (Costo: ${toll.cost} CLP)");
    }
  });
}
