class VehiculoModel {
  final String id;
  final String usuarioId;
  final String patente;
  final String? alias;
  final String tipoVehiculo; // Ej: '2AxlesAuto', 'Motorcycle'

  VehiculoModel({
    required this.id,
    required this.usuarioId,
    required this.patente,
    this.alias,
    required this.tipoVehiculo,
  });

  factory VehiculoModel.fromJson(Map<String, dynamic> json, String id) {
    return VehiculoModel(
      id: id,
      usuarioId: json['usuario_id'] ?? '',
      patente: json['patente'] ?? '',
      alias: json['alias'],
      tipoVehiculo: json['tipo_vehiculo'] ?? '2AxlesAuto',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario_id': usuarioId,
      'patente': patente,
      'alias': alias,
      'tipo_vehiculo': tipoVehiculo,
    };
  }
}
