import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/services/mantencion_service.dart';
import '../dashboard/dashboard_logica.dart';
import '../dashboard/gastos_historial.dart';
import 'gasto_periodo.dart';
import 'widgets_gasto.dart';

/// Tarjeta "Gastado en <mes>" del vehículo elegido: monto del mes actual y
/// cantidad de mantenciones, con un enlace "Ver todo" al historial de gastos.
/// Mide lo mismo que la tarjeta de gastos del Inicio.
/// Ya no tiene selector de periodo: el detalle por mes y año está en el
/// historial.
/// Solo orquesta: el cálculo está en `gasto_periodo.dart` y cada pieza visual
/// en `widgets_gasto.dart` y `selector_periodo_gasto.dart`.
class ResumenGastosMantenciones extends StatefulWidget {
  final String vehiculoId;

  /// Se llama al tocar "Ver todo". Sin él, el enlace no se muestra.
  final VoidCallback? onVerTodo;

  /// Solo para probar con una fecha fija.
  final DateTime? hoy;

  const ResumenGastosMantenciones({
    super.key,
    required this.vehiculoId,
    this.onVerTodo,
    this.hoy,
  });

  @override
  State<ResumenGastosMantenciones> createState() =>
      _ResumenGastosMantencionesState();
}

class _ResumenGastosMantencionesState extends State<ResumenGastosMantenciones> {
  late Stream<List<MantencionModel>> _stream = _crearStream();

  DateTime get _hoy => widget.hoy ?? DateTime.now();

  /// Siempre el mes actual.
  late final PeriodoGasto _periodo = PeriodoGasto.mes(_hoy);

  Stream<List<MantencionModel>> _crearStream() => MantencionService()
      .streamPorVehiculo(widget.vehiculoId, estado: EstadoMantencion.realizada);

  @override
  void didUpdateWidget(ResumenGastosMantenciones anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.vehiculoId != widget.vehiculoId) {
      _stream = _crearStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MantencionModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final lista = snapshot.data ?? const <MantencionModel>[];
        final resumen = calcularGasto(lista, _periodo);
        final mes = nombreDelMes(_hoy.month).toLowerCase();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título sobre la tarjeta ("Gastado en octubre") y, a la derecha, el
            // enlace al historial. Igual que "Gastos del mes" en el Inicio.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gastado en $mes',
                    style: const TextStyle(
                      color: TokensGasto.textoPrincipal,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onVerTodo != null)
                  GestureDetector(
                    onTap: widget.onVerTodo,
                    child: const Text(
                      'Ver todo',
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Mismo tamaño que la tarjeta de gastos del Inicio.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TokensGasto.fondoCard,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SizedBox(
                height: altoContenidoTarjetaGastos,
                child: snapshot.hasError
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No fue posible cargar los gastos.',
                          style: TextStyle(
                            color: TokensGasto.textoSecundario,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Una sola línea: si el monto es largo, se achica.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatearPesos(resumen.total),
                              maxLines: 1,
                              style: const TextStyle(
                                color: TokensGasto.textoPrincipal,
                                fontSize: 28,
                                height: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            resumen.cantidad == 0
                                ? 'Sin mantenciones este mes'
                                : textoCantidad(resumen.cantidad),
                            style: const TextStyle(
                              color: TokensGasto.textoSecundario,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
