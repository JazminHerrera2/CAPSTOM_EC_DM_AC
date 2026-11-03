/// Los viajes (TAG) no guardan el id del vehículo, solo su nombre con el
/// formato "Marca (PATENTE)" (en debug, con el sufijo " [SIMULADO]"). Un viaje
/// es de un vehículo si ese nombre lleva su patente entre paréntesis.
bool viajeEsDeVehiculo(String nombreVehiculoDelViaje, String patente) {
  final p = patente.trim().toUpperCase();
  if (p.isEmpty) return false;
  return nombreVehiculoDelViaje.toUpperCase().contains('($p)');
}

/// Una boleta auditada guarda la patente que leyó del documento (a veces con
/// puntos o guiones, o en minúsculas). Es del vehículo si, ignorando todo lo
/// que no sea letra o número, es la misma patente.
bool boletaEsDeVehiculo(String? patenteDeLaBoleta, String patente) {
  String limpia(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  final p = limpia(patente);
  return p.isNotEmpty && limpia(patenteDeLaBoleta ?? '') == p;
}
