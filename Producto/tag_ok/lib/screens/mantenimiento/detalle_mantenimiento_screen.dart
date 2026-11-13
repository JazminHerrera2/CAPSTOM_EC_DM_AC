import 'package:flutter/material.dart';

import '../../data/models/componente_mantencion_model.dart';
import '../../data/models/mantencion_model.dart';
import 'tarjeta_mantencion.dart';
import 'package:tag_ok/theme/app_colors.dart';

/// Detalle de una mantención: todos los datos que se guardaron al registrarla
/// o programarla. Se abre al tocar una tarjeta del historial o de las próximas.
class DetalleMantenimientoScreen extends StatelessWidget {
  final MantencionModel mantencion;

  const DetalleMantenimientoScreen({super.key, required this.mantencion});


  bool get _programada => mantencion.estado == EstadoMantencion.programada;

  /// Nombre legible de un componente revisado (los ids vienen de la lista).
  String _nombreComponente(String id) {
    for (final c in componentesPorDefecto) {
      if (c.id == id) return c.nombre;
    }
    final texto = id.replaceAll('_', ' ').trim();
    return texto.isEmpty ? id : texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final m = mantencion;
    final filas = <(IconData, String, String)>[
      if (m.fecha != null)
        (Icons.event_outlined, 'Fecha', formatoFecha(m.fecha!)),
      if (m.kilometraje != null)
        (Icons.speed_outlined, 'Kilometraje', '${formatoMiles(m.kilometraje!)} km'),
      if ((m.taller ?? '').trim().isNotEmpty)
        (Icons.storefront_outlined, 'Taller', m.taller!.trim()),
      if (m.costo != null)
        (Icons.payments_outlined, 'Costo', '\$${formatoMiles(m.costo!)}'),
      if (m.proximaFecha != null)
        (Icons.event_repeat_outlined, 'Próxima fecha', formatoFecha(m.proximaFecha!)),
      if (m.proximoKilometraje != null)
        (
          Icons.flag_outlined,
          'Próximo kilometraje',
          '${formatoMiles(m.proximoKilometraje!)} km'
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.texto),
        title: const Text(
          'Detalle de mantención',
          style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _cabecera(),

                if (filas.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _titulo('Información general'),
                  const SizedBox(height: 10),
                  _tarjeta(
                    Column(
                      children: [
                        for (var i = 0; i < filas.length; i++) ...[
                          if (i > 0) const Divider(height: 18, color: AppColors.fondo),
                          _fila(filas[i].$1, filas[i].$2, filas[i].$3),
                        ],
                      ],
                    ),
                  ),
                ],

                if ((m.descripcion ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _titulo('Descripción'),
                  const SizedBox(height: 10),
                  _tarjeta(_texto(m.descripcion!.trim())),
                ],

                if ((m.observaciones ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _titulo('Observaciones'),
                  const SizedBox(height: 10),
                  _tarjeta(_texto(m.observaciones!.trim())),
                ],

                if (!_programada) ...[
                  const SizedBox(height: 22),
                  _titulo('Comprobante'),
                  const SizedBox(height: 10),
                  _tarjeta(
                    _fila(
                      Icons.receipt_long_outlined,
                      'Documento',
                      m.referenciaComprobante ?? 'Sin comprobante',
                    ),
                  ),
                ],

                if (m.componentes.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _titulo('Componentes revisados'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in m.componentes) _chip(_nombreComponente(id)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    final m = mantencion;
    final color = _programada ? AppColors.advertencia : AppColors.primario;
    return _tarjeta(
      Row(
        children: [
          // Solo el ícono, en azul y sin recuadro de color de fondo.
          SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              _programada
                  ? Icons.event_available_outlined
                  : Icons.build_circle_outlined,
              color: AppColors.primario,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombreTipo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _etiqueta(_programada ? 'Programada' : 'Realizada', color),
                    if (m.origenRegistro == 'ia')
                      _etiqueta('Registrada con IA', AppColors.textoSecundario),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _titulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _tarjeta(Widget hijo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
      ),
      child: hijo,
    );
  }

  Widget _fila(IconData icono, String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: AppColors.primario, size: 19),
        const SizedBox(width: 10),
        Text(etiqueta, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _texto(String texto) {
    return Text(
      texto,
      style: const TextStyle(color: AppColors.texto, fontSize: 14, height: 1.5),
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.texto,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
