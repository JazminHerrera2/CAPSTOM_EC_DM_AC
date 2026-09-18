import 'package:flutter/material.dart';
import 'audit_screen.dart';
import 'herramientas/herramientas_hub_screen.dart';
import 'inicio_dashboard_screen.dart';
import 'live_map_screen.dart';
import 'mi_vehiculo/mi_vehiculo_screen.dart';

/// Contenedor de navegación principal (bottom nav + botón central).
///
/// Reestructuración de navegación que reemplaza la decisión de
/// docs/06-decision-navegacion.md:
/// - "Inicio" ahora muestra un dashboard de plantilla (`InicioDashboardScreen`),
///   sin lógica ni datos reales. El mapa en tiempo real que vivía acá se
///   movió tal cual a `LiveMapScreen`.
/// - El botón central flotante abre `LiveMapScreen` (antes abría
///   directamente "Configurar viaje" — ese flujo ahora vive dentro del
///   mapa, con su propio botón).
/// - "Vehículos" (Fase 1, `VehiculosScreen`) se sacó del bottom nav — ahora
///   se accede desde el hub de "Herramientas" como "Categoría de vehículo
///   (TAG)". Este slot del bottom nav ahora es "Mi Vehículo"
///   (`MiVehiculoScreen`, módulo de Fase 2).
/// - "Perfil" se renombró a "Herramientas" y ahora abre un hub de accesos
///   en vez de ir directo a la pantalla de perfil.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // El mapa no es una pestaña más del bottom nav (se abre desde el botón
  // central), pero debe mostrarse dentro del mismo Scaffold para que el
  // menú inferior nunca desaparezca — por eso es un flag aparte en vez de
  // un Navigator.push a una pantalla completa.
  bool _mostrandoMapa = false;

  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _mostrandoMapa = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      // LiveMapScreen se mantiene siempre montado (Offstage) en vez de
      // construirse/destruirse con el resto de las pestañas: en Fase 1 el
      // GPS y la detección de cruces de peaje vivían en el estado de
      // HomeScreen y corrían en segundo plano sin importar qué pestaña se
      // viera. Si LiveMapScreen se destruyera al cambiar de pestaña
      // (dispose() cancela la suscripción GPS), el tracking se detendría
      // en medio de un viaje — justamente lo que NO debe pasar. Las otras
      // 4 pestañas sí se reconstruyen normalmente al cambiar, igual que en
      // Fase 1 (nunca fueron persistentes).
      body: SafeArea(
        child: Stack(
          children: [
            Offstage(
              offstage: _mostrandoMapa,
              child: _buildBodyTab(),
            ),
            Offstage(
              offstage: !_mostrandoMapa,
              child: const LiveMapScreen(),
            ),
          ],
        ),
      ),

      // Botón central flotante: abre el mapa en tiempo real.
      floatingActionButton: Container(
        height: 72,
        width: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => setState(() => _mostrandoMapa = true),
          backgroundColor: primaryColor,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.map_outlined,
            size: 34,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Menú de navegación inferior con el "hueco" en el medio
      bottomNavigationBar: BottomAppBar(
        color: navBgColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavIcon(Icons.dashboard_outlined, 0, 'Inicio'),
              _buildNavIcon(Icons.receipt_long_outlined, 1, 'Auditoría'),

              const SizedBox(width: 50), // Espacio para el botón central flotante

              _buildNavIcon(Icons.directions_car_outlined, 2, 'Mi Vehículo'),
              _buildNavIcon(Icons.build_outlined, 3, 'Herramientas'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : textMuted,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyTab() {
    switch (_selectedIndex) {
      case 0:
        return const InicioDashboardScreen();
      case 1:
        return const AuditScreen();
      case 2:
        return const MiVehiculoScreen();
      case 3:
        return const HerramientasHubScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
