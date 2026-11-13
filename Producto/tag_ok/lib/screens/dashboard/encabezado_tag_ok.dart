import 'package:flutter/material.dart';

import '../notificaciones/notificaciones_screen.dart';
import '../profile_screen.dart';
import 'logo_tag_ok.dart';
import 'package:tag_ok/theme/app_colors.dart';

/// Encabezado común de las pestañas principales (Inicio, Auditoría, Vehículos
/// y Herramientas): logo TAG OK a la izquierda; campana de notificaciones y
/// avatar de perfil a la derecha.
class EncabezadoTagOk extends StatelessWidget {
  /// Margen alrededor del encabezado. Cada pantalla lo ajusta a su propio
  /// espaciado lateral.
  final EdgeInsetsGeometry padding;

  const EncabezadoTagOk({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          const LogoTagOk(),
          const Spacer(),
          const CampanaNotificaciones(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const CircleAvatar(
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
