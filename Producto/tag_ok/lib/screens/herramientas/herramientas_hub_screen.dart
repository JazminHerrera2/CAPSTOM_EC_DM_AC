import 'package:flutter/material.dart';
import '../profile_screen.dart';
import '../vehiculos_screen.dart';
import 'placeholder_modulo_screen.dart';

/// Hub de "Herramientas" (antes "Perfil" en el bottom nav). Reestructuración
/// de navegación que reemplaza la decisión de
/// docs/06-decision-navegacion.md — reemplaza el acceso directo a
/// ProfileScreen por este hub con accesos a perfil y a los módulos de
/// Fase 2 todavía no implementados.
class HerramientasHubScreen extends StatelessWidget {
  const HerramientasHubScreen({super.key});

  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

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
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaceholderModuloScreen(
              titulo: 'Mantenciones',
              icono: Icons.handyman_outlined,
              sprintEstimado: 'Sprint 3',
            ),
          ),
        ),
      ),
      _AccesoHerramienta(
        titulo: 'Categoría de vehículo (TAG)',
        icono: Icons.directions_car_outlined,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VehiculosScreen()),
        ),
      ),
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
