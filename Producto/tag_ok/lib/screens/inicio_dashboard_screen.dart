import 'package:flutter/material.dart';

/// "Inicio" — plantilla visual del dashboard (scaffold), sin lógica ni
/// conexión a datos reales. Reemplaza el mapa en tiempo real que vivía
/// antes en esta pestaña (ahora en `LiveMapScreen`, accesible desde el
/// botón central flotante). Reestructuración de navegación que reemplaza
/// la decisión de docs/06-decision-navegacion.md.
///
/// Todas las cards muestran datos de ejemplo hardcodeados a propósito —
/// solo es la estructura visual, la conexión a datos reales queda para un
/// Sprint futuro cuando se defina el dashboard "Mi Auto" (Sprint 5).
class InicioDashboardScreen extends StatelessWidget {
  const InicioDashboardScreen({super.key});

  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Hola, Conductor',
              style: TextStyle(color: _textMain, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Este es un resumen de ejemplo',
              style: TextStyle(color: _textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.attach_money,
                    titulo: 'Gasto del mes',
                    valor: '\$0',
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.build_outlined,
                    titulo: 'Próxima mantención',
                    valor: 'Sin datos',
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.directions_car_outlined,
                    titulo: 'Vehículo principal',
                    valor: 'Sin asignar',
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.description_outlined,
                    titulo: 'Documentos por vencer',
                    valor: '0',
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(
                'Espacio reservado — próximas alertas / actividad reciente',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String valor;
  final Color color;

  const _DashboardCard({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InicioDashboardScreen._surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: TextStyle(color: InicioDashboardScreen._textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              color: InicioDashboardScreen._textMain,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
