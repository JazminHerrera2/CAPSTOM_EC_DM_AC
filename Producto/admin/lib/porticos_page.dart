import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';
import 'dashboard_page.dart' show GrillaTarjetas, TarjetaDato;
import 'porticos_paneles.dart';

class PorticosPage extends StatefulWidget {
  const PorticosPage({super.key, required this.service, this.onIrA});

  final AdminFirestoreService service;
  final void Function(String titulo)? onIrA;

  @override
  State<PorticosPage> createState() => _PorticosPageState();
}

class _PorticosPageState extends State<PorticosPage> {
  final TextEditingController _busqueda = TextEditingController();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      widget.service.streamPorticos();
  String _autopista = 'Todas';
  String _estado = 'Todos';
  int _pagina = 0;
  int _porPagina = 10;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _concesionarias = const [];
  List<String> _autopistasEnPorticos = const [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subConc;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() => _pagina = 0));
    // Si la colección aún no tiene reglas publicadas, se usan solo los pórticos.
    _subConc = widget.service.streamConcesionarias().listen(
      (s) {
        if (mounted) setState(() => _concesionarias = s.docs);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _subConc?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  /// Autopistas que se pueden elegir: concesionarias registradas + las que ya
  /// aparecen en algún pórtico.
  List<String> _autopistasDisponibles() {
    final nombres = <String>{
      for (final d in _concesionarias)
        (d.data()['nombre'] ?? d.id).toString(),
      ..._autopistasEnPorticos,
    }..removeWhere((e) => e.trim().isEmpty);
    return nombres.toList()..sort();
  }

  String _codigoAutopista(String nombre) {
    for (final d in _concesionarias) {
      if ((d.data()['nombre'] ?? d.id).toString() == nombre) {
        return (d.data()['codigo'] ?? '').toString();
      }
    }
    return '';
  }

  Future<void> _alternar(PorticoAdmin p) async {
    final nuevo = !p.activo;
    try {
      await p.actualizar({'activo': nuevo});
      await widget.service.logAction(
        action: nuevo ? 'ACTIVATE_PORTICO' : 'DEACTIVATE_PORTICO',
        target: p.nombre,
        details:
            '${nuevo ? 'Activó' : 'Desactivó'} el pórtico ${p.etiquetaCodigo} (${p.nombre})',
      );
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo cambiar el estado: $e', error: true);
    }
  }

  Future<void> _eliminar(PorticoAdmin p) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar pórtico',
      mensaje:
          '¿Eliminar el pórtico ${p.etiquetaCodigo} (${p.nombre})? Esta acción es irreversible.',
      confirmar: 'Sí, eliminar',
      peligro: true,
    );
    if (!ok) return;
    try {
      await p.doc.reference.delete();
      await widget.service.logAction(
        action: 'DELETE_PORTICO',
        target: p.nombre,
        details: 'Eliminó el pórtico ${p.etiquetaCodigo} (${p.nombre})',
      );
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo eliminar: $e', error: true);
    }
  }

  Future<void> _formulario({PorticoAdmin? p}) async {
    final r = await mostrarPanelPortico(
      context,
      autopistas: _autopistasDisponibles(),
      autopista: p?.autopista,
      codigo: p?.codigo ?? '',
      sentido: p?.sentido ?? '',
      nombre: p?.nombre ?? '',
      lat: p?.lat,
      lng: p?.lng,
      edicion: p != null,
    );
    if (r == null) return;
    final codigoAutopista = _codigoAutopista(r.autopista);
    final campos = <String, dynamic>{
      'nombre': r.nombre,
      'codigo': r.codigo,
      'autopista': r.autopista,
      if (codigoAutopista.isNotEmpty) 'autopista_codigo': codigoAutopista,
      'sentido': r.sentido,
      'lat': r.lat,
      'lng': r.lng,
    };
    try {
      if (p == null) {
        await widget.service.firestore.collection('porticos').add({
          ...campos,
          'activo': true,
          'tarifa_base': 0,
          'tarifa_punta': 0,
          'tarifa_saturacion': 0,
        });
        await widget.service.logAction(
          action: 'CREATE_PORTICO',
          target: r.nombre,
          details: 'Creó el pórtico ${r.codigo} (${r.nombre}) en ${r.autopista}',
        );
        if (mounted) avisar(context, 'Pórtico creado.');
      } else {
        await p.actualizar(campos);
        await widget.service.logAction(
          action: 'UPDATE_PORTICO',
          target: r.nombre,
          details: 'Actualizó el pórtico ${p.etiquetaCodigo} (${r.nombre})',
        );
        if (mounted) avisar(context, 'Pórtico actualizado.');
      }
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo guardar el pórtico: $e', error: true);
    }
  }

  Future<void> _reajuste(List<PorticoAdmin> todos, String alcanceInicial) async {
    final r = await mostrarPanelReajuste(
      context,
      autopistas: _autopistasDisponibles(),
      alcanceInicial: alcanceInicial,
      contar: (a) => a == 'Todas'
          ? todos.length
          : todos.where((p) => p.autopista == a).length,
    );
    if (r == null) return;
    final lista = r.alcance == 'Todas'
        ? todos
        : todos.where((p) => p.autopista == r.alcance).toList();
    final factor = 1 + r.porcentaje / 100;
    double redondea(double x) => (x * factor * 100).round() / 100;
    try {
      final db = widget.service.firestore;
      var batch = db.batch();
      var n = 0;
      for (final p in lista) {
        final pre = p.anidado ? 'datos.' : '';
        batch.update(p.doc.reference, {
          '${pre}tarifa_base': redondea(p.tarifaBase),
          '${pre}tarifa_punta': redondea(p.tarifaPunta),
          '${pre}tarifa_saturacion': redondea(p.tarifaSaturacion),
        });
        if (++n % 400 == 0) {
          await batch.commit();
          batch = db.batch();
        }
      }
      await batch.commit();
      await widget.service.logAction(
        action: 'REAJUSTE_MASIVO_IPC',
        target: r.alcance == 'Todas' ? 'Todas las autopistas' : r.alcance,
        details: 'Reajuste del ${r.porcentaje}% aplicado a ${lista.length} pórticos.',
      );
      if (mounted) avisar(context, 'Reajuste aplicado a ${lista.length} pórticos.');
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo aplicar el reajuste: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error al leer Firestore: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
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
        _autopistasEnPorticos = autopistas;
        final autopistaSel = autopistas.contains(_autopista) ? _autopista : 'Todas';

        final q = _busqueda.text.toLowerCase().trim();
        final filtrados = todos.where((p) {
          if (autopistaSel != 'Todas' && p.autopista != autopistaSel) return false;
          if (_estado == 'Vigentes' && !p.activo) return false;
          if (_estado == 'Inactivos' && p.activo) return false;
          if (q.isEmpty) return true;
          return p.nombre.toLowerCase().contains(q) ||
              p.codigo.toLowerCase().contains(q) ||
              p.autopista.toLowerCase().contains(q);
        }).toList();

        final paginas = (filtrados.length / _porPagina).ceil();
        if (_pagina >= paginas && paginas > 0) _pagina = paginas - 1;
        final desde = _pagina * _porPagina;
        final hasta = (desde + _porPagina).clamp(0, filtrados.length);
        final pagina = filtrados.sublist(desde, hasta);
        final vigentes = todos.where((p) => p.activo).length;
        final compact = MediaQuery.sizeOf(context).width < 820;

        return SafeArea(
          child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
                  titulo: 'Pórticos',
                  subtitulo:
                      'Registra y mantiene los pórticos de cada autopista concesionada.',
                  acciones: [
                    BotonContorno(
                      texto: 'Actualizar',
                      icono: Icons.refresh,
                      onPressed: () => setState(
                        () => _stream = widget.service.streamPorticos(),
                      ),
                    ),
                    BotonContorno(
                      texto: 'Reajuste IPC',
                      icono: Icons.percent,
                      onPressed: () => _reajuste(todos, autopistaSel),
                    ),
                    BotonContorno(
                      texto: 'Carga masiva',
                      icono: Icons.upload_outlined,
                      onPressed: () => mostrarPanelCargaPorticos(context, widget.service),
                    ),
                    BotonPrimario(
                      texto: 'Nuevo pórtico',
                      icono: Icons.add,
                      onPressed: () => _formulario(),
                    ),
                  ],
                ),
            children: [

                GrillaTarjetas(
                  tarjetas: [
                    TarjetaDato(
                      etiqueta: 'Total',
                      valor: '${todos.length}',
                      icono: Icons.location_on_outlined,
                    ),
                    TarjetaDato(
                      etiqueta: 'Vigentes',
                      valor: '$vigentes',
                      icono: Icons.power_settings_new,
                    ),
                    TarjetaDato(
                      etiqueta: 'Inactivos',
                      valor: '${todos.length - vigentes}',
                      icono: Icons.block,
                    ),
                    TarjetaDato(
                      etiqueta: 'Autopistas',
                      valor: '${autopistas.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TarjetaBlanca(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CabeceraListado(
                        titulo: 'Listado',
                        subtitulo:
                            '${filtrados.length} de ${todos.length} pórticos',
                        controles: [
                          CampoBusqueda(
                            controller: _busqueda,
                            hint: 'Buscar por nombre, código o autopista…',
                            ancho: 300,
                          ),
                          DesplegableFiltro(
                            valor: autopistaSel,
                            opciones: ['Todas', ...autopistas],
                            etiquetas: const {'Todas': 'Todas las autopistas'},
                            ancho: 210,
                            onChanged: (v) => setState(() {
                              _autopista = v;
                              _pagina = 0;
                            }),
                          ),
                          DesplegableFiltro(
                            valor: _estado,
                            opciones: const ['Todos', 'Vigentes', 'Inactivos'],
                            ancho: 140,
                            onChanged: (v) => setState(() {
                              _estado = v;
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
                          encabezados: const [
                            'Pórtico',
                            'Autopista',
                            'Sentido',
                            'Coordenadas',
                            'Estado',
                            '',
                          ],
                          anchos: const [190, 90, 200, 120, 130],
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
                                p.sentido.isEmpty
                                    ? const Text('—')
                                    : Pildora(p.sentido),
                                Text(
                                  (p.lat != null && p.lng != null)
                                      ? '${p.lat!.toStringAsFixed(5)}, ${p.lng!.toStringAsFixed(5)}'
                                      : '—',
                                  style: const TextStyle(
                                    color: kGris,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                p.activo
                                    ? const Pildora(
                                        'Vigente',
                                        fondo: Color(0xFFECFDF5),
                                        colorTexto: kVerde,
                                        borde: Color(0xFFA7F3D0),
                                      )
                                    : const Pildora(
                                        'Inactivo',
                                        fondo: Color(0xFFF1F5F9),
                                        colorTexto: kGris,
                                        borde: kBorde,
                                      ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: p.activo ? 'Desactivar' : 'Activar',
                                      icon: Icon(
                                        Icons.power_settings_new,
                                        size: 20,
                                        color: p.activo ? kVerde : kGris,
                                      ),
                                      onPressed: () => _alternar(p),
                                    ),
                                    IconButton(
                                      tooltip: 'Editar',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                        color: kTinta,
                                      ),
                                      onPressed: () => _formulario(p: p),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _eliminar(p),
                                    ),
                                  ],
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
                ),
              
            ],
          ),
        );
      },
    );
  }
}
