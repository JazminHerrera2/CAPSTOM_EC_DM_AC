import 'package:flutter/material.dart';

/// Selector (tipo de mantención, vehículo) en forma de acordeón: al tocar la cabecera
/// se despliega la lista de opciones. Si se elige [opcionOtra], aparece debajo
/// una casilla de texto para escribir el tipo.
class SelectorTipoMantencion extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> opciones;
  final String? valor;
  final ValueChanged<String> onChanged;

  /// Si es null no hay opción "Otra" con casilla de texto (p. ej. al elegir
  /// un vehículo).
  final TextEditingController? otroController;

  final IconData icono;
  final String opcionOtra;

  /// true: la lista flota sobre el contenido (overlay) en vez de empujarlo.
  final bool flotante;

  /// Largo máximo de lo que se escribe en la casilla de "Otros" (null = sin
  /// límite).
  final int? largoMaximoOtro;

  const SelectorTipoMantencion({
    super.key,
    required this.opciones,
    required this.valor,
    required this.onChanged,
    this.otroController,
    this.icono = Icons.build_outlined,
    this.label = 'Tipo de mantención',
    this.hint = 'Seleccionar tipo',
    this.opcionOtra = 'Otra',
    this.flotante = false,
    this.largoMaximoOtro,
  });

  @override
  State<SelectorTipoMantencion> createState() => _SelectorTipoMantencionState();
}

class _SelectorTipoMantencionState extends State<SelectorTipoMantencion> {
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFCBD5E1);

  static const double _alturaMaxima = 220;

  bool _abierto = false;
  final ScrollController _scroll = ScrollController();
  final LayerLink _link = LayerLink();
  final GlobalKey _botonKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _scroll.dispose();
    super.dispose();
  }

  Widget _panel(String? valor) {
    return Container(
      margin: EdgeInsets.only(top: widget.flotante ? 0 : 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent),
        boxShadow: widget.flotante
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxHeight: widget.flotante ? 240 : _alturaMaxima,
      ),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _scroll,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: widget.opciones.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: borderColor),
          itemBuilder: (context, i) {
            final opcion = widget.opciones[i];
            final seleccionada = opcion == valor;
            return InkWell(
              onTap: () {
                widget.onChanged(opcion);
                _cerrar();
              },
              child: Container(
                color: seleccionada ? primaryColor.withOpacity(0.16) : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opcion,
                        style: TextStyle(
                          color: seleccionada
                              ? const Color(0xFF1E3A8A)
                              : textMain,
                          fontSize: 13,
                          fontWeight: seleccionada
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (seleccionada)
                      const Icon(
                        Icons.check_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Abre o cierra la lista. En modo flotante la lista se dibuja en un
  /// OverlayEntry anclado debajo del botón, por lo que no empuja el contenido.
  void _alternar() {
    if (!widget.flotante) {
      setState(() => _abierto = !_abierto);
      return;
    }
    if (_entry == null) {
      _mostrar();
    } else {
      _cerrar();
    }
  }

  void _mostrar() {
    final caja = _botonKey.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null) return;
    final ancho = caja.size.width;
    final alto = caja.size.height;

    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Cierra al tocar fuera de la lista.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cerrar,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: Offset(0, alto + 6),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: ancho,
                child: Material(
                  type: MaterialType.transparency,
                  child: _panel(widget.valor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() => _abierto = true);
  }

  void _cerrar() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _abierto = false);
  }

  @override
  Widget build(BuildContext context) {
    final valor = widget.valor;
    final esOtra = widget.otroController != null && valor == widget.opcionOtra;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botón del acordeón.
        CompositedTransformTarget(
          link: _link,
          child: Material(
            key: _botonKey,
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _alternar,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _abierto ? primaryColor : Colors.transparent,
                    width: _abierto ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(widget.icono, color: textMuted, size: 21),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            valor ?? widget.hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: valor == null ? textMuted : textMain,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _abierto ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Panel desplegable con scroll.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _abierto && !widget.flotante
              ? _panel(valor)
              : const SizedBox(width: double.infinity),
        ),
        if (esOtra) ...[
          const SizedBox(height: 10),
          TextField(
            controller: widget.otroController!,
            maxLength: widget.largoMaximoOtro,
            style: const TextStyle(color: textMain, fontSize: 13),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Escribe el tipo de mantención',
              labelStyle: const TextStyle(color: textMuted),
              prefixIcon: const Icon(
                Icons.edit_outlined,
                color: textMuted,
                size: 21,
              ),
              filled: true,
              fillColor: bgColor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
