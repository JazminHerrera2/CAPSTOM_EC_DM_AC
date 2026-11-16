import 'package:flutter/material.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

/// Color asociado al estado general de un vehículo ("Todo al día", etc.).
/// Mismos colores que Mi Vehículo; vive acá para no tocar esas pantallas.
Color colorEstadoVehiculo(String estado) {
  switch (estado) {
    case 'Atención requerida':
      return AppColors.error;
    case 'Próximo vencimiento':
      return AppColors.alerta;
    case 'Todo al día':
      return AppColors.exito;
    default:
      return AppColors.textoSecundario;
  }
}

/// Fondo del chip de estado: el tono suave que acompaña a [colorEstadoVehiculo].
Color fondoEstadoVehiculo(String estado) {
  switch (estado) {
    case 'Atención requerida':
      return AppColors.errorFondo;
    case 'Próximo vencimiento':
      return AppColors.advertenciaFondo;
    case 'Todo al día':
      return AppColors.exitoFondo;
    default:
      return AppColors.contenedorSuave;
  }
}

IconData iconoEstadoVehiculo(String estado) {
  switch (estado) {
    case 'Atención requerida':
      return Icons.error_outline;
    case 'Próximo vencimiento':
      return Icons.schedule;
    case 'Todo al día':
      return Icons.check_circle_outline;
    default:
      return Icons.help_outline;
  }
}

/// Versión corta del estado, para chips compactos ("Al día", "Por vencer"…).
String etiquetaCortaEstadoVehiculo(String estado) {
  switch (estado) {
    case 'Atención requerida':
      return 'Atención';
    case 'Próximo vencimiento':
      return 'Por vencer';
    case 'Todo al día':
      return 'Al día';
    default:
      return estado;
  }
}

/// Chip con el estado de un vehículo, reutilizado en el carrusel del dashboard.
/// Con [compacto] muestra la etiqueta corta ("Al día").
class EstadoVehiculoChip extends StatelessWidget {
  final String estado;
  final bool compacto;

  const EstadoVehiculoChip({
    super.key,
    required this.estado,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoVehiculo(estado);
    final texto = compacto ? etiquetaCortaEstadoVehiculo(estado) : estado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondoEstadoVehiculo(estado),
        borderRadius: BorderRadius.circular(AppRadios.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoEstadoVehiculo(estado), color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
