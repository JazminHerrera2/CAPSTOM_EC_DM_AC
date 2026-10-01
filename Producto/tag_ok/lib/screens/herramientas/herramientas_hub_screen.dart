import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/documento_vehicular_service.dart';
import '../../data/services/notificacion_service.dart';
import '../mi_vehiculo/registrar_documento_ia_screen.dart';
import '../profile_screen.dart';
import 'placeholder_modulo_screen.dart';

/// Hub de "Herramientas" (antes "Perfil" en el bottom nav). Reestructuración
/// de navegación que reemplaza la decisión de
/// docs/06-decision-navegacion.md — reemplaza el acceso directo a
/// ProfileScreen por este hub con accesos a perfil y a los módulos de
/// Fase 2 todavía no implementados.
class HerramientasHubScreen extends StatefulWidget {
  final VoidCallback? onAbrirMantenciones;

  const HerramientasHubScreen({
    super.key,
    this.onAbrirMantenciones,
  });

  @override
  State<HerramientasHubScreen> createState() =>
      _HerramientasHubScreenState();
}

class _HerramientasHubScreenState extends State<HerramientasHubScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DocumentoVehicularService _documentoService =
      DocumentoVehicularService();
  final NotificacionService _notificacionService = NotificacionService();

  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

  Future<void> _probarEstadosVencimiento() async {
    final ahora = DateTime(2026, 9, 27, 15, 30);
    final casos = <({String fecha, String esperado, DateTime? valor})>[
      (
        fecha: '26/09/2026',
        esperado: 'Atención requerida',
        valor: DateTime(2026, 9, 26),
      ),
      (
        fecha: '27/09/2026',
        esperado: 'Atención requerida',
        valor: DateTime(2026, 9, 27),
      ),
      (
        fecha: '28/09/2026',
        esperado: 'Próximo vencimiento',
        valor: DateTime(2026, 9, 28),
      ),
      (
        fecha: '27/10/2026',
        esperado: 'Próximo vencimiento',
        valor: DateTime(2026, 10, 27),
      ),
      (
        fecha: '28/10/2026',
        esperado: 'Todo al día',
        valor: DateTime(2026, 10, 28),
      ),
      (
        fecha: 'null',
        esperado: 'Sin información',
        valor: null,
      ),
    ];

    final resultados = casos.map((caso) {
      final obtenido = VehiculoModel.calcularEstadoGeneral(
        [caso.valor],
        ahora: ahora,
      );
      final correcto = obtenido == caso.esperado;
      return '${caso.fecha}: esperado "${caso.esperado}" | '
          'obtenido "$obtenido" | ${correcto ? 'OK' : 'ERROR'}';
    }).toList();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prueba de estados de vencimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: resultados
              .map(
                (resultado) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(resultado),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _probarActualizarVencimiento() async {
    try {
      await _documentoService.actualizarVencimiento(
        'Gb76D9tP4Up42FiKrpqP',
        DateTime(2026, 11, 30),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vencimiento actualizado correctamente a 30/11/2026',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al actualizar vencimiento: $e',
          ),
        ),
      );
    }
  }

  Future<void> _probarNotificaciones() async {
    try {
      final snapshot = await _firestore
          .collection('vehiculos')
          .where('patente', isEqualTo: 'TEST26')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el vehículo TEST26')),
        );
        return;
      }

      final vehiculoId = snapshot.docs.first.id;
      final fechaVencimiento = DateTime.now().add(const Duration(days: 30));

      await _notificacionService.configurarNotificacionesVencimiento(
        vehiculoId: vehiculoId,
        documentoId: 'documento_prueba_notificaciones',
        nombreDocumento: 'SOAP de prueba',
        fechaVencimiento: fechaVencimiento,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prueba completada: revisa Firestore > notificaciones'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en prueba de notificaciones: $e')),
      );
    }
  }

  Future<void> _abrirRegistroDocumento() async {
    try {
      final snapshot = await _firestore
          .collection('vehiculos')
          .where('patente', isEqualTo: 'TEST26')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró el vehículo TEST26'),
          ),
        );
        return;
      }

      final vehiculoId = snapshot.docs.first.id;

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegistrarDocumentoIaScreen(
            vehiculoId: vehiculoId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir registro de documento: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accesos = <_AccesoHerramienta>[
      _AccesoHerramienta(
        titulo: 'Mi perfil',
        icono: Icons.person_outline,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        ),
      ),
      _AccesoHerramienta(
        titulo: 'Combustible',
        icono: Icons.local_gas_station_outlined,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaceholderModuloScreen(
              titulo: 'Combustible',
              icono: Icons.local_gas_station_outlined,
              sprintEstimado: 'Sprint 4',
            ),
          ),
        ),
      ),
      _AccesoHerramienta(
        titulo: 'Estacionamiento',
        icono: Icons.local_parking_outlined,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaceholderModuloScreen(
              titulo: 'Estacionamiento',
              icono: Icons.local_parking_outlined,
              sprintEstimado: 'Sprint 4',
            ),
          ),
        ),
      ),
      _AccesoHerramienta(
        titulo: 'Beneficios',
        icono: Icons.card_giftcard_outlined,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaceholderModuloScreen(
              titulo: 'Beneficios',
              icono: Icons.card_giftcard_outlined,
              sprintEstimado: 'Sprint 5',
            ),
          ),
        ),
      ),
      _AccesoHerramienta(
        titulo: 'Mantenciones',
        icono: Icons.handyman_outlined,
        onTap: (context) {
          if (widget.onAbrirMantenciones != null) {
            widget.onAbrirMantenciones!();
          }
        },
      ),
      if (kDebugMode) ...[
        _AccesoHerramienta(
          titulo: 'DEV - Registrar documento (TEST26)',
          icono: Icons.description_outlined,
          onTap: (context) => _abrirRegistroDocumento(),
        ),
        _AccesoHerramienta(
          titulo: 'DEV - Notificaciones',
          icono: Icons.warning_amber_rounded,
          onTap: (context) => _probarNotificaciones(),
        ),
        _AccesoHerramienta(
          titulo: 'DEV - Actualizar vencimiento',
          icono: Icons.edit_calendar_outlined,
          onTap: (context) => _probarActualizarVencimiento(),
        ),
        _AccesoHerramienta(
          titulo: 'DEV - Estados vencimiento',
          icono: Icons.fact_check_outlined,
          onTap: (context) => _probarEstadosVencimiento(),
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text('Herramientas', style: TextStyle(color: _textMain)),
        iconTheme: const IconThemeData(color: _textMain),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: accesos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final acceso = accesos[index];
            return Material(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => acceso.onTap(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(acceso.icono, color: _primaryColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          acceso.titulo,
                          style: const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: _textMuted),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccesoHerramienta {
  final String titulo;
  final IconData icono;
  final void Function(BuildContext context) onTap;

  _AccesoHerramienta({
    required this.titulo,
    required this.icono,
    required this.onTap,
  });
}
