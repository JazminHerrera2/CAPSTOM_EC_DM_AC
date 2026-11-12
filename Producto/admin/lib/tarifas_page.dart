import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';
import 'porticos_paneles.dart';

class TarifasPage extends StatefulWidget {
  const TarifasPage({super.key, required this.service});

  final AdminFirestoreService service;

  @override
  State<TarifasPage> createState() => _TarifasPageState();
}

class _TarifasPageState extends State<TarifasPage> {
  final TextEditingController _busqueda = TextEditingController();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      widget.service.streamPorticos();
  String _autopista = 'Todas';
  int _pagina = 0;
  int _porPagina = 10;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() => _pagina = 0));
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _editar(PorticoAdmin p) async {
    final r = await mostrarPanelLateral<({double base, double punta, double sat})>(
      context,
      ancho: 460,
      builder: (_) => _PanelTarifas(p: p),
    );
    if (r == null) return;
    try {
      await p.actualizar({
        'tarifa_base': r.base,
        'tarifa_punta': r.punta,
        'tarifa_saturacion': r.sat,
      });
      await widget.service.logAction(
        action: 'EDIT_TARIFF',
        target: p.nombre,
        details:
            'Configuró la tarifa del pórtico ${p.etiquetaCodigo} (${p.nombre}): base \$${_num(r.base)}, punta \$${_num(r.punta)}, saturación \$${_num(r.sat)}',
      );
      if (mounted) avisar(context, 'Tarifas guardadas.');
    } catch (e) {
      if (mounted) avisar(context, 'No se pudieron guardar: $e', error: true);
    }
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    return SafeArea(
      child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
              titulo: 'Tarifas',
              subtitulo:
                  'Administra los valores de cobro por vehículo y horario de cada pórtico.',
              acciones: [
                BotonContorno(
                  texto: 'Actualizar',
                  icono: Icons.refresh,
                  onPressed: () => setState(
                    () => _stream = widget.service.streamPorticos(),
                  ),
                ),
              ],
            ),
            children: [

            _listadoPorticos(),
          
            ],
          ),
    );
  }

  Widget _listadoPorticos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Error al leer Firestore: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final todos = snap.data!.docs.map(PorticoAdmin.new).toList()
          ..sort((a, b) {
            final c = a.autopista.compareTo(b.autopista);
            return c != 0 ? c : a.etiquetaCodigo.compareTo(b.etiquetaCodigo);
          });
        final autopistas = {
          for (final p in todos)
            if (p.autopista.isNotEmpty) p.autopista,
        }.toList()..sort();
        final sel = autopistas.contains(_autopista) ? _autopista : 'Todas';
        final q = _busqueda.text.toLowerCase().trim();
        final filtrados = todos.where((p) {
          if (sel != 'Todas' && p.autopista != sel) return false;
          if (q.isEmpty) return true;
          return p.nombre.toLowerCase().contains(q) ||
              p.codigo.toLowerCase().contains(q);
        }).toList();

        final paginas = (filtrados.length / _porPagina).ceil();
        if (_pagina >= paginas && paginas > 0) _pagina = paginas - 1;
        final desde = _pagina * _porPagina;
        final hasta = (desde + _porPagina).clamp(0, filtrados.length);
        final pagina = filtrados.sublist(desde, hasta);

        return TarjetaBlanca(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CabeceraListado(
                titulo: 'Tarifas por pórtico',
                subtitulo: '${filtrados.length} de ${todos.length} pórticos',
                controles: [
                  CampoBusqueda(controller: _busqueda, hint: 'Buscar pórtico…'),
                  DesplegableFiltro(
                    valor: sel,
                    opciones: ['Todas', ...autopistas],
                    etiquetas: const {'Todas': 'Todas las autopistas'},
                    ancho: 210,
                    onChanged: (v) => setState(() {
                      _autopista = v;
                      _pagina = 0;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (filtrados.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No hay pórticos que coincidan.')),
                )
              else
                TablaSimple(
                  encabezados: const ['Pórtico', 'Autopista', 'Tarifa', ''],
                  anchos: const [230, 170, 150],
                  filas: [
                    for (final p in pagina)
                      [
                        Row(
                          children: [
                            const IconoCuadro(Icons.location_on_outlined),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (p.nombre.isNotEmpty)
                                    Text(
                                      p.nombre,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: kTinta,
                                      ),
                                    ),
                                  Text(
                                    p.etiquetaCodigo,
                                    style: const TextStyle(
                                      color: kGris,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          p.autopista,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kTinta, fontSize: 14.5),
                        ),
                        p.tieneTarifa
                            ? const Pildora(
                                'Configurada',
                                fondo: Color(0xFFECFDF5),
                                colorTexto: kVerde,
                                borde: Color(0xFFA7F3D0),
                                icono: Icons.check_circle_outline,
                              )
                            : const Pildora(
                                'Pendiente',
                                fondo: Color(0xFFF8FAFC),
                                colorTexto: kGris,
                                borde: kBorde,
                                icono: Icons.hourglass_empty,
                              ),
                        TextButton.icon(
                          onPressed: () => _editar(p),
                          icon: Icon(
                            p.tieneTarifa ? Icons.edit_outlined : Icons.add,
                            size: 17,
                          ),
                          label: Text(p.tieneTarifa ? 'Editar tarifas' : 'Agregar tarifas'),
                          style: TextButton.styleFrom(
                            foregroundColor: kTinta,
                            textStyle: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                  ],
                ),
              const Divider(),
              Paginador(
                pagina: _pagina,
                porPagina: _porPagina,
                total: filtrados.length,
                etiqueta: 'pórticos',
                onPagina: (n) => setState(() => _pagina = n),
                onPorPagina: (n) => setState(() {
                  _porPagina = n;
                  _pagina = 0;
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Panel lateral para editar las tarifas de un pórtico.
class _PanelTarifas extends StatefulWidget {
  const _PanelTarifas({required this.p});

  final PorticoAdmin p;

  @override
  State<_PanelTarifas> createState() => _PanelTarifasState();
}

class _PanelTarifasState extends State<_PanelTarifas> {
  late final TextEditingController _base = TextEditingController(text: _t(widget.p.tarifaBase));
  late final TextEditingController _punta = TextEditingController(text: _t(widget.p.tarifaPunta));
  late final TextEditingController _sat = TextEditingController(text: _t(widget.p.tarifaSaturacion));
  String? _error;

  static String _t(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  @override
  void dispose() {
    _base.dispose();
    _punta.dispose();
    _sat.dispose();
    super.dispose();
  }

  double? _v(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _guardar() {
    final b = _v(_base);
    final pu = _v(_punta);
    final s = _v(_sat);
    if (b == null || pu == null || s == null || b < 0 || pu < 0 || s < 0) {
      setState(() => _error = 'Ingresa valores numéricos válidos (0 o más).');
      return;
    }
    Navigator.of(context).pop((base: b, punta: pu, sat: s));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Column(
      children: [
        CabeceraPanel(
          titulo: widget.p.tieneTarifa ? 'Editar tarifas' : 'Agregar tarifas',
          subtitulo: const Text(
            'Valores de cobro de este pórtico según el horario en que se cruza.',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorde),
                ),
                child: Row(
                  children: [
                    const IconoCuadro(Icons.location_on_outlined, tam: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nombre.isEmpty ? p.etiquetaCodigo : p.nombre,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: kTinta,
                            ),
                          ),
                          Text(
                            '${p.etiquetaCodigo} · ${p.autopista}',
                            style: const TextStyle(color: kGris, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CampoEtiquetado(
                etiqueta: 'Tarifa base',
                horario: 'Resto del día y fines de semana (fuera de punta)',
                controller: _base,
                hint: 'Ej: 500',
                numerico: true,
                sufijo: '\$',
                monoespaciado: true,
                autofocus: true,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 18),
              CampoEtiquetado(
                etiqueta: 'Tarifa punta',
                horario: 'Lun a vie · 07:00 a 09:00 y 17:30 a 20:00',
                controller: _punta,
                hint: 'Ej: 900',
                numerico: true,
                sufijo: '\$',
                monoespaciado: true,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 18),
              CampoEtiquetado(
                etiqueta: 'Tarifa saturación',
                horario: 'Lun a vie · 08:00 a 09:00 y 18:00 a 19:00 (reemplaza a la punta)',
                controller: _sat,
                hint: 'Ej: 1200',
                numerico: true,
                sufijo: '\$',
                monoespaciado: true,
                error: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 10),
              const Text(
                'Los horarios son los que usa la app del conductor para calcular el costo de cada pórtico. Los montos van en pesos chilenos.',
                style: TextStyle(color: kGris, fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
        PiePanel(
          textoPrincipal: 'Guardar tarifas',
          iconoPrincipal: Icons.save_outlined,
          onPrincipal: _guardar,
        ),
      ],
    );
  }
}
