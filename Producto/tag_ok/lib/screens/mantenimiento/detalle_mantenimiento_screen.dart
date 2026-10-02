import 'package:flutter/material.dart';

class DetalleMantenimientoScreen extends StatelessWidget {
  const DetalleMantenimientoScreen({super.key});

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
          'Detalle de mantención',
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

            _tituloSeccion('Información general'),

            const SizedBox(height: 10),

            _contenedorInformacion(
              children: [
                _filaInformacion(
                  icon: Icons.build_outlined,
                  titulo: 'Tipo de mantención',
                ),
                _separador(),
                _filaInformacion(
                  icon: Icons.directions_car_outlined,
                  titulo: 'Vehículo',
                ),
                _separador(),
                _filaInformacion(
                  icon: Icons.calendar_today_outlined,
                  titulo: 'Fecha',
                ),
                _separador(),
                _filaInformacion(
                  icon: Icons.speed_outlined,
                  titulo: 'Kilometraje',
                ),
              ],
            ),

            const SizedBox(height: 22),

            _tituloSeccion('Servicio'),

            const SizedBox(height: 10),

            _contenedorInformacion(
              children: [
                _filaInformacion(
                  icon: Icons.storefront_outlined,
                  titulo: 'Taller',
                ),
                _separador(),
                _filaInformacion(
                  icon: Icons.attach_money_rounded,
                  titulo: 'Costo',
                ),
              ],
            ),

            const SizedBox(height: 22),

            _tituloSeccion('Detalles'),

            const SizedBox(height: 10),

            _campoDetalle(
              icon: Icons.description_outlined,
              titulo: 'Descripción',
              textoVacio: 'Sin descripción registrada',
            ),

            const SizedBox(height: 10),

            _campoDetalle(
              icon: Icons.notes_rounded,
              titulo: 'Observaciones',
              textoVacio: 'Sin observaciones registradas',
            ),

            const SizedBox(height: 22),

            _tituloSeccion('Comprobante'),

            const SizedBox(height: 10),

            _comprobanteVacio(),

            const SizedBox(height: 26),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    // Solo diseño.
                    onPressed: () {},
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 19,
                    ),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textMain,
                      minimumSize: const Size(0, 50),
                      side: const BorderSide(
                        color: borderColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: OutlinedButton.icon(
                    // Solo diseño.
                    onPressed: () {},
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                    ),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF87171),
                      minimumSize: const Size(0, 50),
                      side: BorderSide(
                        color:
                            const Color(0xFFF87171).withOpacity(0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
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
        color: primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.25),
        ),
      ),
      child: const Row(
        children: [
          _IconBox(
            icon: Icons.car_repair_outlined,
            color: primaryColor,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mantención registrada',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Consulta toda la información asociada a esta mantención.',
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

  // ================================================================
  // TÍTULO
  // ================================================================

  Widget _tituloSeccion(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        color: textMain,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ================================================================
  // CONTENEDOR DE INFORMACIÓN
  // ================================================================

  Widget _contenedorInformacion({
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _filaInformacion({
    required IconData icon,
    required String titulo,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFA5B4FC),
              size: 19,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  '—',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _separador() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }

  // ================================================================
  // DESCRIPCIÓN / OBSERVACIONES
  // ================================================================

  Widget _campoDetalle({
    required IconData icon,
    required String titulo,
    required String textoVacio,
  }) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: textMuted,
            size: 21,
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  textoVacio,
                  style: const TextStyle(
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

  // ================================================================
  // COMPROBANTE
  // ================================================================

  Widget _comprobanteVacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: const Row(
        children: [
          _IconBox(
            icon: Icons.receipt_long_outlined,
            color: Color(0xFF64748B),
          ),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sin comprobante asociado',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Esta mantención no tiene un documento adjunto.',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
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