import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/mantencion_service.dart';
import '../../data/services/vehiculo_service.dart';
import 'registrar_mantenimiento_screen.dart';
import 'historial_mantenimientos_screen.dart';
import 'proximas_mantenciones_screen.dart';
import 'registro_ia_mantenimiento_screen.dart';
import 'tarjeta_mantencion.dart';


class MantenimientoScreen extends StatefulWidget {
  /// Vuelve a Herramientas (el módulo vive dentro de HomeScreen, no es una
  /// ruta que se pueda cerrar con Navigator.pop).
  final VoidCallback? onVolver;

  const MantenimientoScreen({super.key, this.onVolver});

  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

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
                child: Column(
                  children: [
                    if (vehiculos.isNotEmpty)
                      _filtrosVehiculos(vehiculos, vehiculo?.id),
                    Expanded(child: _contenido(context, vehiculo)),
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
                        : const Color(0xFF334155),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            // Próxima mantención
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
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
                  const SizedBox(height: 14),
                  _LinkMantenciones(patente: patente, vehiculoId: vehiculoId),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _MenuCard(
              icon: Icons.history_rounded,
              title: 'Historial de mantenciones',
              subtitle: 'Revisa los servicios realizados',
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        HistorialMantenimientosScreen(
                    patente: patente,
                    vehiculoId: vehiculoId,
                  ),
                  ),
                );
              },
            ),

            const SizedBox(height: 22),

            const Text(
              'Registrar mantenciones',
              style: TextStyle(
                color: textMain,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                          icon: Icons.add_circle_outline,
                          title: 'Registrar Manual',
                          subtitle: 'Nueva mantención',
                          color: primaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RegistrarMantenimientoScreen(
                                    vehiculoIdInicial: vehiculoId,
                                  ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Registrar con IA',
                    subtitle: 'Boleta o factura',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                        Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const RegistrarMantenimientoIaScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

          ],
    );
  }
}

// ================================================================
// TARJETA DE ACCIÓN RÁPIDA
// ================================================================

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MantenimientoScreen.surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(
                icon: icon,
                color: color,
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  color: MantenimientoScreen.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: MantenimientoScreen.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// OPCIÓN DEL MENÚ
// ================================================================

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
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
              _IconBox(
                icon: icon,
                color: color,
              ),
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: MantenimientoScreen.textMuted,
                        fontSize: 11,
                      ),
                    ),
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

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 22,
      ),
    );
  }
}

/// Enlace "Mantenciones →" al pie de la tarjeta de próxima mantención.
class _LinkMantenciones extends StatelessWidget {
  final String? patente;
  final String? vehiculoId;

  const _LinkMantenciones({this.patente, this.vehiculoId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProximasMantenimientosScreen(
                  patente: patente,
                  vehiculoId: vehiculoId,
                ),
          ),
        );
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Programar mantenciones',
              style: TextStyle(
                color: MantenimientoScreen.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: MantenimientoScreen.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}


/// Texto de la tarjeta "Próxima mantención": la programada más cercana del
/// vehículo, o el aviso de que no hay ninguna.
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
        const _IconBox(
          icon: Icons.event_available_outlined,
          color: Color(0xFFF59E0B),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m == null ? 'Sin mantenciones programadas' : m.nombreTipo,
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
