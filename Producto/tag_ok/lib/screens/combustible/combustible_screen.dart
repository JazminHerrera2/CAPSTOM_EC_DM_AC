import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/abastecimiento_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/abastecimiento_service.dart';
import '../../data/services/vehiculo_service.dart';
import '../dashboard/dashboard_logica.dart';
import '../dashboard/filtro_mes_anio.dart';
import '../dashboard/gastos_historial.dart' show altoContenidoTarjetaGastos;
import '../mantenimiento/tarjeta_mantencion.dart'
    show formatoFecha, formatoMiles;
import '../mantenimiento/widgets_gasto.dart' show TokensGasto, clp;
import 'gasto_combustible.dart';
import 'registro_ia_combustible_screen.dart';

/// "Combustible y carga": gasto del mes e historial de cargas del vehículo
/// elegido, con el + para registrar una carga (con IA o a mano). Se abre como
/// una pantalla aparte (sin la barra de navegación), igual que Mantenciones.
class CombustibleScreen extends StatefulWidget {
  const CombustibleScreen({super.key});

  @override
  State<CombustibleScreen> createState() => _CombustibleScreenState();
}

class _CombustibleScreenState extends State<CombustibleScreen> {
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  final VehiculoService _vehiculoService = VehiculoService();
  final AbastecimientoService _service = AbastecimientoService();

  // Vehículo elegido en el filtro. Siempre hay uno seleccionado (no existe
  // "Todos"); si no se eligió ninguno o ya no existe, se usa el primero.
  String? _vehiculoId;

  // Filtros del historial. null = todos.
  int? _mes;
  int? _anio;

  // Un stream por vehículo, para no recrearlo en cada reconstrucción.
  String? _streamDe;
  Stream<List<AbastecimientoModel>>? _stream;

  String get _usuarioId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  Stream<List<AbastecimientoModel>> _streamPara(String vehiculoId) {
    if (_streamDe != vehiculoId || _stream == null) {
      _streamDe = vehiculoId;
      _stream = _service.streamPorVehiculo(vehiculoId);
    }
    return _stream!;
  }

  void _elegirVehiculo(String id) => setState(() {
    _vehiculoId = id;
    _mes = null;
    _anio = null;
  });

  Future<void> _eliminar(AbastecimientoModel carga) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Eliminar carga', style: TextStyle(color: textMain)),
        content: Text(
          '¿Eliminar la carga del ${formatoFecha(carga.fecha)}? '
          'Esta acción no se puede deshacer.',
          style: const TextStyle(color: textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFE11D48)),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.eliminar(carga.id);
      messenger.showSnackBar(const SnackBar(content: Text('Carga eliminada.')));
    } catch (e) {
      debugPrint('No se pudo eliminar la carga: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('No fue posible eliminar la carga.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'Combustible y carga',
          style: TextStyle(color: textMain, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: textMain),
      ),
      body: StreamBuilder<List<VehiculoModel>>(
        stream: _vehiculoService.streamVehiculosUsuario(_usuarioId),
        builder: (context, snapshot) {
          // El vehículo principal vive en el usuario (por patente), igual que
          // en Mantenciones.
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .doc(_usuarioId)
                .snapshots(),
            builder: (context, userSnapshot) {
              final principal =
                  (userSnapshot.data?.data()?['vehiculo_principal_id'] ?? '')
                      .toString();

              // El principal va siempre primero; el resto conserva su orden.
              final vehiculos = [...(snapshot.data ?? const <VehiculoModel>[])]
                ..sort((a, b) {
                  final esA = a.patente == principal;
                  final esB = b.patente == principal;
                  if (esA == esB) return 0;
                  return esA ? -1 : 1;
                });

              VehiculoModel? vehiculo;
              for (final v in vehiculos) {
                if (v.id == _vehiculoId) vehiculo = v;
              }
              vehiculo ??= vehiculos.isEmpty ? null : vehiculos.first;

              return SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        if (vehiculos.isNotEmpty)
                          _filtrosVehiculos(vehiculos, vehiculo?.id),
                        Expanded(child: _contenido(vehiculo)),
                      ],
                    ),
                    // El + significa REGISTRAR CARGA (igual que el + de
                    // Mantenciones).
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton(
                        heroTag: 'registrarCarga',
                        backgroundColor: primaryColor,
                        tooltip: 'Registrar carga',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegistroIaCombustibleScreen(
                                vehiculoIdInicial: vehiculo?.id,
                              ),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Un botón por cada vehículo del usuario (sin "Todos"), igual que en
  /// Mantenciones.
  Widget _filtrosVehiculos(List<VehiculoModel> vehiculos, String? activo) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (final v in vehiculos) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _elegirVehiculo(v.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: activo == v.id ? primaryColor : surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  v.patente,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: activo == v.id ? Colors.white : textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _contenido(VehiculoModel? vehiculo) {
    if (vehiculo == null) return _sinVehiculos();
    return StreamBuilder<List<AbastecimientoModel>>(
      stream: _streamPara(vehiculo.id),
      builder: (context, snapshot) {
        final todas = snapshot.data ?? const <AbastecimientoModel>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
          children: [
            _tarjetaGastoMes(todas, snapshot.hasError),
            const SizedBox(height: 22),
            _seccionHistorial(snapshot, todas),
          ],
        );
      },
    );
  }

  // ================================================================
  // GASTO DEL MES
  // ================================================================

  Widget _tarjetaGastoMes(List<AbastecimientoModel> todas, bool error) {
    final hoy = DateTime.now();
    final resumen = calcularResumenMes(todas, hoy);

    final detalle = resumen.cantidad == 0
        ? 'Sin cargas este mes'
        : [
            resumen.cantidad == 1 ? '1 carga' : '${resumen.cantidad} cargas',
            if (resumen.litros > 0) '${formatoCantidad(resumen.litros)} L',
            if (resumen.kwh > 0) '${formatoCantidad(resumen.kwh)} kWh',
          ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastado en ${nombreDelMes(hoy.month).toLowerCase()}',
          style: const TextStyle(
            color: TokensGasto.textoPrincipal,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Mismo tamaño que la tarjeta de gastos del Inicio.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TokensGasto.fondoCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            height: altoContenidoTarjetaGastos,
            child: error
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No fue posible cargar las cargas.',
                      style: TextStyle(
                        color: TokensGasto.textoSecundario,
                        fontSize: 14,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Una sola línea: si el monto es largo, se achica.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          clp(resumen.total),
                          maxLines: 1,
                          style: const TextStyle(
                            color: TokensGasto.textoPrincipal,
                            fontSize: 28,
                            height: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        detalle,
                        style: const TextStyle(
                          color: TokensGasto.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // HISTORIAL
  // ================================================================

  List<AbastecimientoModel> _filtrar(List<AbastecimientoModel> todas) {
    return todas.where((c) {
      if (_anio != null && c.fecha.year != _anio) return false;
      if (_mes != null && c.fecha.month != _mes) return false;
      return true;
    }).toList();
  }

  Widget _seccionHistorial(
    AsyncSnapshot<List<AbastecimientoModel>> snapshot,
    List<AbastecimientoModel> todas,
  ) {
    if (snapshot.hasError) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'No fue posible cargar el historial.',
            style: TextStyle(color: textMuted),
          ),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final lista = _filtrar(todas);
    final anios = {for (final c in todas) c.fecha.year}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Historial de cargas',
                style: TextStyle(
                  color: textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                lista.length == 1 ? '1 registro' : '${lista.length} registros',
                style: const TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (todas.isNotEmpty) ...[
          const SizedBox(height: 12),
          FiltroMesAnio(
            mes: _mes,
            anio: _anio,
            anios: anios,
            alCambiarMes: (v) => setState(() => _mes = v),
            alCambiarAnio: (v) => setState(() => _anio = v),
          ),
        ],
        const SizedBox(height: 12),
        if (lista.isEmpty)
          _estadoVacio(
            detalle: todas.isEmpty
                ? null
                : 'No hay cargas que coincidan con el filtro.',
          )
        else
          for (final c in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _tarjetaCarga(c),
            ),
      ],
    );
  }

  Widget _tarjetaCarga(AbastecimientoModel c) {
    final electrica = c.tipoAbastecimiento == TipoAbastecimiento.cargaElectrica;

    final lineas = <String>[
      [
        formatoFecha(c.fecha),
        if (c.kilometraje != null) '${formatoMiles(c.kilometraje!)} km',
      ].join(' · '),
      [
        if ((c.tipoCombustible ?? '').isNotEmpty) c.tipoCombustible!,
        if (c.cantidad != null) '${formatoCantidad(c.cantidad!)} ${c.unidad}',
        if (c.precioUnitario != null)
          '\$${formatoCantidad(c.precioUnitario!)}/${c.unidad}',
      ].join(' · '),
    ].where((l) => l.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solo el ícono, en azul y sin recuadro de color de fondo.
          SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              electrica
                  ? Icons.ev_station_outlined
                  : Icons.local_gas_station_outlined,
              color: primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final linea in lineas) ...[
                  const SizedBox(height: 4),
                  Text(
                    linea,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              c.total == null ? '—' : clp(c.total!),
              style: const TextStyle(
                color: textMain,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Eliminar carga',
            visualDensity: VisualDensity.compact,
            onPressed: () => _eliminar(c),
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48)),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // ESTADOS VACÍOS
  // ================================================================

  Widget _estadoVacio({String? detalle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_gas_station_outlined,
              color: primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'Aún no hay cargas registradas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            detalle ??
                'Toca el + para registrar una carga con la boleta de la '
                    'bencinera o a mano.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: textMuted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _sinVehiculos() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, color: textMuted, size: 55),
            SizedBox(height: 16),
            Text(
              'No tienes vehículos registrados',
              style: TextStyle(
                color: textMain,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Primero registra un vehículo desde Mi Vehículo para poder '
              'registrar sus cargas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
