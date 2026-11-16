import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/screens/estacionamientos/direccion_de_ubicacion.dart';

/// Nombre de las calles en la tarjeta del estacionamiento y en el historial
/// (HU-18, opción B del 12-nov: se busca al mostrar y se recuerda en memoria;
/// no se guarda en Firestore). Sin red: Mapbox está simulado.
void main() {
  const auto = GeoPoint(-33.437812, -70.650423);

  setUp(olvidarDireccionesEnMemoria);

  test('la clave redondea a 5 decimales (~1 m): el mismo punto usa la misma entrada', () {
    expect(claveDireccion(auto), '-33.43781,-70.65042');
    expect(claveDireccion(const GeoPoint(-33.4378121, -70.6504229)), claveDireccion(auto));
  });

  test('consulta a Mapbox una sola vez por punto, aunque se pida varias veces', () async {
    var llamadas = 0;
    Future<String?> buscar(double lat, double lng) async {
      llamadas++;
      return 'Plaza de Armas 442, Santiago';
    }

    final a = direccionConMemoria(auto, buscar: buscar);
    final b = direccionConMemoria(auto, buscar: buscar); // al mismo tiempo
    expect(await a, 'Plaza de Armas 442, Santiago');
    expect(await b, 'Plaza de Armas 442, Santiago');
    expect(await direccionConMemoria(auto, buscar: buscar), 'Plaza de Armas 442, Santiago');
    expect(llamadas, 1);
  });

  test('si Mapbox falla o no encuentra nada, no se recuerda y se reintenta', () async {
    var llamadas = 0;
    Future<String?> sinConexion(double lat, double lng) async {
      llamadas++;
      throw Exception('sin conexión');
    }

    expect(await direccionConMemoria(auto, buscar: sinConexion), isNull);
    expect(await direccionConMemoria(auto, buscar: (_, _) async => null), isNull);
    expect(await direccionConMemoria(auto, buscar: (_, _) async => 'Ahora sí 123'), 'Ahora sí 123');
    expect(llamadas, 1);
  });

  testWidgets('muestra "Buscando…" y luego "Quedó en …"', (tester) async {
    final respuesta = Completer<String?>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DireccionDeUbicacion(ubicacion: auto, buscar: (_, _) => respuesta.future),
      ),
    ));
    expect(find.text('Buscando la dirección…'), findsOneWidget);

    respuesta.complete('Plaza de Armas 442, Santiago');
    await tester.pumpAndSettle();
    expect(find.text('Quedó en Plaza de Armas 442, Santiago'), findsOneWidget);
  });

  testWidgets('sin dirección no muestra nada (es un dato de ayuda)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DireccionDeUbicacion(ubicacion: auto, buscar: (_, _) async => null),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quedó en'), findsNothing);
    expect(find.text('Buscando la dirección…'), findsNothing);
  });
}
