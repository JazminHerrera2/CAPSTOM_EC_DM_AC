import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../dialogo_cerrar_sesion.dart';
import '../login_screen.dart';
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
  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

  Future<void> _cerrarSesion() async {
    if (!await confirmarCerrarSesion(context)) return;

    await FirebaseAuth.instance.signOut();
    // Vuelve al inicio de sesión eliminando el historial de pantallas.
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
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
        child: Column(
          children: [
            Expanded(
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

            // Cerrar sesión, fijo al pie de la pantalla.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _cerrarSesion,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
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
