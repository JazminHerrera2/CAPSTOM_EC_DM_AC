import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import 'detalle_mantenimiento_screen.dart';

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

/// Tarjeta de una mantención, para las listas de Historial y Próximas. Las
/// realizadas (historial) se abren al tocarlas y muestran su detalle; las
/// programadas no tienen detalle y, si se indica [onEliminar], llevan un botón
/// de eliminar a su derecha.
class TarjetaMantencion extends StatelessWidget {
  final MantencionModel mantencion;

  /// Si viene, se muestra un botón de eliminar al lado de la tarjeta.
  final VoidCallback? onEliminar;

  const TarjetaMantencion({
    super.key,
    required this.mantencion,
    this.onEliminar,
  });

  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _iconoColor = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final m = mantencion;
    final programada = m.estado == EstadoMantencion.programada;

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

    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Solo las realizadas (historial) tienen detalle.
        onTap: programada
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalleMantenimientoScreen(mantencion: m),
                  ),
                ),
        child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solo el ícono, en azul y sin recuadro de color de fondo.
          SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              programada
                  ? Icons.event_available_outlined
                  : Icons.build_circle_outlined,
              color: _iconoColor,
              size: 28,
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
          if (onEliminar != null)
            IconButton(
              tooltip: 'Eliminar programación',
              visualDensity: VisualDensity.compact,
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48)),
            )
          else if (!programada)
            const Icon(Icons.chevron_right, color: _textMuted),
        ],
      ),
    ),
      ),
    );
  }
}
