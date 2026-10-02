import 'package:flutter/material.dart';

import 'registrar_mantenimiento_screen.dart';

class HistorialMantenimientosScreen extends StatefulWidget {
  const HistorialMantenimientosScreen({super.key});

  @override
  State<HistorialMantenimientosScreen> createState() =>
      _HistorialMantenimientosScreenState();
}

class _HistorialMantenimientosScreenState
    extends State<HistorialMantenimientosScreen> {
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF334155);

  String _vehiculoSeleccionado = 'Todos los vehículos';
  String _tipoSeleccionado = 'Todos los tipos';

  final List<String> _vehiculos = const [
    'Todos los vehículos',
  ];

  final List<String> _tipos = const [
    'Todos los tipos',
    'Cambio de aceite',
    'Revisión general',
    'Cambio de filtros',
    'Frenos',
    'Neumáticos',
    'Alineación y balanceo',
    'Batería',
    'Sistema eléctrico',
    'Motor',
    'Preventiva',
    'Otra',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: textMain,
        ),
        title: const Text(
          'Historial de mantenciones',
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
              'Filtrar historial',
              style: TextStyle(
                color: textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            _selectorVehiculo(),

            const SizedBox(height: 10),

            _selectorTipo(),

            const SizedBox(height: 26),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mantenciones realizadas',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '0 registros',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _estadoVacio(),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // CABECERA
  // ================================================================

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
            icon: Icons.history_rounded,
            color: Color(0xFF3B82F6),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historial de tu vehículo',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Aquí podrás revisar las mantenciones y servicios realizados a tus vehículos.',
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

  // ================================================================
  // FILTRO VEHÍCULO
  // ================================================================

  Widget _selectorVehiculo() {
    return DropdownButtonFormField<String>(
      value: _vehiculoSeleccionado,
      dropdownColor: surfaceColor,
      iconEnabledColor: textMuted,
      style: const TextStyle(
        color: textMain,
        fontSize: 13,
      ),
      decoration: _decoracionFiltro(
        label: 'Vehículo',
        icon: Icons.directions_car_outlined,
      ),
      items: _vehiculos
          .map(
            (vehiculo) => DropdownMenuItem<String>(
              value: vehiculo,
              child: Text(vehiculo),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _vehiculoSeleccionado = value;
        });
      },
    );
  }

  // ================================================================
  // FILTRO TIPO
  // ================================================================

  Widget _selectorTipo() {
    return DropdownButtonFormField<String>(
      value: _tipoSeleccionado,
      dropdownColor: surfaceColor,
      iconEnabledColor: textMuted,
      style: const TextStyle(
        color: textMain,
        fontSize: 13,
      ),
      decoration: _decoracionFiltro(
        label: 'Tipo de mantención',
        icon: Icons.build_outlined,
      ),
      items: _tipos
          .map(
            (tipo) => DropdownMenuItem<String>(
              value: tipo,
              child: Text(tipo),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _tipoSeleccionado = value;
        });
      },
    );
  }

  InputDecoration _decoracionFiltro({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: textMuted,
      ),
      prefixIcon: Icon(
        icon,
        color: textMuted,
        size: 21,
      ),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
      ),
    );
  }

  // ================================================================
  // ESTADO VACÍO
  // ================================================================

  Widget _estadoVacio() {
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
              color: primaryColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.car_repair_outlined,
              color: primaryColor,
              size: 32,
            ),
          ),

          const SizedBox(height: 17),

          const Text(
            'Aún no hay mantenciones registradas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Cuando registres una mantención, podrás encontrarla en este historial.',
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RegistrarMantenimientoScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Registrar mantención',
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