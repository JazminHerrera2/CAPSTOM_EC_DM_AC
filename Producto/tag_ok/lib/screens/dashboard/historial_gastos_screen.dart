import 'package:flutter/material.dart';

import 'dashboard_logica.dart';
import 'filtro_mes_anio.dart';

/// Historial de gastos de un vehículo, filtrable por mes y año. Muestra el
/// total pagado y, debajo, un apartado por tipo de gasto con su total para el
/// período elegido (sin desglose). Al tocar un tipo se abre su página:
/// Mantenciones, TAG, Combustible o Estacionamientos. Se abre desde "Ver todo"
/// de Gastos del mes.
class HistorialGastosScreen extends StatefulWidget {
  /// Nombre del vehículo, que se muestra bajo el título.
  final String nombreVehiculo;
  final List<MovimientoGasto> movimientos;

  /// Se llama al tocar el apartado de un tipo de gasto.
  final void Function(CategoriaGasto categoria) alAbrirCategoria;

  const HistorialGastosScreen({
    super.key,
    required this.nombreVehiculo,
    required this.movimientos,
    required this.alAbrirCategoria,
  });

  @override
  State<HistorialGastosScreen> createState() => _HistorialGastosScreenState();
}

class _HistorialGastosScreenState extends State<HistorialGastosScreen> {
  static const Color _bgColor = Color(0xFFF1F5F9);
  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  // Filtro: mes (1 a 12) y año. `null` = todos.
  int? _mes;
  int? _anio;

  // Orden en que se muestran los tipos.
  static const List<CategoriaGasto> _orden = [
    CategoriaGasto.combustible,
    CategoriaGasto.tag,
    CategoriaGasto.estacionamientos,
    CategoriaGasto.mantenciones,
  ];

  static String _etiqueta(CategoriaGasto c) {
    switch (c) {
      case CategoriaGasto.combustible:
        return 'Combustible';
      case CategoriaGasto.tag:
        return 'TAG';
      case CategoriaGasto.estacionamientos:
        return 'Estacionamientos';
      case CategoriaGasto.mantenciones:
        return 'Mantenciones';
    }
  }

  static IconData _icono(CategoriaGasto c) {
    switch (c) {
      case CategoriaGasto.tag:
        return Icons.toll_outlined;
      case CategoriaGasto.combustible:
        return Icons.local_gas_station_outlined;
      case CategoriaGasto.estacionamientos:
        return Icons.local_parking_outlined;
      case CategoriaGasto.mantenciones:
        return Icons.handyman_outlined;
    }
  }

  // Todos los íconos del historial son del azul marino del botón del mapa.
  static const Color _colorIconos = Color(0xFF1E3A8A);

  static Color _color(CategoriaGasto c) => _colorIconos;

  @override
  Widget build(BuildContext context) {
    final anios = aniosConMovimientos(widget.movimientos);
    final filtrados = filtrarMovimientos(
      widget.movimientos,
      anio: _anio,
      mes: _mes,
    );
    final totales = totalesPorCategoria(filtrados);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _textMain),
        title: const Text(
          'Historial de gastos',
          style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (widget.nombreVehiculo.isNotEmpty) ...[
                  _tarjetaVehiculo(),
                  const SizedBox(height: 10),
                ],
                FiltroMesAnio(
                  mes: _mes,
                  anio: _anio,
                  anios: anios,
                  alCambiarMes: (v) => setState(() => _mes = v),
                  alCambiarAnio: (v) => setState(() => _anio = v),
                ),
                // Línea que separa los filtros del resto de la página.
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFCBD5E1), height: 1, thickness: 1),
                const SizedBox(height: 16),
                _totalPagado(sumarMovimientos(filtrados)),
                const SizedBox(height: 14),
                for (final c in _orden) ...[
                  _apartado(c, totales[c] ?? 0),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Vehículo del historial: solo se muestra (no se cambia desde acá), igual que
  /// en el historial de mantenciones.
  Widget _tarjetaVehiculo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_outlined, color: _textMuted, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo',
                  style: TextStyle(color: _textMuted, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.nombreVehiculo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMain,
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

  /// Fondo del total pagado: el azul claro de las barras de los meses que no
  /// son el de mayor gasto en "Gastos del mes" del Inicio.
  static final Color _azulBarras = const Color(0xFF1E3A8A).withValues(alpha: 0.35);

  Widget _totalPagado(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _azulBarras,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Total pagado',
              style: TextStyle(
                color: _textMain,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            formatearPesos(total),
            style: const TextStyle(
              color: _textMain,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Un tipo de gasto con su total del período; al tocarlo se abre su página.
  Widget _apartado(CategoriaGasto c, int total) {
    final color = _color(c);
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.alAbrirCategoria(c),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Solo el ícono, en azul y sin recuadro de color detrás.
              SizedBox(
                width: 40,
                height: 40,
                child: Icon(_icono(c), color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _etiqueta(c),
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatearPesos(total),
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
