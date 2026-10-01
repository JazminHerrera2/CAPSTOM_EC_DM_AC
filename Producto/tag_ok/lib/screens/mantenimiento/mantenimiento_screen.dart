import 'package:flutter/material.dart';
import 'registrar_mantenimiento_screen.dart';
import 'historial_mantenimientos_screen.dart';
import 'proximas_mantenciones_screen.dart';
import 'registro_ia_mantenimiento_screen.dart';


class MantenimientoScreen extends StatelessWidget {
  const MantenimientoScreen({super.key});

  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'Mantenciones',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: textMain),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            // Próxima mantención
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconBox(
                        icon: Icons.event_available_outlined,
                        color: Color(0xFFF59E0B),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Próxima mantención',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Sin mantenciones programadas',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Programa una mantención para recibir recordatorios.',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Acciones rápidas',
              style: TextStyle(
                color: textMain,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                          icon: Icons.add_circle_outline,
                          title: 'Registrar',
                          subtitle: 'Nueva mantención',
                          color: primaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RegistrarMantenimientoScreen(),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Registrar con IA',
                    subtitle: 'Boleta o factura',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                        Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const RegistrarMantenimientoIaScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Mi mantenimiento',
              style: TextStyle(
                color: textMain,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            _MenuCard(
              icon: Icons.history_rounded,
              title: 'Historial de mantenciones',
              subtitle: 'Revisa los servicios realizados',
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const HistorialMantenimientosScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            _MenuCard(
              icon: Icons.calendar_month_outlined,
              title: 'Próximas mantenciones',
              subtitle: 'Fechas, kilometraje y recordatorios',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ProximasMantenimientosScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Historial resumido
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Actividad reciente',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Próximamente: historial completo.
                  },
                  child: const Text(
                    'Ver todo',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 30,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    color: textMuted,
                    size: 42,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Aún no hay mantenciones',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Tus mantenciones realizadas aparecerán aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// TARJETA DE ACCIÓN RÁPIDA
// ================================================================

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MantenimientoScreen.surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(
                icon: icon,
                color: color,
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  color: MantenimientoScreen.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: MantenimientoScreen.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// OPCIÓN DEL MENÚ
// ================================================================

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MantenimientoScreen.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _IconBox(
                icon: icon,
                color: color,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MantenimientoScreen.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: MantenimientoScreen.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MantenimientoScreen.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// CONTENEDOR DE ICONOS
// ================================================================

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 22,
      ),
    );
  }
}