// Constantes de la simulación de recorrido del mapa (SOLO modo debug).
//
// La simulación no tiene lógica de cruce propia: un temporizador llama a
// `_simulateMovement` de `live_map_screen.dart` (la misma interpolación que ya
// usa la app con GPS débil), y los cruces los detecta `_checkTollCrossings`.
// Aquí solo se define cuánto avanza cada paso.

/// Velocidad base simulada; el multiplicador la acelera (1x = 60 km/h).
const double velocidadBaseSimulacionKmH = 60;

/// Velocidades que ofrece el botón "Simular recorrido".
const List<double> multiplicadoresSimulacion = [1, 5, 20];

/// Cada cuánto avanza la simulación. Es corto a propósito: `_simulateMovement`
/// solo revisa los cruces en la posición final de cada llamada (radio de 45 m),
/// así que pasos largos se saltarían pórticos.
const Duration pasoSimulacion = Duration(milliseconds: 100);

/// Sufijo que se agrega al `vehicleName` de los viajes guardados mientras la
/// simulación estuvo activa, para identificarlos y borrarlos.
const String sufijoViajeSimulado = ' [SIMULADO]';

/// Metros que avanza la simulación en cada paso con el [multiplicador] dado.
double metrosPorPasoSimulacion(double multiplicador) =>
    (velocidadBaseSimulacionKmH / 3.6) *
    multiplicador *
    (pasoSimulacion.inMilliseconds / 1000);

/// `vehicleName` de un viaje simulado: el nombre normal más [sufijoViajeSimulado].
String nombreVehiculoSimulado(String nombreVehiculo) =>
    '$nombreVehiculo$sufijoViajeSimulado';
