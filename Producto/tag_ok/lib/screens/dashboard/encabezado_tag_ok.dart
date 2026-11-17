import 'package:flutter/material.dart';

import '../notificaciones/notificaciones_screen.dart';
import '../profile_screen.dart';
import 'logo_tag_ok.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/modo_tema.dart';

/// Encabezado común de las pestañas principales (Inicio, Auditoría, Vehículos
/// y Herramientas): logo TAG OK a la izquierda; campana de notificaciones y
/// avatar de perfil a la derecha. En el Inicio, además, el switch del modo
/// oscuro.
class EncabezadoTagOk extends StatelessWidget {
  /// Margen alrededor del encabezado. Cada pantalla lo ajusta a su propio
  /// espaciado lateral.
  final EdgeInsetsGeometry padding;

  /// Muestra el switch de modo oscuro (solo en el Inicio).
  final bool conSwitchModoOscuro;

  const EncabezadoTagOk({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
    this.conSwitchModoOscuro = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          const LogoTagOk(),
          const Spacer(),
          if (conSwitchModoOscuro) ...[
            const SwitchModoOscuro(),
            const SizedBox(width: 4),
          ],
          const CampanaNotificaciones(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.contenedorSuave,
              child: Icon(
                Icons.person_outline,
                color: AppColors.primario,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch con ícono de luna: activa o desactiva el modo oscuro de toda la app.
/// Apagado (modo claro) por defecto.
class SwitchModoOscuro extends StatelessWidget {
  const SwitchModoOscuro({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ModoTema.oscuro,
      builder: (context, oscuro, _) => Tooltip(
        message: oscuro ? 'Desactivar modo oscuro' : 'Activar modo oscuro',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              oscuro ? Icons.dark_mode : Icons.dark_mode_outlined,
              color: oscuro ? AppColors.primario : AppColors.textoSecundario,
              size: 20,
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: oscuro,
                onChanged: ModoTema.cambiar,
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppColors.sobrePrimario
                      : AppColors.textoSecundario,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppColors.primario
                      : AppColors.contenedorSuave,
                ),
                trackOutlineColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? Colors.transparent
                      : AppColors.borde,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
