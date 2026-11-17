import 'package:flutter/material.dart';

import '../../data/models/abastecimiento_model.dart';
import '../mantenimiento/tarjeta_mantencion.dart'
    show formatoFecha, formatoMiles;
import '../mantenimiento/widgets_gasto.dart' show clp;
import 'gasto_combustible.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

/// Detalle de una carga de combustible o de energía: todos los datos que se
/// guardaron al registrarla. Se abre al tocar una tarjeta del historial, igual
/// que el detalle de una mantención.
class DetalleCombustibleScreen extends StatelessWidget {
  final AbastecimientoModel carga;

  const DetalleCombustibleScreen({super.key, required this.carga});

  bool get _electrica =>
      carga.tipoAbastecimiento == TipoAbastecimiento.cargaElectrica;

  @override
  Widget build(BuildContext context) {
    final c = carga;
    final filas = <(IconData, String, String)>[
      (Icons.event_outlined, 'Fecha', formatoFecha(c.fecha)),
      if (c.kilometraje != null)
        (Icons.speed_outlined, 'Kilometraje', '${formatoMiles(c.kilometraje!)} km'),
      if ((c.estacionServicio ?? '').trim().isNotEmpty)
        (
          Icons.storefront_outlined,
          _electrica ? 'Estación de carga' : 'Estación de servicio',
          c.estacionServicio!.trim()
        ),
      if ((c.tipoCombustible ?? '').trim().isNotEmpty)
        (
          Icons.local_gas_station_outlined,
          _electrica ? 'Tipo de energía' : 'Combustible',
          c.tipoCombustible!.trim()
        ),
      if (c.cantidad != null)
        (
          Icons.opacity_outlined,
          'Cantidad',
          '${formatoCantidad(c.cantidad!)} ${c.unidad}'
        ),
      if (c.precioUnitario != null)
        (
          Icons.sell_outlined,
          'Precio por ${c.unidad}',
          '\$${formatoCantidad(c.precioUnitario!)}'
        ),
      if (c.total != null)
        (Icons.payments_outlined, 'Total pagado', clp(c.total!)),
    ];

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.texto),
        title: Text(
          'Detalle de carga',
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
                const SizedBox(height: 22),
                _titulo('Información general'),
                const SizedBox(height: 10),
                _tarjeta(
                  Column(
                    children: [
                      for (var i = 0; i < filas.length; i++) ...[
                        if (i > 0) Divider(height: 18, color: AppColors.fondo),
                        _fila(filas[i].$1, filas[i].$2, filas[i].$3),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return _tarjeta(
      Row(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              _electrica
                  ? Icons.ev_station_outlined
                  : Icons.local_gas_station_outlined,
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
                  carga.titulo,
                  style: TextStyle(
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
                    _etiqueta(carga.tipoAbastecimiento.etiqueta, AppColors.primario),
                    if (carga.origenRegistro == 'ia')
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
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
      style: TextStyle(
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
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        boxShadow: AppSombras.tarjeta,
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
        Text(etiqueta, style: TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
