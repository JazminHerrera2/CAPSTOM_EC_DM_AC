import 'package:flutter/material.dart';

/// Color asociado al estado general de un vehículo ("Todo al día", etc.).
/// Mismos colores que Mi Vehículo; vive acá para no tocar esas pantallas.
Color colorEstadoVehiculo(String estado) {
  switch (estado) {
    case 'Atención requerida':
      return Colors.redAccent;
    case 'Próximo vencimiento':
      return const Color(0xFFF97316);
    case 'Todo al día':
      return const Color(0xFF10B981);
    default:
      return const Color(0xFF64748B);
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

/// Chip con el estado de un vehículo, reutilizado en el carrusel del dashboard.
class EstadoVehiculoChip extends StatelessWidget {
  final String estado;

  const EstadoVehiculoChip({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoVehiculo(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoEstadoVehiculo(estado), color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              estado,
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
