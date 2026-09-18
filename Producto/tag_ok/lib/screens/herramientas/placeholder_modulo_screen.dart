import 'package:flutter/material.dart';

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
    const bgColor = Color(0xFF0F172A);
    const textMain = Color(0xFFF8FAFC);
    const textMuted = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(titulo, style: const TextStyle(color: textMain)),
        iconTheme: const IconThemeData(color: textMain),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 72, color: textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: const TextStyle(color: textMain, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Disponible en $sprintEstimado',
              style: const TextStyle(color: textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
