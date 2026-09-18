import 'package:cloud_firestore/cloud_firestore.dart';

/// Entidad VEHICULOS, colección `vehiculos` — compartida entre Fase 1
/// (clasificación de tarifa TAG, `vehiculos_screen.dart`) y Fase 2 (ficha
/// completa del vehículo, módulo Mi Vehículo). Un mismo documento puede ser
/// creado o editado por cualquiera de los dos flujos.
///
/// `idUsuario` se mantiene como DocumentReference (no como string) a
/// propósito: es el campo que usan las queries de Fase 1
/// (`vehiculos_screen.dart`, `data/services/history_service.dart`) para
/// filtrar por dueño. Si Fase 2 escribiera un `usuario_id` string en vez de
/// reusar este campo, los vehículos de cada flujo quedarían invisibles para
/// el otro dentro de la misma colección. Ver addendum en
/// docs/00-sprint-actual.md.
///
/// `categoria` (Fase 1, tarifaria: AUTO/CAMIONETA/MOTO) y `tipoVehiculo`
/// (Fase 2, descriptiva: SUV/Sedán/etc.) son campos distintos que coexisten
/// a propósito — no se fusionan.
class VehiculoModel {
  final String id;
  final DocumentReference idUsuario;
  final String patente;

  // --- Campos de Fase 1 (vehiculos_screen.dart), sin modificar ---
  final String? categoria;
  final String? fechaIngreso;

  // --- Campos compartidos ---
  final String? marca;

  // --- Campos nuevos de Fase 2 (ficha completa del vehículo) ---
  final String? modelo;
  final int? anio;
  final String? tipoVehiculo;
  final String? tipoCombustible;
  final int? kilometrajeActual;
  final String? alias;
  final String? fotoPath;
  final String? estado;

  VehiculoModel({
    required this.id,
    required this.idUsuario,
    required this.patente,
    this.categoria,
    this.fechaIngreso,
    this.marca,
    this.modelo,
    this.anio,
    this.tipoVehiculo,
    this.tipoCombustible,
    this.kilometrajeActual,
    this.alias,
    this.fotoPath,
    this.estado,
  });

  factory VehiculoModel.fromJson(Map<String, dynamic> json, String id) {
    return VehiculoModel(
      id: id,
      idUsuario: json['id_usuario'] as DocumentReference,
      patente: json['patente'] ?? '',
      categoria: json['categoria'],
      fechaIngreso: json['fecha_ingreso'],
      marca: json['marca'],
      modelo: json['modelo'],
      anio: json['anio'] as int?,
      tipoVehiculo: json['tipo_vehiculo'],
      tipoCombustible: json['tipo_combustible'],
      kilometrajeActual: json['kilometraje_actual'] as int?,
      alias: json['alias'],
      fotoPath: json['foto_path'],
      estado: json['estado'],
    );
  }

  /// Para creación de un vehículo nuevo desde Mi Vehículo (CU1). No incluye
  /// `categoria`/`fecha_ingreso`: esos son de Fase 1 y se dejan sin
  /// completar cuando el vehículo se origina en Fase 2 (no se inventan).
  Map<String, dynamic> toJson() {
    return {
      'id_usuario': idUsuario,
      'patente': patente,
      if (marca != null) 'marca': marca,
      if (modelo != null) 'modelo': modelo,
      if (anio != null) 'anio': anio,
      if (tipoVehiculo != null) 'tipo_vehiculo': tipoVehiculo,
      if (tipoCombustible != null) 'tipo_combustible': tipoCombustible,
      if (kilometrajeActual != null) 'kilometraje_actual': kilometrajeActual,
      if (alias != null) 'alias': alias,
      if (fotoPath != null) 'foto_path': fotoPath,
      'estado': estado ?? 'activo',
    };
  }

  /// CU5 — determina el estado general según los vencimientos de sus
  /// documentos. No decide nada por sí sola si no hay documentos (E1/E2 de
  /// CU5): en ese caso el llamador debe mostrar "Sin información".
  static String calcularEstadoGeneral(
    List<DateTime?> fechasVencimiento, {
    DateTime? ahora,
  }) {
    final hoy = ahora ?? DateTime.now();
    final fechas = fechasVencimiento.whereType<DateTime>().toList();
    if (fechas.isEmpty) return 'Sin información';

    final vencidos = fechas.where((f) => f.isBefore(hoy)).isNotEmpty;
    if (vencidos) return 'Atención requerida';

    final proximoLimite = hoy.add(const Duration(days: 30));
    final proximo = fechas
        .where((f) => f.isBefore(proximoLimite))
        .isNotEmpty;
    if (proximo) return 'Próximo vencimiento';

    return 'Todo al día';
  }
}
