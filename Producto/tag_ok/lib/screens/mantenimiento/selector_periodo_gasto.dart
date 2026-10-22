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
/// periodo elegido, o null si se cancela. Solo deja elegir entre [primero] (la
/// primera mantención registrada) y [hoy]. Sin paquetes: es un diálogo propio.
Future<PeriodoGasto?> mostrarSelectorPeriodo(
  BuildContext context, {
  required PeriodoGasto actual,
  required DateTime primero,
  required DateTime hoy,
}) {
  return showDialog<PeriodoGasto>(
    context: context,
    builder: (_) => _DialogoPeriodo(actual: actual, primero: primero, hoy: hoy),
  );
}

class _DialogoPeriodo extends StatefulWidget {
  final PeriodoGasto actual;
  final DateTime primero;
  final DateTime hoy;

  const _DialogoPeriodo({
    required this.actual,
    required this.primero,
    required this.hoy,
  });

  @override
  State<_DialogoPeriodo> createState() => _DialogoPeriodoState();
}

class _DialogoPeriodoState extends State<_DialogoPeriodo> {
  /// Año que se está mirando (solo en el selector de mes).
  late int _anio = widget.actual.inicio.year;

  bool get _esMes => widget.actual.tipo == TipoPeriodo.mes;

  bool _mesDisponible(int anio, int mes) {
    final inicio = DateTime(widget.primero.year, widget.primero.month);
    final fin = DateTime(widget.hoy.year, widget.hoy.month);
    final candidato = DateTime(anio, mes);
    return !candidato.isBefore(inicio) && !candidato.isAfter(fin);
  }

  Widget _celda({
    required String texto,
    required bool seleccionada,
    required bool disponible,
    required String semantica,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: seleccionada,
      enabled: disponible,
      label: semantica,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: disponible ? onTap : null,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: seleccionada ? TokensGasto.violeta : TokensGasto.pildora,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: seleccionada
                  ? Colors.white
                  : disponible
                      ? TokensGasto.textoPrincipal
                      : TokensGasto.flechaDeshabilitada,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectorMes() {
    final actual = widget.actual;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Año anterior',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _anio > widget.primero.year
                  ? () => setState(() => _anio--)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: TokensGasto.textoPrincipal,
              disabledColor: TokensGasto.flechaDeshabilitada,
            ),
            Expanded(
              child: Text(
                '$_anio',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TokensGasto.textoPrincipal,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Año siguiente',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _anio < widget.hoy.year
                  ? () => setState(() => _anio++)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              color: TokensGasto.textoPrincipal,
              disabledColor: TokensGasto.flechaDeshabilitada,
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2,
          children: [
            for (var mes = 1; mes <= 12; mes++)
              _celda(
                texto: _mesesAbreviados[mes - 1],
                seleccionada:
                    actual.inicio.year == _anio && actual.inicio.month == mes,
                disponible: _mesDisponible(_anio, mes),
                semantica: PeriodoGasto.mes(DateTime(_anio, mes)).etiqueta,
                onTap: () => Navigator.pop(
                  context,
                  PeriodoGasto.mes(DateTime(_anio, mes)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _selectorAnio() {
    final anios = [
      for (var a = widget.hoy.year; a >= widget.primero.year; a--) a,
    ];
    return SizedBox(
      width: double.maxFinite,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2,
        children: [
          for (final a in anios)
            _celda(
              texto: '$a',
              seleccionada: widget.actual.inicio.year == a,
              disponible: true,
              semantica: 'Año $a',
              onTap: () => Navigator.pop(
                context,
                PeriodoGasto.anio(DateTime(a)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TokensGasto.fondoCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: TokensGasto.bordeCard),
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
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: _esMes ? _selectorMes() : _selectorAnio(),
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
