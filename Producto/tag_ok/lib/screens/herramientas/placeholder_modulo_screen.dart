import 'package:flutter/material.dart';
import 'package:tag_ok/theme/app_colors.dart';

/// Placeholder visual sin lógica para módulos que todavía no se
/// implementan (Combustible, Estacionamiento, Beneficios, Mantenciones).
/// Solo deja el acceso de navegación listo — cada uno se reemplaza por su
/// pantalla real en el Sprint que le corresponde.
class PlaceholderModuloScreen extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String sprintEstimado;

  const PlaceholderModuloScreen({
    super.key,
    required this.titulo,
    required this.icono,
    required this.sprintEstimado,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        title: Text(titulo, style: const TextStyle(color: AppColors.texto)),
        iconTheme: const IconThemeData(color: AppColors.texto),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 72, color: AppColors.textoSecundario.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: const TextStyle(color: AppColors.texto, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Disponible en $sprintEstimado',
              style: const TextStyle(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}
