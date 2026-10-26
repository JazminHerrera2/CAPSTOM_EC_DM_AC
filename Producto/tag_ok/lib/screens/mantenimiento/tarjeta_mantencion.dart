import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';

/// Formatea un entero con separador de miles (72450 -> 72.450).
String formatoMiles(int valor) {
  final texto = valor.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return valor < 0 ? '-$buffer' : buffer.toString();
}

String formatoFecha(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  return '$d/$m/${fecha.year}';
}

/// Tarjeta de una mantención, para las listas de Historial y Próximas.
class TarjetaMantencion extends StatelessWidget {
  final MantencionModel mantencion;

  const TarjetaMantencion({super.key, required this.mantencion});

  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final m = mantencion;
    final programada = m.estado == EstadoMantencion.programada;
    final color =
        programada ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6);

    final lineas = <String>[
      if (programada) ...[
        if (m.proximaFecha != null) 'Fecha: ${formatoFecha(m.proximaFecha!)}',
        if (m.proximoKilometraje != null)
          'Kilometraje: ${formatoMiles(m.proximoKilometraje!)} km',
      ] else ...[
        [
          if (m.fecha != null) formatoFecha(m.fecha!),
          if (m.kilometraje != null) '${formatoMiles(m.kilometraje!)} km',
        ].join(' · '),
        if ((m.taller ?? '').isNotEmpty) m.taller!,
        if (m.costo != null) '\$${formatoMiles(m.costo!)}',
        if ((m.descripcion ?? '').isNotEmpty) m.descripcion!,
        // Documento asociado del historial (RF-010): solo la referencia.
        m.referenciaComprobante ?? 'Sin comprobante',
      ],
    ].where((l) => l.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              programada
                  ? Icons.event_available_outlined
                  : Icons.build_circle_outlined,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombreTipo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final linea in lineas) ...[
                  const SizedBox(height: 4),
                  Text(
                    linea,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
