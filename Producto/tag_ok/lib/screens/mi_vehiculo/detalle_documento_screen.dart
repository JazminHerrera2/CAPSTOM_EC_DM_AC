import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/documento_vehicular_model.dart';

class DetalleDocumentoScreen extends StatelessWidget {
  final DocumentoVehicularModel documento;
  final String patenteVehiculo;

  const DetalleDocumentoScreen({
    super.key,
    required this.documento,
    required this.patenteVehiculo,
  });

  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF27364D);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color primaryColor = Color(0xFF4F46E5);

  // ------------------------------------------------------------
  // ESTADO
  // ------------------------------------------------------------

  String _estadoDocumento() {
    final fecha = documento.fechaVencimiento;

    if (fecha == null) {
      return 'Sin vencimiento';
    }

    final ahora = DateTime.now();

    final hoy = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
    );

    final vencimiento = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
    );

    final dias = vencimiento.difference(hoy).inDays;

    if (dias < 0) {
      return 'Vencido';
    }

    if (dias <= 30) {
      return 'Próximo a vencer';
    }

    return 'Vigente';
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Vencido':
        return Colors.redAccent;

      case 'Próximo a vencer':
        return const Color(0xFFF59E0B);

      case 'Vigente':
        return const Color(0xFF10B981);

      default:
        return textMuted;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'Vencido':
        return Icons.error_outline;

      case 'Próximo a vencer':
        return Icons.schedule_outlined;

      case 'Vigente':
        return Icons.check_circle_outline;

      default:
        return Icons.info_outline;
    }
  }

  // ------------------------------------------------------------
  // FECHAS
  // ------------------------------------------------------------

  String _fecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin información';
    }

    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  // ------------------------------------------------------------
  // FILA DE INFORMACIÓN
  // ------------------------------------------------------------

  Widget _dato({
    required IconData icono,
    required String titulo,
    required String? valor,
  }) {
    final texto =
        valor == null || valor.trim().isEmpty
            ? 'Sin información'
            : valor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icono,
              color: primaryColor,
              size: 19,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  texto,
                  style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    final estado = _estadoDocumento();
    final colorEstado = _colorEstado(estado);

    return Scaffold(
      backgroundColor: bgColor,

      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: textMain,
        ),
        title: const Text(
          'Detalle del documento',
          style: TextStyle(
            color: textMain,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          10,
          20,
          35,
        ),
        children: [
          // ------------------------------------------------------
          // DOCUMENTO
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF334155),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: primaryColor,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  documento.tipoDocumento.etiqueta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  patenteVehiculo,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorEstado.withOpacity(0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconoEstado(estado),
                        color: colorEstado,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        estado,
                        style: TextStyle(
                          color: colorEstado,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // ------------------------------------------------------
          // INFORMACIÓN
          // ------------------------------------------------------

          const Text(
            'Información del documento',
            style: TextStyle(
              color: textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF334155),
              ),
            ),
            child: Column(
              children: [
                _dato(
                  icono: Icons.numbers_outlined,
                  titulo: 'Número de documento',
                  valor: documento.numero,
                ),

                const Divider(
                  color: Color(0xFF334155),
                  height: 1,
                ),

                _dato(
                  icono: Icons.event_available_outlined,
                  titulo: 'Fecha de emisión',
                  valor: _fecha(
                    documento.fechaEmision,
                  ),
                ),

                const Divider(
                  color: Color(0xFF334155),
                  height: 1,
                ),

                _dato(
                  icono: Icons.event_busy_outlined,
                  titulo: 'Fecha de vencimiento',
                  valor: _fecha(
                    documento.fechaVencimiento,
                  ),
                ),

                if (documento.compania != null &&
                    documento.compania!
                        .trim()
                        .isNotEmpty) ...[
                  const Divider(
                    color: Color(0xFF334155),
                    height: 1,
                  ),
                  _dato(
                    icono: Icons.business_outlined,
                    titulo: 'Compañía',
                    valor: documento.compania,
                  ),
                ],

                if (documento.numeroPoliza != null &&
                    documento.numeroPoliza!
                        .trim()
                        .isNotEmpty) ...[
                  const Divider(
                    color: Color(0xFF334155),
                    height: 1,
                  ),
                  _dato(
                    icono: Icons.shield_outlined,
                    titulo: 'Número de póliza',
                    valor: documento.numeroPoliza,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 26),

          // ------------------------------------------------------
          // REGISTRO
          // ------------------------------------------------------

          const Text(
            'Información del registro',
            style: TextStyle(
              color: textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF334155),
              ),
            ),
            child: Column(
              children: [
                _dato(
                  icono: documento.origenRegistro == 'manual'
                      ? Icons.edit_note_outlined
                      : Icons.auto_awesome_outlined,
                  titulo: 'Origen del registro',
                  valor: documento.origenRegistro == 'manual'
                      ? 'Ingreso manual'
                      : 'Procesado con IA',
                ),

                const Divider(
                  color: Color(0xFF334155),
                  height: 1,
                ),

                _dato(
                  icono: Icons.history_outlined,
                  titulo: 'Fecha de registro',
                  valor: _fecha(
                    documento.fechaRegistro,
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // ARCHIVO
          // ------------------------------------------------------

          if (documento.archivoPath != null &&
              documento.archivoPath!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(height: 26),

            const Text(
              'Archivo asociado',
              style: TextStyle(
                color: textMain,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF334155),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.attach_file,
                    color: primaryColor,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Documento original guardado',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF10B981),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}