import 'package:flutter/material.dart';

class RevisarIaMantenimientoScreen extends StatefulWidget {
  const RevisarIaMantenimientoScreen({super.key});

  @override
  State<RevisarIaMantenimientoScreen> createState() =>
      _RevisarIaMantenimientoScreenState();
}

class _RevisarIaMantenimientoScreenState
    extends State<RevisarIaMantenimientoScreen> {
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
          'Revisar información',
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

            _sectionTitle('Información de la mantención'),
            const SizedBox(height: 12),

            _dropdownField(
              label: 'Vehículo',
              hint: 'Seleccionar vehículo',
              icon: Icons.directions_car_outlined,
            ),

            const SizedBox(height: 14),

            _dropdownField(
              label: 'Tipo de mantención',
              hint: 'Seleccionar tipo',
              icon: Icons.build_outlined,
            ),

            const SizedBox(height: 14),

            _textField(
              label: 'Fecha',
              hint: 'Seleccionar fecha',
              icon: Icons.calendar_today_outlined,
            ),

            const SizedBox(height: 14),

            _textField(
              label: 'Kilometraje',
              hint: 'Ingresar kilometraje',
              icon: Icons.speed_outlined,
            ),

            const SizedBox(height: 24),

            _sectionTitle('Servicio'),
            const SizedBox(height: 12),

            _textField(
              label: 'Taller o proveedor',
              hint: 'Nombre del taller',
              icon: Icons.store_outlined,
            ),

            const SizedBox(height: 14),

            _textField(
              label: 'Monto total',
              hint: '\$0',
              icon: Icons.payments_outlined,
            ),

            const SizedBox(height: 24),

            _sectionTitle('Información detectada'),
            const SizedBox(height: 12),

            _largeField(
              label: 'Servicios realizados',
              hint: 'Servicios detectados en el comprobante',
            ),

            const SizedBox(height: 14),

            _largeField(
              label: 'Repuestos o piezas',
              hint: 'Repuestos detectados en el comprobante',
            ),

            const SizedBox(height: 14),

            _largeField(
              label: 'Observaciones',
              hint: 'Agregar observaciones',
            ),

            const SizedBox(height: 26),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.20),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF60A5FA),
                    size: 19,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Revisa que la información sea correcta antes de confirmar el registro.',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                // Guardado real se implementará en integración.
                onPressed: () {},
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                ),
                label: const Text(
                  'Confirmar mantención',
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

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
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

  Widget _cabecera() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.22),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFA78BFA),
            size: 25,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información detectada',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Puedes revisar y corregir los datos antes de continuar.',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: textMain,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _textField({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 7),
        TextField(
          style: const TextStyle(
            color: textMain,
            fontSize: 13,
          ),
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
          ),
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 7),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: textMuted,
                size: 19,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _largeField({
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 7),
        TextField(
          maxLines: 3,
          style: const TextStyle(
            color: textMain,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: textMuted,
              fontSize: 12,
            ),
            filled: true,
            fillColor: surfaceColor,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                color: primaryColor,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: textMain,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: textMuted,
        fontSize: 12,
      ),
      prefixIcon: Icon(
        icon,
        color: textMuted,
        size: 19,
      ),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.4,
        ),
      ),
    );
  }
}