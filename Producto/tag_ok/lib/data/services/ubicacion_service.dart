import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Por qué no se pudo obtener la ubicación (excepciones E1 y E2 del CU18).
enum MotivoErrorUbicacion {
  /// El GPS o la ubicación del dispositivo están apagados (E1).
  gpsDesactivado,

  /// El usuario no dio permiso esta vez (E2).
  permisoDenegado,

  /// El permiso quedó bloqueado: solo se habilita desde los ajustes (E2).
  permisoBloqueado,

  /// No llegó una posición a tiempo, por ejemplo sin señal (E1).
  sinSenal,
}

/// Texto que la pantalla le muestra al usuario para cada motivo.
String mensajeErrorUbicacion(MotivoErrorUbicacion motivo) {
  switch (motivo) {
    case MotivoErrorUbicacion.gpsDesactivado:
      return 'Activa la ubicación de tu dispositivo para guardar dónde '
          'quedó tu auto.';
    case MotivoErrorUbicacion.permisoDenegado:
      return 'Sin permiso de ubicación no se puede guardar dónde quedó tu '
          'auto.';
    case MotivoErrorUbicacion.permisoBloqueado:
      return 'El permiso de ubicación está bloqueado. Habilítalo en los '
          'ajustes de tu dispositivo o del navegador.';
    case MotivoErrorUbicacion.sinSenal:
      return 'No se pudo obtener tu ubicación. Revisa la señal e inténtalo '
          'de nuevo.';
  }
}

/// Error al obtener la ubicación, con un mensaje listo para mostrar.
class ErrorUbicacion implements Exception {
  const ErrorUbicacion(this.motivo);

  final MotivoErrorUbicacion motivo;

  /// Texto listo para mostrarle al usuario.
  String get mensaje => mensajeErrorUbicacion(motivo);

  @override
  String toString() => mensaje;
}

/// Distancia en línea recta, en metros, entre dos puntos.
double distanciaEnMetros(GeoPoint a, GeoPoint b) {
  return const Distance().as(
    LengthUnit.Meter,
    LatLng(a.latitude, a.longitude),
    LatLng(b.latitude, b.longitude),
  );
}

/// "a 230 m" o "a 1,4 km", para mostrar cuánto falta para llegar al auto.
String textoDistancia(double metros) {
  if (metros < 1000) return 'a ${metros.round()} m';
  final km = (metros / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return 'a $km km';
}

/// Obtiene la posición GPS del dispositivo (RF-019, HU-18). Funciona en web y
/// en Android con el paquete `geolocator`, el mismo del mapa de TAG.
class UbicacionService {
  /// Tiempo máximo para esperar la primera posición. Igual que el mapa de
  /// rutas (live_map_screen): si no llega a tiempo, se sigue igual con el
  /// seguimiento en vivo en vez de dejar al usuario esperando.
  static const Duration tiempoMaximo = Duration(seconds: 5);

  /// Última posición que el dispositivo ya tenía guardada, al instante y sin
  /// encender el GPS. Sirve para mostrar algo en el mapa mientras llega la
  /// posición real. Devuelve null si no hay, si todavía no hay permiso o en la
  /// web (el navegador no la entrega).
  Future<GeoPoint?> ultimaUbicacionConocida() async {
    if (kIsWeb) return null;
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : GeoPoint(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Revisa que la ubicación esté activa, pide el permiso si hace falta y
  /// devuelve la posición actual. Si no se puede, lanza [ErrorUbicacion] con el
  /// motivo, para que la pantalla muestre el mensaje.
  Future<GeoPoint> obtenerUbicacionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ErrorUbicacion(MotivoErrorUbicacion.gpsDesactivado);
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw const ErrorUbicacion(MotivoErrorUbicacion.permisoDenegado);
    }
    if (permiso == LocationPermission.deniedForever) {
      throw const ErrorUbicacion(MotivoErrorUbicacion.permisoBloqueado);
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        // Mismos ajustes que el mapa de rutas (live_map_screen).
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: tiempoMaximo,
        ),
      );
      return GeoPoint(posicion.latitude, posicion.longitude);
    } catch (e) {
      throw traducirErrorUbicacion(e);
    }
  }

  /// Sigue la posición del usuario en vivo: entrega un punto nuevo cada vez
  /// que se mueve al menos [metrosMinimos]. Se usa en "¿Dónde está mi auto?"
  /// para que el punto azul y la distancia se actualicen mientras camina.
  /// Llamar después de [obtenerUbicacionActual], que ya pidió el permiso. El
  /// seguimiento se detiene al cancelar la suscripción (al cerrar el mapa).
  Stream<GeoPoint> seguirUbicacion() {
    // Mismos ajustes que el mapa de rutas (live_map_screen) en reposo: máxima
    // precisión y una actualización apenas el usuario se mueve.
    final LocationSettings ajustes;
    if (defaultTargetPlatform == TargetPlatform.android) {
      ajustes = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      ajustes = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
      );
    } else {
      ajustes = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );
    }
    return Geolocator.getPositionStream(locationSettings: ajustes).transform(StreamTransformer<Position, GeoPoint>.fromHandlers(
      handleData: (p, sink) => sink.add(GeoPoint(p.latitude, p.longitude)),
      handleError: (e, _, sink) => sink.addError(traducirErrorUbicacion(e)),
    ));
  }
}

/// Convierte los errores de `geolocator` en un [ErrorUbicacion] con mensaje
/// para el usuario. Lo que no se reconoce se trata como "sin señal".
ErrorUbicacion traducirErrorUbicacion(Object error) {
  if (error is ErrorUbicacion) return error;
  if (error is LocationServiceDisabledException) {
    return const ErrorUbicacion(MotivoErrorUbicacion.gpsDesactivado);
  }
  if (error is PermissionDeniedException) {
    return const ErrorUbicacion(MotivoErrorUbicacion.permisoDenegado);
  }
  // TimeoutException, PositionUpdateException (en el navegador: "posición no
  // disponible", por ejemplo con la ubicación de Windows apagada) y otros.
  return const ErrorUbicacion(MotivoErrorUbicacion.sinSenal);
}
