import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:latlong2/latlong.dart';

/// Última posición real del usuario que ya obtuvo el mapa de rutas
/// (`LiveMapScreen`).
///
/// `LiveMapScreen` queda siempre montado en la pantalla principal: pide el GPS
/// y abre el seguimiento en vivo apenas arranca la app. Con esto, las demás
/// pantallas con mapa (por ejemplo Estacionamientos) pueden usar esa misma
/// posición en vez de esperar un GPS en frío, que en el navegador puede tardar
/// varios segundos.
///
/// Solo guarda la posición; la lógica del GPS sigue en `LiveMapScreen`.
abstract final class PosicionCompartida {
  static LatLng? _posicion;
  static DateTime? _momento;

  /// Lo llama el mapa de rutas cada vez que recibe una posición real.
  static void actualizar(LatLng posicion, {DateTime? ahora}) {
    _posicion = posicion;
    _momento = ahora ?? DateTime.now();
  }

  /// La última posición conocida, o null si no hay o ya es muy antigua
  /// ([vigencia]).
  static GeoPoint? reciente({
    Duration vigencia = const Duration(minutes: 5),
    DateTime? ahora,
  }) {
    final posicion = _posicion;
    final momento = _momento;
    if (posicion == null || momento == null) return null;
    final edad = (ahora ?? DateTime.now()).difference(momento);
    if (edad > vigencia) return null;
    return GeoPoint(posicion.latitude, posicion.longitude);
  }

  /// Solo para tests.
  static void olvidar() {
    _posicion = null;
    _momento = null;
  }
}
