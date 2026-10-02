import 'package:flutter/material.dart';
import 'procesando_ia_mantenimiento_screen.dart';

class RegistrarMantenimientoIaScreen extends StatefulWidget {
  const RegistrarMantenimientoIaScreen({super.key});

  @override
  State<RegistrarMantenimientoIaScreen> createState() =>
      _RegistrarMantenimientoIaScreenState();
}

class _RegistrarMantenimientoIaScreenState
    extends State<RegistrarMantenimientoIaScreen> {
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textMain),
        title: const Text(
          'Registrar con IA',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _cabecera(),

            const SizedBox(height: 24),

            const Text(
              'Comprobante de mantención',
              style: TextStyle(
                color: textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Sube una boleta o factura del servicio realizado.',
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 14),

            _zonaCarga(),

            const SizedBox(height: 18),

            _informacionIa(),

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                // Por ahora solo diseño.
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ProcesandoIaMantenimientoScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Analizar con IA',
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

            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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
        color: const Color(0xFF8B5CF6).withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(
            icon: Icons.auto_awesome_rounded,
            color: Color(0xFF8B5CF6),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro inteligente',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'La IA podrá extraer la información de tu boleta o factura para facilitar el registro.',
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
  // ZONA DE CARGA
  // ================================================================

  Widget _zonaCarga() {
    return InkWell(
      // Selección real del archivo se implementará después.
      onTap: () {
        _mostrarAviso();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 38,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file_outlined,
                color: Color(0xFFA5B4FC),
                size: 31,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Seleccionar comprobante',
              style: TextStyle(
                color: textMain,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Sube una foto, boleta o factura de la mantención.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'JPG · PNG · PDF',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // INFORMACIÓN SOBRE LA IA
  // ================================================================

  Widget _informacionIa() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF60A5FA),
                size: 20,
              ),
              SizedBox(width: 9),
              Text(
                '¿Qué información se detectará?',
                style: TextStyle(
                  color: textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          SizedBox(height: 14),

          _DetectionRow(text: 'Taller o proveedor'),
          _DetectionRow(text: 'Fecha del servicio'),
          _DetectionRow(text: 'Servicios realizados'),
          _DetectionRow(text: 'Repuestos o piezas'),
          _DetectionRow(text: 'Kilometraje'),
          _DetectionRow(text: 'Monto total'),
          _DetectionRow(text: 'Tipo de mantención'),
        ],
      ),
    );
  }

  void _mostrarAviso() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La selección y análisis del archivo se conectará en la etapa de integración.',
        ),
      ),
    );
  }
}

// ==================================================================
// FILA DE INFORMACIÓN
// ==================================================================

class _DetectionRow extends StatelessWidget {
  final String text;

  const _DetectionRow({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF8B5CF6),
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _RegistrarMantenimientoIaScreenState.textMuted,
                fontSize: 12,
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