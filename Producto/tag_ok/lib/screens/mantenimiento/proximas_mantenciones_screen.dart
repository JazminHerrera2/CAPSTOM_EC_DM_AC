import 'package:flutter/material.dart';

class ProximasMantenimientosScreen extends StatelessWidget {
  const ProximasMantenimientosScreen({super.key});

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
        iconTheme: const IconThemeData(color: textMain),
        title: const Text(
          'Próximas mantenciones',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            _cabecera(),

            const SizedBox(height: 24),

            const Text(
              'Mantenciones programadas',
              style: TextStyle(
                color: textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            _estadoVacio(context),
          ],
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(
            icon: Icons.calendar_month_outlined,
            color: Color(0xFFF59E0B),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planifica el cuidado de tu vehículo',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Programa tus próximas mantenciones por fecha, kilometraje o ambos.',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: Color(0xFFF59E0B),
              size: 32,
            ),
          ),

          const SizedBox(height: 17),

          const Text(
            'No tienes mantenciones programadas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Programa tu próxima mantención para llevar un mejor control del cuidado de tu vehículo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 22),

          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                _mostrarProgramarMantencion(context);
              },
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Programar mantención',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarProgramarMantencion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return const _ProgramarMantencionSheet();
      },
    );
  }
}

// ==================================================================
// VENTANA PARA PROGRAMAR MANTENCIÓN
// ==================================================================

class _ProgramarMantencionSheet extends StatefulWidget {
  const _ProgramarMantencionSheet();

  @override
  State<_ProgramarMantencionSheet> createState() =>
      _ProgramarMantencionSheetState();
}

class _ProgramarMantencionSheetState
    extends State<_ProgramarMantencionSheet> {
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF334155);

  String _programarPor = 'Fecha';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Programar mantención',
              style: TextStyle(
                color: textMain,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Define cuándo debería realizarse la próxima mantención.',
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 22),

            _campoVisual(
              label: 'Vehículo',
              hint: 'Seleccionar vehículo',
              icon: Icons.directions_car_outlined,
            ),

            const SizedBox(height: 12),

            _campoVisual(
              label: 'Tipo de mantención',
              hint: 'Seleccionar tipo',
              icon: Icons.build_outlined,
            ),

            const SizedBox(height: 22),

            const Text(
              'Programar por',
              style: TextStyle(
                color: textMain,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: _opcion('Fecha')),
                const SizedBox(width: 8),
                Expanded(child: _opcion('Kilometraje')),
                const SizedBox(width: 8),
                Expanded(child: _opcion('Ambos')),
              ],
            ),

            const SizedBox(height: 18),

            if (_programarPor == 'Fecha' ||
                _programarPor == 'Ambos')
              _campoVisual(
                label: 'Próxima fecha',
                hint: 'Seleccionar fecha',
                icon: Icons.calendar_today_outlined,
              ),

            if (_programarPor == 'Ambos')
              const SizedBox(height: 12),

            if (_programarPor == 'Kilometraje' ||
                _programarPor == 'Ambos')
              _campoVisual(
                label: 'Próximo kilometraje',
                hint: 'Ej: 80.000 km',
                icon: Icons.speed_outlined,
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                // Diseño solamente.
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
                label: const Text(
                  'Programar mantención',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcion(String texto) {
    final seleccionado = _programarPor == texto;

    return InkWell(
      onTap: () {
        setState(() {
          _programarPor = texto;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: seleccionado
              ? primaryColor.withOpacity(0.16)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? primaryColor
                : borderColor,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: seleccionado
                ? const Color(0xFFA5B4FC)
                : textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _campoVisual({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: textMuted,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: textMuted,
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// ICONO
// ==================================================================

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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: color,
        size: 23,
      ),
    );
  }
}