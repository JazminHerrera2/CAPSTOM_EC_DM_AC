import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/services/aviso_navegador_service.dart';
import '../data/services/notificacion_service.dart';
import 'audit_screen.dart';
import 'beneficios/beneficios_screen.dart';
import 'inicio_dashboard_screen.dart';
import 'live_map_screen.dart';
import 'mi_vehiculo/mi_vehiculo_screen.dart';
import 'mantenimiento/mantenimiento_screen.dart';

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
/// - "Vehículos" (Fase 1, `VehiculosScreen`) vuelve al bottom nav como
///   "Mis Vehículos", tal como estaba originalmente. El módulo "Mi
///   Vehículo" de Fase 2 se sacó de la navegación principal.
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
  bool _mostrandoMantenimiento = false;

  // Navigator propio del módulo de mantenciones: las pantallas que se abren
  // desde ahí (historial, próximas, registrar) se apilan dentro del cuerpo de
  // HomeScreen y así el menú inferior siempre queda visible.
  final GlobalKey<NavigatorState> _mantenimientoNavKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Deja programados en el celular los avisos de vencimiento del usuario.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      NotificacionService().sincronizarDispositivo(uid);
      // En web: avisos del navegador mientras la app esté abierta.
      AvisoNavegadorService.instance.iniciar(uid);
    }
  }

  @override
  void dispose() {
    AvisoNavegadorService.instance.detener();
    super.dispose();
  }

  final Color bgColor = const Color(0xFFF1F5F9);
  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color navBgColor = Colors.white;
  final Color textMuted = const Color(0xFF64748B);

  /// Abre Mantenciones SIEMPRE en su página principal. Su navegador propio
  /// sigue vivo mientras se está en otra pestaña, así que si se había dejado un
  /// detalle abierto (de una mantención, del historial, etc.) se cierran todas
  /// las pantallas apiladas antes de mostrarlo.
  void _abrirMantenciones() {
    _mantenimientoNavKey.currentState?.popUntil((ruta) => ruta.isFirst);
    setState(() {
      _mostrandoMantenimiento = true;
      _mostrandoMapa = false;
    });
  }

  // Mantenciones se abre desde el Inicio, así que al salir se vuelve a él.
  void _volverAlInicio() {
    setState(() {
      _selectedIndex = 0;
      _mostrandoMapa = false;
      _mostrandoMantenimiento = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _mostrandoMapa = false;
      _mostrandoMantenimiento = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // En mantenciones, "atrás" cierra la pantalla abierta y, desde la
      // principal, vuelve a Herramientas en vez de salir de la app.
      canPop: !_mostrandoMantenimiento,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _mantenimientoNavKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else {
          _volverAlInicio();
        }
      },
      child: Scaffold(
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
              offstage: _mostrandoMapa || _mostrandoMantenimiento,
              child: _buildBodyTab(),
            ),

            Offstage(
              offstage: !_mostrandoMapa,
              child: const LiveMapScreen(),
            ),

            Offstage(
              offstage: !_mostrandoMantenimiento,
              child: Navigator(
                key: _mantenimientoNavKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => MantenimientoScreen(
                    onVolver: _volverAlInicio,
                    onIrAAuditoria: () => _onItemTapped(1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Botón central: abre el mapa en tiempo real. Va en el centro de la barra,
      // dentro de un hueco curvo: la barra rodea al círculo y moldea su silueta.
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
          onPressed: () {
            setState(() {
              _mostrandoMapa = true;
              _mostrandoMantenimiento = false;
            });
          },
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
      // Centrado en la barra pero más abajo que el centerDocked normal: el
      // círculo queda más metido en la barra y el hueco curvo traza su silueta.
      floatingActionButtonLocation: const _CentroDockedMasAbajo(18),

      // Barra blanca con el "hueco" curvo en el medio; el contorno gris lo da la
      // sombra, que sigue la forma del hueco. Íconos grises; el azul marca la
      // pestaña seleccionada.
      bottomNavigationBar: BottomAppBar(
        color: navBgColor,
        elevation: 10,
        shadowColor: const Color(0xFF94A3B8),
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 70,
          // Las cuatro pestañas se reparten el ancho; el hueco del centro es más
          // ancho que el botón del mapa para que Auditoría y Vehículos no queden
          // pegados a él.
          child: Row(
            children: [
              Expanded(child: _buildNavIcon(Icons.dashboard_outlined, 0, 'Inicio')),
              Expanded(child: _buildNavIcon(Icons.receipt_long_outlined, 1, 'Auditoría')),

              const SizedBox(width: 104), // Espacio para el botón central

              Expanded(child: _buildNavIcon(Icons.directions_car_outlined, 2, 'Vehículos')),
              Expanded(child: _buildNavIcon(Icons.card_giftcard_outlined, 3, 'Beneficios')),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, String label) {
    // Mientras se muestra el mapa (botón central) ningún ítem del nav
    // queda marcado, ya que el mapa no es una pestaña más.
    final isSelected = !_mostrandoMapa && _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
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
        return InicioDashboardScreen(
          onIrAVehiculos: () => _onItemTapped(2),
          onIrAAuditoria: () => _onItemTapped(1),
          onIrABeneficios: () => _onItemTapped(3),
          onAbrirMantenciones: _abrirMantenciones,
        );
      case 1:
        return const AuditScreen();
      case 2:
        return const MiVehiculoScreen();
      case 3:
        return const BeneficiosScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Igual que [FloatingActionButtonLocation.centerDocked] (centrado, apoyado en
/// el borde superior de la barra inferior) pero [bajada] píxeles más abajo. El
/// hueco curvo de la barra se calcula con la posición real del botón, así que
/// sigue su silueta.
class _CentroDockedMasAbajo extends FloatingActionButtonLocation {
  final double bajada;

  const _CentroDockedMasAbajo(this.bajada);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final base = FloatingActionButtonLocation.centerDocked.getOffset(scaffoldGeometry);
    return Offset(base.dx, base.dy + bajada);
  }

  @override
  String toString() => 'centerDocked bajado $bajada px';
}
