import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/services/mantencion_service.dart';
import 'gasto_periodo.dart';
import 'selector_periodo_gasto.dart';
import 'widgets_gasto.dart';

/// Card "Gasto en mantenciones" del vehículo elegido: monto del periodo
/// (mes, año o todo) y cantidad de mantenciones.
/// Solo orquesta: el cálculo está en `gasto_periodo.dart` y cada pieza visual
/// en `widgets_gasto.dart` y `selector_periodo_gasto.dart`.
class ResumenGastosMantenciones extends StatefulWidget {
  final String vehiculoId;

  /// Solo para probar con una fecha fija.
  final DateTime? hoy;

  const ResumenGastosMantenciones({
    super.key,
    required this.vehiculoId,
    this.hoy,
  });

  @override
  State<ResumenGastosMantenciones> createState() =>
      _ResumenGastosMantencionesState();
}

class _ResumenGastosMantencionesState extends State<ResumenGastosMantenciones> {
  late Stream<List<MantencionModel>> _stream = _crearStream();

  DateTime get _hoy => widget.hoy ?? DateTime.now();

  /// Mes por defecto.
  late PeriodoGasto _periodo = PeriodoGasto.mes(_hoy);

  Stream<List<MantencionModel>> _crearStream() => MantencionService()
      .streamPorVehiculo(widget.vehiculoId, estado: EstadoMantencion.realizada);

  @override
  void didUpdateWidget(ResumenGastosMantenciones anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.vehiculoId != widget.vehiculoId) {
      _stream = _crearStream();
    }
  }

  /// Cambia de Mes/Año/Todo conservando, si se puede, el año que se miraba.
  void _cambiarTipo(TipoPeriodo tipo) {
    final hoy = _hoy;
    final anio = _periodo.inicio.year;
    setState(() {
      switch (tipo) {
        case TipoPeriodo.mes:
          // De año a mes: el mes actual si es este año; si no, diciembre.
          _periodo = _periodo.tipo == TipoPeriodo.mes
              ? _periodo
              : PeriodoGasto.mes(
                  anio >= hoy.year ? hoy : DateTime(anio, 12),
                );
        case TipoPeriodo.anio:
          _periodo = PeriodoGasto.anio(
            _periodo.tipo == TipoPeriodo.todo ? hoy : DateTime(anio),
          );
        case TipoPeriodo.todo:
          _periodo = PeriodoGasto.todo();
      }
    });
  }

  Future<void> _elegir(List<MantencionModel> lista) async {
    final elegido = await mostrarSelectorPeriodo(
      context,
      actual: _periodo,
      meses: mesesConMantenciones(lista),
      anios: aniosConMantenciones(lista),
    );
    if (elegido != null && mounted) setState(() => _periodo = elegido);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MantencionModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final lista = snapshot.data ?? const <MantencionModel>[];
        final resumen = calcularGasto(lista, _periodo);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: TokensGasto.fondoCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TokensGasto.bordeCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Encabezado
              const Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    color: TokensGasto.iconoVerde,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gasto en mantenciones',
                      style: TextStyle(
                        color: TokensGasto.textoPrincipal,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2-3. Mes | Año | Todo a la izquierda y, a su derecha, la
              // opción de mes o de año (en Todo no hay opción que elegir).
              Row(
                children: [
                  SegmentosPeriodo(
                    seleccionado: _periodo.tipo,
                    onChanged: _cambiarTipo,
                  ),
                  if (_periodo.tipo != TipoPeriodo.todo) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PildoraPeriodo(
                          periodo: _periodo,
                          onElegir: () => _elegir(lista),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // 4-6. Monto, cantidad y estado vacío
              if (snapshot.hasError)
                const Text(
                  'No fue posible cargar los gastos.',
                  style: TextStyle(
                    color: TokensGasto.textoSecundario,
                    fontSize: 14,
                  ),
                )
              else
                MontoPeriodo(resumen: resumen),
            ],
          ),
        );
      },
    );
  }
}
