import 'package:flutter/material.dart';

import 'gasto_periodo.dart';
import 'tarjeta_mantencion.dart';

/// Colores del card "Gasto en mantenciones". La app no tiene un archivo de
/// tema (cada pantalla define los suyos), así que viven acá, solo para el card.
class TokensGasto {
  static const Color fondoCard = Color(0xFFFFFFFF);
  static const Color bordeCard = Color(0xFFCBD5E1);
  static const Color violeta = Color(0xFF1E3A8A);
  static const Color pildora = Color(0xFFE2E8F0);
  static const Color textoPrincipal = Color(0xFF0F172A);
  static const Color textoSecundario = Color(0xFF64748B);
  static const Color acento = Color(0xFF2F5BBA);
  static const Color flechaDeshabilitada = Color(0xFF94A3B8);
  static const Color iconoVerde = Color(0xFF2DD4BF);
}

/// Monto en pesos chilenos con separador de miles por punto: $87.000.
String clp(int monto) =>
    '${monto < 0 ? '-' : ''}\$${formatoMiles(monto.abs())}';

String textoCantidad(int n) => n == 1 ? '1 mantención' : '$n mantenciones';

/// Selector segmentado "Mes | Año | Todo" (compacto).
class SegmentosPeriodo extends StatelessWidget {
  final TipoPeriodo seleccionado;
  final ValueChanged<TipoPeriodo> onChanged;

  const SegmentosPeriodo({
    super.key,
    required this.seleccionado,
    required this.onChanged,
  });

  static const _etiquetas = {
    TipoPeriodo.mes: 'Mes',
    TipoPeriodo.anio: 'Año',
    TipoPeriodo.todo: 'Todo',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TokensGasto.pildora,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tipo in TipoPeriodo.values)
            Semantics(
              button: true,
              selected: tipo == seleccionado,
              label: 'Ver gasto por ${_etiquetas[tipo]!.toLowerCase()}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onChanged(tipo),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tipo == seleccionado
                        ? TokensGasto.violeta
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _etiquetas[tipo]!,
                    style: TextStyle(
                      color: tipo == seleccionado
                          ? Colors.white
                          : TokensGasto.textoSecundario,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Píldora con el periodo ("Octubre 2026" o "2026"); al tocarla se abre el
/// selector de mes o de año.
class PildoraPeriodo extends StatelessWidget {
  final PeriodoGasto periodo;
  final VoidCallback onElegir;

  const PildoraPeriodo({
    super.key,
    required this.periodo,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    final unidad = periodo.tipo == TipoPeriodo.mes ? 'mes' : 'año';
    return Semantics(
      button: true,
      label: 'Elegir $unidad, ${periodo.etiqueta.toLowerCase()}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onElegir,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: TokensGasto.pildora,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  periodo.etiqueta,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TokensGasto.textoPrincipal,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: TokensGasto.acento,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monto principal del periodo y cantidad de mantenciones.
class MontoPeriodo extends StatelessWidget {
  final ResumenGasto resumen;

  const MontoPeriodo({super.key, required this.resumen});

  @override
  Widget build(BuildContext context) {
    final vacio = resumen.cantidad == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El monto se achica si es muy largo (ej. $12.345.678) en vez de
        // desbordar; las cifras tabulares evitan que salte al cambiar.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            clp(resumen.total),
            maxLines: 1,
            style: const TextStyle(
              color: TokensGasto.textoPrincipal,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              height: 1.1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          vacio
              ? 'Sin mantenciones en este periodo'
              : textoCantidad(resumen.cantidad),
          style: const TextStyle(
            color: TokensGasto.textoSecundario,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
