/// Los viajes (TAG) no guardan el id del vehículo, solo su nombre con el
/// formato "Marca (PATENTE)" (en debug, con el sufijo " [SIMULADO]"). Un viaje
/// es de un vehículo si ese nombre lleva su patente entre paréntesis.
bool viajeEsDeVehiculo(String nombreVehiculoDelViaje, String patente) {
  final p = patente.trim().toUpperCase();
  if (p.isEmpty) return false;
  return nombreVehiculoDelViaje.toUpperCase().contains('($p)');
}
