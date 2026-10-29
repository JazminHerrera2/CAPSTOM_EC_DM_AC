import 'package:flutter/material.dart';

import 'gasto_periodo.dart';
import 'widgets_gasto.dart';

const List<String> _mesesAbreviados = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// Abre el selector de mes o de año (según el tipo de [actual]) y devuelve el
/// periodo elegido, o null si se cancela. Solo ofrece los [meses] o [anios]
/// en que hay mantenciones registradas: lo que no tiene registros no aparece.
Future<PeriodoGasto?> mostrarSelectorPeriodo(
  BuildContext context, {
  required PeriodoGasto actual,
  required List<DateTime> meses,
  required List<int> anios,
}) {
  return showDialog<PeriodoGasto>(
    context: context,
    builder: (_) => _DialogoPeriodo(actual: actual, meses: meses, anios: anios),
  );
}

class _DialogoPeriodo extends StatelessWidget {
  final PeriodoGasto actual;

  /// Meses con mantenciones (primer día de cada mes), del más reciente al más
  /// antiguo.
  final List<DateTime> meses;

  /// Años con mantenciones, del más reciente al más antiguo.
  final List<int> anios;

  const _DialogoPeriodo({
    required this.actual,
    required this.meses,
    required this.anios,
  });

  bool get _esMes => actual.tipo == TipoPeriodo.mes;

  Widget _celda(
    BuildContext context, {
    required String texto,
    required String semantica,
    required bool seleccionada,
    required PeriodoGasto periodo,
  }) {
    return Semantics(
      button: true,
      selected: seleccionada,
      label: semantica,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context, periodo),
        child: Container(
          width: 84,
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: seleccionada ? TokensGasto.violeta : TokensGasto.pildora,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: seleccionada ? Colors.white : TokensGasto.textoPrincipal,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _listaMeses(BuildContext context) {
    // Agrupa por año, conservando el orden (el más reciente primero).
    final porAnio = <int, List<DateTime>>{};
    for (final mes in meses) {
      porAnio.putIfAbsent(mes.year, () => []).add(mes);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entrada in porAnio.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              '${entrada.key}',
              style: const TextStyle(
                color: TokensGasto.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mes in entrada.value)
                _celda(
                  context,
                  texto: _mesesAbreviados[mes.month - 1],
                  semantica: PeriodoGasto.mes(mes).etiqueta,
                  seleccionada: actual.tipo == TipoPeriodo.mes &&
                      actual.inicio.year == mes.year &&
                      actual.inicio.month == mes.month,
                  periodo: PeriodoGasto.mes(mes),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _listaAnios(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final anio in anios)
          _celda(
            context,
            texto: '$anio',
            semantica: 'Año $anio',
            seleccionada:
                actual.tipo == TipoPeriodo.anio && actual.inicio.year == anio,
            periodo: PeriodoGasto.anio(DateTime(anio)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayOpciones = _esMes ? meses.isNotEmpty : anios.isNotEmpty;

    return Dialog(
      backgroundColor: TokensGasto.fondoCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _esMes ? 'Elegir mes' : 'Elegir año',
              style: const TextStyle(
                color: TokensGasto.textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _esMes
                  ? 'Solo aparecen los meses con mantenciones registradas.'
                  : 'Solo aparecen los años con mantenciones registradas.',
              style: const TextStyle(
                color: TokensGasto.textoSecundario,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: hayOpciones
                    ? (_esMes ? _listaMeses(context) : _listaAnios(context))
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Aún no tienes mantenciones registradas con costo.',
                          style: TextStyle(
                            color: TokensGasto.textoPrincipal,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: TokensGasto.acento),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
