import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dashboard_page.dart' show haceCuanto;

// Paleta compartida por las pantallas del panel.
const Color kTinta = Color(0xFF0F172A);
const Color kGris = Color(0xFF64748B);
const Color kBorde = Color(0xFFE2E8F0);
const Color kAzul = Color(0xFF1D4ED8);
const Color kAzulSuave = Color(0xFFE0ECFF);
const Color kVerde = Color(0xFF059669);
const Color kRojo = Color(0xFFE11D48);

/// Alto común de botones, filtros y buscadores de las barras de herramientas.
const double kAltoControl = 46;

// ---------------------------------------------------------------------------
// Fechas
// ---------------------------------------------------------------------------

const List<String> _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// "24 abr 2026"
String fechaCorta(DateTime f) => '${f.day} ${_meses[f.month - 1]} ${f.year}';

/// "24 abr 2026, 01:24 p. m."
String fechaHora(DateTime f) {
  final h12 = f.hour % 12 == 0 ? 12 : f.hour % 12;
  final sufijo = f.hour < 12 ? 'a. m.' : 'p. m.';
  return '${fechaCorta(f)}, ${h12.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')} $sufijo';
}

/// "24 abr 2026, 01:24 p. m. · Hace 2 meses"
String fechaHoraRelativa(DateTime f, DateTime ahora) =>
    '${fechaHora(f)} · ${haceCuanto(f, ahora)}';

/// "2026-11-11" (para nombres de archivo).
String fechaIso(DateTime f) =>
    '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

DateTime? fechaDe(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

// ---------------------------------------------------------------------------
// Pórtico (el documento convive en formato plano y anidado bajo `datos`)
// ---------------------------------------------------------------------------

double? _aDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString().replaceAll(',', '.') ?? '');
}

class PorticoAdmin {
  PorticoAdmin(this.doc)
    : anidado = doc.data()['datos'] is Map,
      d = doc.data()['datos'] is Map
          ? Map<String, dynamic>.from(doc.data()['datos'] as Map)
          : doc.data();

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool anidado;
  final Map<String, dynamic> d;

  String get id => doc.id;
  String get nombre =>
      (d['nombre'] ?? d['autopista'] ?? '').toString().trim();
  String get codigo =>
      (d['codigo'] ?? d['id_portico'] ?? d['codigo_portico'] ?? '')
          .toString()
          .trim();
  String get autopista => (d['autopista'] ?? '').toString().trim();
  String get autopistaCodigo =>
      (d['autopista_codigo'] ?? d['codigo_autopista'] ?? '').toString().trim();
  String get sentido => (d['sentido'] ?? '').toString().trim();

  double? get lat {
    var v = _aDouble(d['lat'] ?? d['latitud']);
    final loc = d['location'];
    if (v == null && loc is Map) v = _aDouble(loc['lat']);
    final u = d['ubicacion'];
    if (v == null && u is GeoPoint) v = u.latitude;
    return v;
  }

  double? get lng {
    var v = _aDouble(d['lng'] ?? d['longitud']);
    final loc = d['location'];
    if (v == null && loc is Map) v = _aDouble(loc['lng']);
    final u = d['ubicacion'];
    if (v == null && u is GeoPoint) v = u.longitude;
    return v;
  }

  bool get activo {
    final v = d['activo'] ?? d['vigente'];
    return v is bool ? v : true;
  }

  double get tarifaBase => _aDouble(
        d['tarifa_base'] ?? d['costo'] ?? d['cost'] ?? d['Tarifa_Base'],
      ) ??
      0;
  double get tarifaPunta =>
      _aDouble(d['tarifa_punta'] ?? d['costoPunta'] ?? d['Tarifa_Punta']) ?? 0;
  double get tarifaSaturacion =>
      _aDouble(
        d['tarifa_saturacion'] ??
            d['costoSaturacion'] ??
            d['Tarifa_Saturacion'],
      ) ??
      0;
  bool get tieneTarifa => tarifaBase > 0;

  /// Cantidad de valores tarifarios configurados (base, punta, saturación).
  int get reglasTarifarias =>
      [tarifaBase, tarifaPunta, tarifaSaturacion].where((t) => t > 0).length;

  String get etiquetaCodigo => codigo.isNotEmpty ? codigo : id;

  /// Actualiza campos respetando si el documento es plano o anidado.
  Future<void> actualizar(Map<String, dynamic> campos) {
    final prefijo = anidado ? 'datos.' : '';
    return doc.reference.update({
      for (final e in campos.entries) '$prefijo${e.key}': e.value,
    });
  }
}

/// Nombre de autopista -> pórticos.
Map<String, List<PorticoAdmin>> agruparPorAutopista(List<PorticoAdmin> lista) {
  final m = <String, List<PorticoAdmin>>{};
  for (final p in lista) {
    if (p.autopista.isEmpty) continue;
    m.putIfAbsent(p.autopista, () => []).add(p);
  }
  return m;
}

// ---------------------------------------------------------------------------
// Varias suscripciones a streams con un solo setState
// ---------------------------------------------------------------------------

class SuscripcionesMultiples {
  final List<StreamSubscription<dynamic>> _subs = [];

  void escuchar<T>(
    Stream<T> stream,
    void Function(T) alDato, {
    void Function(Object)? alError,
  }) {
    _subs.add(
      stream.listen(alDato, onError: (Object e) => alError?.call(e)),
    );
  }

  void cancelar() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}

// ---------------------------------------------------------------------------
// Piezas visuales
// ---------------------------------------------------------------------------

class EncabezadoPagina extends StatelessWidget {
  const EncabezadoPagina({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.acciones = const [],
    this.icono,
    this.colorIcono = kAzul,
  });

  final String titulo;
  final String subtitulo;
  final List<Widget> acciones;
  final IconData? icono;
  final Color colorIcono;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icono != null) ...[
              Icon(icono, color: colorIcono, size: 26),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: compact ? 24 : 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: kTinta,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(subtitulo, style: const TextStyle(color: kGris, fontSize: 14)),
      ],
    );
    if (acciones.isEmpty) return textos;
    return LayoutBuilder(
      builder: (context, c) {
        // Pantalla ancha: título a la izquierda y botones a la derecha, a la
        // misma altura. Angosta: botones debajo del título.
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: textos),
              const SizedBox(width: 16),
              for (int i = 0; i < acciones.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                acciones[i],
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            textos,
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: acciones),
          ],
        );
      },
    );
  }
}

/// Barra de encabezado fija (título, subtítulo y acciones) que queda arriba
/// de la pantalla mientras el contenido se desplaza.
class BarraEncabezado extends StatelessWidget {
  const BarraEncabezado({super.key, required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 16 : 28,
      vertical: compact ? 14 : 20,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: kBorde)),
    ),
    child: child,
  );
}

/// Página con encabezado fijo y contenido desplazable.
class PaginaConEncabezado extends StatelessWidget {
  const PaginaConEncabezado({
    super.key,
    required this.compact,
    required this.encabezado,
    required this.children,
  });

  final bool compact;
  final Widget encabezado;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 16.0 : 28.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BarraEncabezado(compact: compact, child: encabezado),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 24, pad, pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class BotonContorno extends StatelessWidget {
  const BotonContorno({
    super.key,
    required this.texto,
    required this.icono,
    required this.onPressed,
  });

  final String texto;
  final IconData icono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icono, size: 18),
    label: Text(texto),
    style: OutlinedButton.styleFrom(
      foregroundColor: kTinta,
      side: const BorderSide(color: kBorde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size(0, kAltoControl),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

class BotonPrimario extends StatelessWidget {
  const BotonPrimario({
    super.key,
    required this.texto,
    required this.icono,
    required this.onPressed,
  });

  final String texto;
  final IconData icono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icono, size: 18),
    label: Text(texto),
    style: FilledButton.styleFrom(
      backgroundColor: kAzul,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size(0, kAltoControl),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

/// Contenedor blanco redondeado de las tarjetas grandes.
class TarjetaBlanca extends StatelessWidget {
  const TarjetaBlanca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: kBorde),
    ),
    child: child,
  );
}

/// Título + subtítulo de una tarjeta de listado, con controles a la derecha.
class CabeceraListado extends StatelessWidget {
  const CabeceraListado({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.controles = const [],
  });

  final String titulo;
  final String subtitulo;
  final List<Widget> controles;

  @override
  Widget build(BuildContext context) {
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kTinta,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitulo, style: const TextStyle(color: kGris, fontSize: 14)),
      ],
    );
    if (controles.isEmpty) return textos;
    return LayoutBuilder(
      builder: (context, c) {
        // Ancho aproximado que ocupan los controles en una sola fila.
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              textos,
              const Spacer(),
              for (int i = 0; i < controles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                controles[i],
              ],
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            textos,
            Wrap(spacing: 10, runSpacing: 10, children: controles),
          ],
        );
      },
    );
  }
}

InputDecoration decoCampo({required String hint, IconData? icono}) {
  OutlineInputBorder borde(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: const TextStyle(color: kGris, fontSize: 14),
    prefixIcon: icono == null ? null : Icon(icono, size: 20, color: kGris),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: borde(kBorde),
    enabledBorder: borde(kBorde),
    focusedBorder: borde(kAzul),
  );
}

class CampoBusqueda extends StatelessWidget {
  const CampoBusqueda({
    super.key,
    required this.controller,
    required this.hint,
    this.ancho = 260,
  });

  final TextEditingController controller;
  final String hint;
  final double ancho;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: ancho,
    height: kAltoControl,
    child: TextField(
      controller: controller,
      textAlignVertical: TextAlignVertical.center,
      decoration: decoCampo(hint: hint, icono: Icons.search),
    ),
  );
}

/// Desplegable de filtro: [opciones] son los valores; [etiquetas] (opcional)
/// cambia el texto mostrado de algunos valores. Usa el mismo acordeón que la
/// app del conductor.
class DesplegableFiltro extends StatelessWidget {
  const DesplegableFiltro({
    super.key,
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.ancho = 180,
    this.etiquetas = const {},
  });

  final String valor;
  final List<String> opciones;
  final ValueChanged<String> onChanged;
  final double ancho;
  final Map<String, String> etiquetas;

  @override
  Widget build(BuildContext context) => SelectorAcordeon(
    opciones: opciones,
    valor: opciones.contains(valor) ? valor : opciones.first,
    etiquetas: etiquetas,
    onChanged: onChanged,
    ancho: ancho,
    compacto: true,
  );
}


/// Selector en forma de acordeón (mismo diseño que el de la app del
/// conductor): cabecera blanca con flecha en círculo y lista flotante con la
/// opción elegida marcada.
class SelectorAcordeon extends StatefulWidget {
  const SelectorAcordeon({
    super.key,
    required this.opciones,
    required this.valor,
    required this.onChanged,
    this.etiquetas = const {},
    this.etiqueta,
    this.hint = 'Seleccionar',
    this.icono,
    this.ancho,
    this.deshabilitado = false,
    this.haciaArriba = false,
    this.compacto = false,
  });

  final List<String> opciones;
  final String? valor;
  final ValueChanged<String> onChanged;

  /// Texto mostrado para cada valor (si no está, se muestra el valor).
  final Map<String, String> etiquetas;

  /// Título pequeño sobre el valor (como en la app del conductor).
  final String? etiqueta;
  final String hint;
  final IconData? icono;
  final double? ancho;
  final bool deshabilitado;

  /// Abre la lista hacia arriba (para controles al pie de la página).
  final bool haciaArriba;

  /// Cabecera de una sola línea, para filtros en barras de herramientas.
  final bool compacto;

  @override
  State<SelectorAcordeon> createState() => _SelectorAcordeonState();
}

class _SelectorAcordeonState extends State<SelectorAcordeon> {
  final LayerLink _link = LayerLink();
  final GlobalKey _botonKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  OverlayEntry? _entry;
  bool _abierto = false;

  String _texto(String v) => widget.etiquetas[v] ?? v;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _scroll.dispose();
    super.dispose();
  }

  void _alternar() {
    if (widget.deshabilitado) return;
    _entry == null ? _mostrar() : _cerrar();
  }

  void _mostrar() {
    final caja = _botonKey.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null) return;
    final ancho = caja.size.width;
    final alto = caja.size.height;
    final arriba = widget.haciaArriba;

    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cerrar,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: arriba ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: arriba ? Alignment.bottomLeft : Alignment.topLeft,
            offset: Offset(0, arriba ? -6 : 6),
            child: Align(
              alignment: arriba ? Alignment.bottomLeft : Alignment.topLeft,
              child: SizedBox(
                width: ancho < 170 ? 170 : ancho,
                child: Material(
                  type: MaterialType.transparency,
                  child: _panel(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() => _abierto = true);
    // alto se usa solo para anclar; evita aviso de variable sin uso.
    assert(alto >= 0);
  }

  void _cerrar() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _abierto = false);
  }

  Widget _panel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxHeight: 260),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: widget.opciones.length > 6,
        child: ListView.separated(
          controller: _scroll,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: widget.opciones.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: kBorde),
          itemBuilder: (context, i) {
            final opcion = widget.opciones[i];
            final seleccionada = opcion == widget.valor;
            return InkWell(
              onTap: () {
                widget.onChanged(opcion);
                _cerrar();
              },
              child: Container(
                color: seleccionada ? kAzul.withValues(alpha: 0.10) : null,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _texto(opcion),
                        style: TextStyle(
                          color: seleccionada ? kAzul : kTinta,
                          fontSize: 13.5,
                          fontWeight:
                              seleccionada ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (seleccionada)
                      const Icon(Icons.check_rounded, color: kAzul, size: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.valor;
    final conEtiqueta = widget.etiqueta != null;
    final cabecera = CompositedTransformTarget(
      link: _link,
      child: Material(
        key: _botonKey,
        color: widget.deshabilitado ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _alternar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: widget.compacto && !conEtiqueta
                ? const BoxConstraints(minHeight: kAltoControl)
                : null,
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: widget.compacto && !conEtiqueta ? 0 : 11,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _abierto ? kAzul : kBorde,
                width: _abierto ? 1.5 : 1,
              ),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Row(
              children: [
                if (widget.icono != null) ...[
                  Icon(widget.icono, color: kGris, size: 20),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (conEtiqueta) ...[
                        Text(
                          widget.etiqueta!,
                          style: const TextStyle(color: kGris, fontSize: 10.5),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        v == null ? widget.hint : _texto(v),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: v == null ? kGris : kTinta,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _abierto ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: kAzul.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: kAzul,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
    return widget.ancho == null
        ? cabecera
        : SizedBox(width: widget.ancho, child: cabecera);
  }
}

class Pildora extends StatelessWidget {
  const Pildora(
    this.texto, {
    super.key,
    this.fondo = const Color(0xFFF1F5F9),
    this.colorTexto = kTinta,
    this.borde,
    this.icono,
  });

  final String texto;
  final Color fondo;
  final Color colorTexto;
  final Color? borde;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(20),
      border: borde == null ? null : Border.all(color: borde!),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 13, color: colorTexto),
          const SizedBox(width: 5),
        ],
        Text(
          texto,
          style: TextStyle(
            color: colorTexto,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// Cuadrito azul claro con icono, usado como "avatar" de filas.
class IconoCuadro extends StatelessWidget {
  const IconoCuadro(this.icono, {super.key, this.tam = 38});

  final IconData icono;
  final double tam;

  @override
  Widget build(BuildContext context) => Container(
    width: tam,
    height: tam,
    decoration: BoxDecoration(
      color: kAzulSuave,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icono, color: kAzul, size: tam * 0.5),
  );
}

/// Fila de tabla con ancho flexible: la primera columna se expande y el resto
/// tiene ancho fijo. En pantallas angostas la tabla se desplaza en horizontal.
class TablaSimple extends StatelessWidget {
  const TablaSimple({
    super.key,
    required this.encabezados,
    required this.anchos,
    required this.filas,
    this.onTapFila,
  });

  /// Un título por columna (el primero corresponde a la columna flexible).
  final List<String> encabezados;

  /// Ancho de cada columna salvo la primera (debe tener `encabezados.length-1`).
  final List<double> anchos;
  final List<List<Widget>> filas;
  final void Function(int index)? onTapFila;

  static const double _minPrimera = 240;

  @override
  Widget build(BuildContext context) {
    final minTotal = _minPrimera + anchos.fold<double>(0, (a, b) => a + b);
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth < minTotal ? minTotal : c.maxWidth;
        Widget fila(List<Widget> celdas, {bool enc = false, int? i}) {
          final contenido = Container(
            padding: EdgeInsets.symmetric(vertical: enc ? 10 : 9, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: kBorde, width: enc ? 1 : 0.8),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: celdas.first),
                for (int k = 1; k < celdas.length; k++)
                  SizedBox(
                    width: anchos[k - 1],
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: celdas[k],
                    ),
                  ),
              ],
            ),
          );
          if (enc || i == null || onTapFila == null) return contenido;
          return InkWell(onTap: () => onTapFila!(i), child: contenido);
        }

        final tabla = SizedBox(
          width: ancho,
          child: Column(
            children: [
              fila([
                for (final e in encabezados)
                  Text(
                    e,
                    style: const TextStyle(
                      color: kTinta,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ], enc: true),
              for (int i = 0; i < filas.length; i++) fila(filas[i], i: i),
            ],
          ),
        );
        if (c.maxWidth >= minTotal) return tabla;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: tabla,
        );
      },
    );
  }
}

/// Paginación simple: "Filas por página", rango y flechas.
class Paginador extends StatelessWidget {
  const Paginador({
    super.key,
    required this.pagina,
    required this.porPagina,
    required this.total,
    required this.etiqueta,
    required this.onPagina,
    required this.onPorPagina,
  });

  final int pagina;
  final int porPagina;
  final int total;
  final String etiqueta;
  final ValueChanged<int> onPagina;
  final ValueChanged<int> onPorPagina;

  @override
  Widget build(BuildContext context) {
    final paginas = (total / porPagina).ceil();
    final desde = total == 0 ? 0 : pagina * porPagina + 1;
    final hasta = ((pagina + 1) * porPagina).clamp(0, total);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(
          'Mostrando $desde-$hasta de $total $etiqueta',
          style: const TextStyle(color: kGris, fontSize: 13),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filas por página',
              style: TextStyle(color: kGris, fontSize: 13),
            ),
            const SizedBox(width: 8),
            SelectorAcordeon(
              ancho: 92,
              compacto: true,
              haciaArriba: true,
              valor: '$porPagina',
              opciones: const ['10', '20', '50'],
              onChanged: (v) => onPorPagina(int.parse(v)),
            ),
            IconButton(
              onPressed: pagina > 0 ? () => onPagina(pagina - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${paginas == 0 ? 0 : pagina + 1} / $paginas',
              style: const TextStyle(color: kGris, fontSize: 13),
            ),
            IconButton(
              onPressed: pagina + 1 < paginas ? () => onPagina(pagina + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Panel lateral derecho (con fondo desenfocado)
// ---------------------------------------------------------------------------

Future<T?> mostrarPanelLateral<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double ancho = 460,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar panel',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) {
      final w = MediaQuery.sizeOf(ctx).width;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(color: Colors.black.withValues(alpha: 0.22)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.white,
              elevation: 8,
              child: SizedBox(
                width: w < ancho ? w : ancho,
                height: double.infinity,
                child: SafeArea(child: builder(ctx)),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

void avisar(BuildContext context, String mensaje, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? kRojo : kVerde,
    ),
  );
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String confirmar = 'Confirmar',
  bool peligro = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: peligro ? kRojo : kAzul,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmar),
        ),
      ],
    ),
  );
  return r ?? false;
}
