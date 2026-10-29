import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/models/vehiculo_model.dart';
import 'dashboard_logica.dart';

/// Lectura de los gastos de un vehículo para el historial de gastos. La usan el
/// Inicio (con datos en vivo) y Mantenciones (carga una vez al abrir el
/// historial), así el historial muestra lo mismo desde los dos lugares.

/// Alto del contenido de las tarjetas de gasto del mes (la del Inicio y la de
/// Mantenciones). Con 16 px de margen arriba y abajo, la tarjeta mide 84 px.
const double altoContenidoTarjetaGastos = 52;

typedef DocsFirestore = Iterable<QueryDocumentSnapshot<Map<String, dynamic>>>;

/// Viajes con peajes (TAG). Los viajes no guardan el vehículo: se asignan al
/// principal. Los viajes con datos incompletos no suman.
List<GastoRegistro> gastosDeViajes(DocsFirestore docs) {
  final lista = <GastoRegistro>[];
  for (final d in docs) {
    try {
      final data = d.data();
      final fecha = DateTime.parse(data['date'] as String);
      final monto = (data['totalCost'] as num).round();
      final peajes = data['tolls'] is List ? (data['tolls'] as List).length : 0;
      lista.add((
        vehiculoId: null,
        fecha: fecha,
        monto: monto,
        titulo: 'Viaje con peajes',
        detalle: peajes == 0 ? null : (peajes == 1 ? '1 peaje' : '$peajes peajes'),
      ));
    } catch (_) {
      // Viaje con datos incompletos: no suma.
    }
  }
  return lista;
}

/// Gastos de una colección con `fecha` (Timestamp) y un campo de monto, como
/// `abastecimientos` (total) y `estacionamientos` (costo).
List<GastoRegistro> gastosDeDocumentos(
  DocsFirestore docs, {
  required String campoMonto,
  required String titulo,
  required String campoDetalle,
}) {
  final lista = <GastoRegistro>[];
  for (final d in docs) {
    final data = d.data();
    final fecha = data['fecha'];
    final monto = data[campoMonto];
    if (fecha is Timestamp && monto is num) {
      final detalle = data[campoDetalle];
      lista.add((
        vehiculoId: data['vehiculo_id'] as String?,
        fecha: fecha.toDate(),
        monto: monto.round(),
        titulo: titulo,
        detalle: detalle is String ? detalle : null,
      ));
    }
  }
  return lista;
}

/// Nombre del vehículo para mostrar sobre el historial.
String nombreParaHistorial(VehiculoModel v) {
  final alias = (v.alias ?? '').trim();
  if (alias.isNotEmpty) return '$alias · ${v.patente}';
  return [v.marca, v.modelo, v.patente]
      .where((e) => e != null && e.trim().isNotEmpty)
      .join(' ');
}

/// Lee una sola vez todos los gastos de un vehículo y los junta, del más
/// reciente al más antiguo. Si una fuente no existe o no se puede leer (p. ej.
/// Combustible y Estacionamientos, del Sprint 4), cuenta como vacía.
Future<List<MovimientoGasto>> cargarMovimientosDeGasto({
  required String uid,
  required String vehiculoId,
  required bool esPrincipal,
}) async {
  final db = FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> leer(
    Query<Map<String, dynamic>> consulta,
  ) async {
    try {
      return (await consulta.get()).docs;
    } catch (e) {
      debugPrint('Historial de gastos: fuente no disponible: $e');
      return const [];
    }
  }

  final mantenciones = await leer(
    db
        .collection('mantenciones')
        .where('uid', isEqualTo: uid)
        .where('vehiculo_id', isEqualTo: vehiculoId),
  );
  final viajes = esPrincipal
      ? await leer(db.collection('usuarios').doc(uid).collection('trips'))
      : const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final combustible =
      await leer(db.collection('abastecimientos').where('uid', isEqualTo: uid));
  final estacionamientos =
      await leer(db.collection('estacionamientos').where('uid', isEqualTo: uid));

  bool esDeEste(GastoRegistro g) => g.vehiculoId == vehiculoId;

  return movimientosDeGasto({
    CategoriaGasto.mantenciones: gastosDeMantenciones(
      mantenciones.map((d) => MantencionModel.fromJson(d.data(), d.id)),
    ),
    CategoriaGasto.tag: gastosDeViajes(viajes),
    CategoriaGasto.combustible: gastosDeDocumentos(
      combustible,
      campoMonto: 'total',
      titulo: 'Carga de combustible',
      campoDetalle: 'estacion_servicio',
    ).where(esDeEste),
    CategoriaGasto.estacionamientos: gastosDeDocumentos(
      estacionamientos,
      campoMonto: 'costo',
      titulo: 'Estacionamiento',
      campoDetalle: 'lugar',
    ).where(esDeEste),
  });
}
