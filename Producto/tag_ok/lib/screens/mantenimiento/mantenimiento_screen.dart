import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/mantencion_service.dart';
import '../../data/services/vehiculo_service.dart';
import '../dashboard/dashboard_logica.dart';
import '../dashboard/gastos_historial.dart';
import '../dashboard/historial_gastos_screen.dart';
import '../herramientas/placeholder_modulo_screen.dart';
import 'historial_mantenimientos_screen.dart';
import 'proximas_mantenciones_screen.dart';
import 'registro_ia_mantenimiento_screen.dart';
import 'resumen_gastos_mantenciones.dart';
import 'tarjeta_mantencion.dart';


class MantenimientoScreen extends StatefulWidget {
  /// Vuelve a Herramientas (el módulo vive dentro de HomeScreen, no es una
  /// ruta que se pueda cerrar con Navigator.pop).
  final VoidCallback? onVolver;

  /// Desde el historial de gastos, el apartado TAG abre la pestaña Auditoría.
  final VoidCallback? onIrAAuditoria;

  const MantenimientoScreen({super.key, this.onVolver, this.onIrAAuditoria});

  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  @override
  State<MantenimientoScreen> createState() => _MantenimientoScreenState();
}

class _MantenimientoScreenState extends State<MantenimientoScreen> {
  static const Color bgColor = MantenimientoScreen.bgColor;
  static const Color surfaceColor = MantenimientoScreen.surfaceColor;
  static const Color primaryColor = MantenimientoScreen.primaryColor;
  static const Color textMain = MantenimientoScreen.textMain;
  static const Color textMuted = MantenimientoScreen.textMuted;

  final VehiculoService _vehiculoService = VehiculoService();

  // Vehículo elegido en el filtro. Siempre hay uno seleccionado (no existe
  // "Todos"); si no se eligió ninguno o ya no existe, se usa el primero.
  String? _vehiculoId;

  String get _usuarioId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  /// "Ver todo" de Gasto en mantenciones: abre el historial de gastos del
  /// vehículo (el mismo que se abre desde el Inicio).
  Future<void> _abrirHistorialGastos(VehiculoModel vehiculo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Indicador de carga mientras se leen los gastos.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    List<MovimientoGasto> movimientos;
    try {
      // El TAG (viajes) se asigna al vehículo principal.
      var esPrincipal = false;
      try {
        final usuario =
            await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        esPrincipal = usuario.data()?['vehiculo_principal_id'] == vehiculo.patente;
      } catch (_) {}
      movimientos = await cargarMovimientosDeGasto(
        uid: uid,
        vehiculoId: vehiculo.id,
        esPrincipal: esPrincipal,
      );
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistorialGastosScreen(
          nombreVehiculo: nombreParaHistorial(vehiculo),
          movimientos: movimientos,
          alAbrirCategoria: (categoria) {
            switch (categoria) {
              case CategoriaGasto.mantenciones:
                // Ya estamos en Mantenciones: se vuelve a esta página.
                Navigator.pop(context);
              case CategoriaGasto.tag:
                Navigator.pop(context);
                widget.onIrAAuditoria?.call();
              case CategoriaGasto.combustible:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlaceholderModuloScreen(
                      titulo: 'Combustible y carga',
                      icono: Icons.local_gas_station_outlined,
                      sprintEstimado: 'Sprint 4',
                    ),
                  ),
                );
              case CategoriaGasto.estacionamientos:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlaceholderModuloScreen(
                      titulo: 'Estacionamiento',
                      icono: Icons.local_parking_outlined,
                      sprintEstimado: 'Sprint 4',
                    ),
                  ),
                );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: widget.onVolver == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver a Herramientas',
                onPressed: widget.onVolver,
              ),
        title: const Text(
          'Mantenciones',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: textMain),
      ),
      body: StreamBuilder<List<VehiculoModel>>(
        stream: _vehiculoService.streamVehiculosUsuario(_usuarioId),
        builder: (context, snapshot) {
          // El vehículo principal vive en el usuario (por patente), igual que
          // en Mi Vehículo.
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
                        Expanded(child: _contenido(context, vehiculo)),
                      ],
                    ),
                    // El + significa REGISTRAR MANTENCIÓN (igual que el + de
                    // Mi Vehículo para agregar un vehículo).
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton(
                        heroTag: 'registrarMantencion',
                        backgroundColor: primaryColor,
                        tooltip: 'Registrar mantención',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RegistrarMantenimientoIaScreen(
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
  /// Mi Vehículo.
  Widget _filtrosVehiculos(List<VehiculoModel> vehiculos, String? activo) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (final v in vehiculos) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _vehiculoId = v.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: activo == v.id ? primaryColor : surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activo == v.id
                        ? primaryColor
                        : Colors.transparent,
                  ),
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

  Widget _contenido(BuildContext context, VehiculoModel? vehiculo) {
    final patente = vehiculo?.patente;
    final vehiculoId = vehiculo?.id;
    return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
          children: [
            // Gasto total y por mes
            if (vehiculoId != null) ...[
              ResumenGastosMantenciones(
                vehiculoId: vehiculoId,
                onVerTodo: () => _abrirHistorialGastos(vehiculo!),
              ),
              const SizedBox(height: 12),
            ],

            // Anuncio con el nombre de la próxima mantención programada.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Próximas mantenciones',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ResumenProxima(vehiculoId: vehiculoId),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Programar mantención: abre la lista de las programadas (con su
            // botón para programar una nueva y el de eliminar cada una).
            _MenuCard(
              icon: Icons.event_available_outlined,
              title: 'Programar mantención',
              subtitle: 'Programa y revisa tus próximas mantenciones',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProximasMantenimientosScreen(
                      patente: patente,
                      vehiculoId: vehiculoId,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _MenuCard(
              icon: Icons.history_rounded,
              title: 'Historial de mantenciones',
              subtitle: 'Revisa los servicios realizados',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistorialMantenimientosScreen(
                      patente: patente,
                      vehiculoId: vehiculoId,
                    ),
                  ),
                );
              },
            ),

          ],
    );
  }
}

// ================================================================
// OPCIÓN DEL MENÚ
// ================================================================

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MantenimientoScreen.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _IconBox(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MantenimientoScreen.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: MantenimientoScreen.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MantenimientoScreen.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// CONTENEDOR DE ICONOS
// ================================================================

/// Ícono de una tarjeta de Mantenciones: azul y sin recuadro de color detrás.
class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Icon(
        icon,
        color: MantenimientoScreen.primaryColor,
        size: 28,
      ),
    );
  }
}

// ================================================================
// ANUNCIO DE LA PRÓXIMA MANTENCIÓN
// ================================================================

/// Nombre de la próxima mantención programada del vehículo (y su fecha o
/// kilometraje), como un anuncio. Sin ninguna programada, lo avisa.
class _ResumenProxima extends StatefulWidget {
  final String? vehiculoId;

  const _ResumenProxima({this.vehiculoId});

  @override
  State<_ResumenProxima> createState() => _ResumenProximaState();
}

class _ResumenProximaState extends State<_ResumenProxima> {
  Stream<List<MantencionModel>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = _crearStream();
  }

  @override
  void didUpdateWidget(_ResumenProxima anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.vehiculoId != widget.vehiculoId) {
      _stream = _crearStream();
    }
  }

  Stream<List<MantencionModel>>? _crearStream() {
    final id = widget.vehiculoId;
    if (id == null) return null;
    return MantencionService()
        .streamPorVehiculo(id, estado: EstadoMantencion.programada);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return _contenido(null);
    return StreamBuilder<List<MantencionModel>>(
      stream: stream,
      builder: (context, snapshot) {
        final lista = snapshot.data ?? const <MantencionModel>[];
        return _contenido(lista.isEmpty ? null : lista.first);
      },
    );
  }

  Widget _contenido(MantencionModel? m) {
    final detalle = m == null
        ? 'Programa una mantención para recibir recordatorios.'
        : [
            if (m.proximaFecha != null) formatoFecha(m.proximaFecha!),
            if (m.proximoKilometraje != null)
              '${formatoMiles(m.proximoKilometraje!)} km',
          ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IconBox(icon: Icons.event_available_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m == null ? 'Sin mantenciones programadas' : m.nombreTipo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MantenimientoScreen.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detalle,
                style: const TextStyle(
                  color: MantenimientoScreen.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
