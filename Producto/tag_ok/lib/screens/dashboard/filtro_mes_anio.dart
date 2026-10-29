import 'package:flutter/material.dart';

import 'dashboard_logica.dart';

/// Filtro por mes y por año: dos desplegables lado a lado. "Todos" no filtra por
/// ese criterio (`null`). La lista se abre justo debajo del campo, del mismo
/// ancho. Lo usan el historial de gastos y el historial de mantenciones.
class FiltroMesAnio extends StatelessWidget {
  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  /// Mes elegido (1 a 12) o `null` = todos.
  final int? mes;

  /// Año elegido o `null` = todos.
  final int? anio;

  /// Años que se ofrecen (normalmente los que tienen datos).
  final List<int> anios;

  final ValueChanged<int?> alCambiarMes;
  final ValueChanged<int?> alCambiarAnio;

  const FiltroMesAnio({
    super.key,
    required this.mes,
    required this.anio,
    required this.anios,
    required this.alCambiarMes,
    required this.alCambiarAnio,
  });

  @override
  Widget build(BuildContext context) {
    final aniosDisponibles = anios.isEmpty ? [DateTime.now().year] : anios;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _selector(
            etiqueta: 'Mes',
            valor: mes ?? 0,
            entradas: [
              const DropdownMenuEntry<int>(value: 0, label: 'Todos'),
              for (var m = 1; m <= 12; m++)
                DropdownMenuEntry<int>(value: m, label: nombreDelMes(m)),
            ],
            alElegir: (v) => alCambiarMes((v == null || v == 0) ? null : v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _selector(
            etiqueta: 'Año',
            valor: anio ?? 0,
            entradas: [
              const DropdownMenuEntry<int>(value: 0, label: 'Todos'),
              for (final a in aniosDisponibles)
                DropdownMenuEntry<int>(value: a, label: '$a'),
            ],
            alElegir: (v) => alCambiarAnio((v == null || v == 0) ? null : v),
          ),
        ),
      ],
    );
  }

  /// Desplegable: la lista se abre debajo del campo (no encima), alineada con
  /// él y con su mismo ancho. El valor 0 representa "Todos".
  Widget _selector({
    required String etiqueta,
    required int valor,
    required List<DropdownMenuEntry<int>> entradas,
    required ValueChanged<int?> alElegir,
  }) {
    return DropdownMenu<int>(
      // Si el valor cambia desde fuera (p. ej. "Limpiar filtros"), el campo se
      // vuelve a construir con el valor nuevo.
      key: ValueKey('$etiqueta-$valor'),
      expandedInsets: EdgeInsets.zero,
      initialSelection: valor,
      label: Text(etiqueta),
      // Solo se elige de la lista: no se escribe ni se filtra.
      requestFocusOnTap: false,
      enableFilter: false,
      enableSearch: false,
      menuHeight: 300,
      textStyle: const TextStyle(color: _textMain, fontSize: 14),
      trailingIcon: const Icon(Icons.keyboard_arrow_down, color: _textMuted),
      selectedTrailingIcon: const Icon(Icons.keyboard_arrow_up, color: _textMuted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor,
        isDense: true,
        labelStyle: const TextStyle(color: _textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(_surfaceColor),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      dropdownMenuEntries: entradas,
      onSelected: alElegir,
    );
  }
}
