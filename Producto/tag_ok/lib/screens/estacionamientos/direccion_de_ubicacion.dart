import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/services/geocoding_service.dart';

/// Busca una dirección para unas coordenadas: por defecto, la búsqueda inversa
/// de Mapbox ([GeocodingService.direccionDe]).
typedef BuscarDireccion = Future<String?> Function(
    double latitud, double longitud);

/// Direcciones ya buscadas mientras la app está abierta, por coordenadas. Se
/// guarda el Future (no solo el resultado) para que dos pantallas que piden la
/// misma dirección al mismo tiempo hagan una sola consulta a Mapbox. Se borra
/// al cerrar la app: la dirección no se guarda en Firestore (opción B, 12-nov).
final Map<String, Future<String?>> _direccionesEnMemoria = {};

/// Clave de la memoria: coordenadas con 5 decimales (~1 metro), para que el
/// mismo punto leído de distintas pantallas use la misma entrada.
String claveDireccion(GeoPoint ubicacion) =>
    '${ubicacion.latitude.toStringAsFixed(5)},'
    '${ubicacion.longitude.toStringAsFixed(5)}';

/// Dirección escrita de [ubicacion], consultando a Mapbox solo la primera vez.
/// Si la consulta falla, devuelve null y no la recuerda, para reintentar la
/// próxima vez (por ejemplo, cuando vuelva la conexión).
Future<String?> direccionConMemoria(GeoPoint ubicacion, {BuscarDireccion? buscar}) {
  final clave = claveDireccion(ubicacion);
  return _direccionesEnMemoria.putIfAbsent(clave, () async {
    try {
      final direccion = await (buscar ?? GeocodingService().direccionDe)(
        ubicacion.latitude,
        ubicacion.longitude,
      );
      if (direccion == null) _direccionesEnMemoria.remove(clave);
      return direccion;
    } catch (_) {
      _direccionesEnMemoria.remove(clave);
      return null;
    }
  });
}

/// Solo para tests: vacía la memoria de direcciones.
@visibleForTesting
void olvidarDireccionesEnMemoria() => _direccionesEnMemoria.clear();

/// Muestra "📍 Quedó en Av. Ejemplo 1234, Comuna" para una ubicación guardada
/// (HU-18). Mientras busca dice "Buscando la dirección…"; si no la encuentra
/// (sin conexión o sin resultados) no muestra nada, porque es un dato de ayuda.
///
/// Se usa en la tarjeta del estacionamiento en curso, en el historial y en
/// "¿Dónde está mi auto?". El front del módulo lo puede usar tal cual:
/// ```dart
/// if (e.tieneUbicacion) DireccionDeUbicacion(ubicacion: e.ubicacion!)
/// ```
class DireccionDeUbicacion extends StatelessWidget {
  const DireccionDeUbicacion({
    super.key,
    required this.ubicacion,
    this.prefijo = 'Quedó en ',
    this.estilo,
    this.buscar,
  });

  final GeoPoint ubicacion;

  /// Texto antes de la dirección.
  final String prefijo;
  final TextStyle? estilo;

  /// Para pruebas; por defecto, Mapbox.
  final BuscarDireccion? buscar;

  @override
  Widget build(BuildContext context) {
    final estiloBase = estilo ??
        TextStyle(color: Colors.grey.shade800, fontSize: 13);
    return FutureBuilder<String?>(
      future: direccionConMemoria(ubicacion, buscar: buscar),
      builder: (context, snap) {
        final buscando = snap.connectionState != ConnectionState.done;
        final direccion = snap.data;
        if (!buscando && direccion == null) return const SizedBox.shrink();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place_outlined,
                size: (estiloBase.fontSize ?? 13) + 3,
                color: estiloBase.color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                buscando ? 'Buscando la dirección…' : '$prefijo$direccion',
                style: estiloBase,
              ),
            ),
          ],
        );
      },
    );
  }
}
