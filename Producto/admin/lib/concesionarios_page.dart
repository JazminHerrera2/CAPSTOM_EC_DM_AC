import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';
import 'dashboard_page.dart' show GrillaTarjetas, TarjetaDato;
import 'file_downloader.dart';
import 'importar_panel.dart';
import 'mapa_page.dart' show capaBaseMapa;
import 'porticos_paneles.dart' show CabeceraPanel, CampoEtiquetado, PiePanel;

/// Una autopista concesionada con sus pórticos.
class Concesionaria {
  Concesionaria({
    required this.nombre,
    required this.codigo,
    required this.porticos,
    this.docId,
  });

  final String nombre;
  final String codigo;
  final List<PorticoAdmin> porticos;

  /// Id del documento en `concesionarias` (null si solo existe por sus pórticos).
  final String? docId;

  /// Id seguro para usar como nombre de archivo o documento.
  String get clave {
    final base = codigo.isNotEmpty ? codigo : nombre;
    return base
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

String _normaliza(String s) => s.toLowerCase().trim();

/// Une el catálogo `concesionarias` con las autopistas que solo aparecen en
/// los pórticos.
List<Concesionaria> armarConcesionarias(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  List<PorticoAdmin> porticos,
) {
  final resultado = <Concesionaria>[];
  final usados = <String>{};

  for (final doc in docs) {
    final d = doc.data();
    final nombre = (d['nombre'] ?? doc.id).toString();
    final codigo = (d['codigo'] ?? '').toString();
    final propios = porticos.where((p) {
      if (codigo.isNotEmpty && p.autopistaCodigo == codigo) return true;
      return _normaliza(p.autopista) == _normaliza(nombre);
    }).toList();
    usados.addAll(propios.map((p) => p.id));
    resultado.add(
      Concesionaria(
        nombre: nombre,
        codigo: codigo,
        porticos: propios,
        docId: doc.id,
      ),
    );
  }

  final huerfanos = <String, List<PorticoAdmin>>{};
  for (final p in porticos) {
    if (usados.contains(p.id) || p.autopista.isEmpty) continue;
    huerfanos.putIfAbsent(p.autopista, () => []).add(p);
  }
  for (final e in huerfanos.entries) {
    resultado.add(
      Concesionaria(
        nombre: e.key,
        codigo: e.value.first.autopistaCodigo,
        porticos: e.value,
      ),
    );
  }
  resultado.sort((a, b) => a.nombre.compareTo(b.nombre));
  return resultado;
}

/// JSON de respaldo de una concesionaria (mismo formato que acepta la carga
/// masiva).
String exportarConcesionariaJson(Concesionaria c, DateTime ahora) {
  final mapa = {
    'codigo': c.codigo,
    'nombre': c.nombre,
    'exportado': ahora.toIso8601String(),
    'porticos': [
      for (final p in c.porticos)
        {
          'codigo': p.etiquetaCodigo,
          'nombre': p.nombre,
          'sentido': p.sentido,
          'lat': p.lat,
          'lng': p.lng,
          'activo': p.activo,
          'tarifa_base': p.tarifaBase,
          'tarifa_punta': p.tarifaPunta,
          'tarifa_saturacion': p.tarifaSaturacion,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(mapa);
}

class ConcesionariosPage extends StatefulWidget {
  const ConcesionariosPage({super.key, required this.service, this.onIrA});

  final AdminFirestoreService service;

  /// Navega a otra sección del menú por su título (p. ej. "Carga masiva").
  final void Function(String titulo)? onIrA;

  @override
  State<ConcesionariosPage> createState() => _ConcesionariosPageState();
}

class _ConcesionariosPageState extends State<ConcesionariosPage> {
  final SuscripcionesMultiples _subs = SuscripcionesMultiples();
  final TextEditingController _busqueda = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _concesionarias;
  List<PorticoAdmin>? _porticos;
  Object? _error;
  int _pagina = 0;
  int _porPagina = 10;

  @override
  void initState() {
    super.initState();
    _suscribir();
    _busqueda.addListener(() => setState(() => _pagina = 0));
  }

  @override
  void dispose() {
    _subs.cancelar();
    _busqueda.dispose();
    super.dispose();
  }

  void _suscribir() {
    _subs.escuchar(widget.service.streamPorticos(), (snap) {
      if (!mounted) return;
      setState(() => _porticos = snap.docs.map(PorticoAdmin.new).toList());
    }, alError: (e) {
      if (mounted) setState(() => _error = e);
    });
    // Si la colección aún no existe en las reglas, se sigue con lo que hay
    // en los pórticos.
    _subs.escuchar(widget.service.streamConcesionarias(), (snap) {
      if (!mounted) return;
      setState(() => _concesionarias = snap.docs);
    }, alError: (_) {
      if (mounted) setState(() => _concesionarias = const []);
    });
  }

  void _actualizar() {
    _subs.cancelar();
    setState(() {
      _concesionarias = null;
      _porticos = null;
    });
    _suscribir();
  }

  Future<void> _nueva() async {
    final r = await mostrarPanelLateral<({String nombre, String codigo})>(
      context,
      ancho: 440,
      builder: (_) => const _PanelNuevaConcesionaria(),
    );
    if (r == null) return;
    final n = r.nombre;
    final c = r.codigo;
    final id = Concesionaria(
      nombre: n,
      codigo: c,
      porticos: const [],
    ).clave;
    try {
      await widget.service.firestore.collection('concesionarias').doc(id).set({
        'nombre': n,
        'codigo': c,
      });
      await widget.service.logAction(
        action: 'CREATE_CONCESIONARIA',
        target: n,
        details: 'Creó la concesionaria $n${c.isEmpty ? '' : ' ($c)'}',
      );
      if (mounted) avisar(context, 'Concesionaria creada.');
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo crear: $e', error: true);
    }
  }

  Future<void> _eliminar(Concesionaria c) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar concesionaria',
      mensaje:
          '¿Eliminar "${c.nombre}" y sus ${c.porticos.length} pórticos? Esta acción es irreversible.',
      confirmar: 'Sí, eliminar',
      peligro: true,
    );
    if (!ok) return;
    try {
      final db = widget.service.firestore;
      var batch = db.batch();
      var n = 0;
      for (final p in c.porticos) {
        batch.delete(p.doc.reference);
        if (++n % 400 == 0) {
          await batch.commit();
          batch = db.batch();
        }
      }
      if (c.docId != null) {
        batch.delete(db.collection('concesionarias').doc(c.docId));
      }
      await batch.commit();
      await widget.service.logAction(
        action: 'DELETE_CONCESIONARIA',
        target: c.nombre,
        details:
            'Eliminó la concesionaria ${c.nombre} y ${c.porticos.length} pórticos.',
      );
      if (mounted) avisar(context, 'Concesionaria eliminada.');
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo eliminar: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error al leer Firestore: $_error'));
    }
    if (_porticos == null || _concesionarias == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final todas = armarConcesionarias(_concesionarias!, _porticos!);
    final q = _normaliza(_busqueda.text);
    final filtradas = todas.where((c) {
      if (q.isEmpty) return true;
      return _normaliza(c.nombre).contains(q) || _normaliza(c.codigo).contains(q);
    }).toList();

    final paginas = (filtradas.length / _porPagina).ceil();
    if (_pagina >= paginas && paginas > 0) _pagina = paginas - 1;
    final desde = _pagina * _porPagina;
    final hasta = (desde + _porPagina).clamp(0, filtradas.length);
    final pagina = filtradas.sublist(desde, hasta);
    final compact = MediaQuery.sizeOf(context).width < 820;

    return SafeArea(
      child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
              titulo: 'Concesionarios',
              subtitulo:
                  'Administra las autopistas concesionadas y sus pórticos asociados.',
              acciones: [
                BotonContorno(
                  texto: 'Actualizar',
                  icono: Icons.refresh,
                  onPressed: _actualizar,
                ),
                BotonContorno(
                  texto: 'Importar JSON',
                  icono: Icons.upload_outlined,
                  onPressed: () => mostrarPanelImportarConcesionarias(context, widget.service),
                ),
                BotonPrimario(
                  texto: 'Nueva concesionaria',
                  icono: Icons.add,
                  onPressed: _nueva,
                ),
              ],
            ),
            children: [

            GrillaTarjetas(
              tarjetas: [
                TarjetaDato(
                  etiqueta: 'Total',
                  valor: '${todas.length}',
                  detalle: 'autopistas registradas',
                  icono: Icons.apartment_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Pórticos totales',
                  valor: '${_porticos!.length}',
                  detalle: 'en todas las autopistas',
                  icono: Icons.location_on_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Con tarifa',
                  valor: '${_porticos!.where((p) => p.tieneTarifa).length}',
                  detalle: 'pórticos con tarifa configurada',
                  icono: Icons.sell_outlined,
                  valorColor: kVerde,
                ),
                TarjetaDato(
                  etiqueta: 'Sin tarifa',
                  valor: '${_porticos!.where((p) => !p.tieneTarifa).length}',
                  detalle: 'pendientes de configurar',
                  icono: Icons.hourglass_empty,
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
                    subtitulo: '${filtradas.length} de ${todas.length} autopistas',
                    controles: [
                      CampoBusqueda(
                        controller: _busqueda,
                        hint: 'Buscar por nombre o código…',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filtradas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No hay concesionarias que coincidan.'),
                      ),
                    )
                  else
                    TablaSimple(
                      encabezados: const [
                        'Autopista',
                        'Código',
                        'Pórticos',
                        '',
                      ],
                      anchos: const [150, 130, 60],
                      onTapFila: (i) => _abrirDetalle(pagina[i]),
                      filas: [
                        for (final c in pagina)
                          [
                            Row(
                              children: [
                                const IconoCuadro(Icons.apartment_outlined),
                                const SizedBox(width: 14),
                                Flexible(
                                  child: Text(
                                    c.nombre,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: kTinta,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(c.codigo, style: const TextStyle(color: kTinta)),
                            Text('${c.porticos.length}'),
                            IconButton(
                              tooltip: 'Eliminar concesionaria',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _eliminar(c),
                            ),
                          ],
                      ],
                    ),
                  const Divider(),
                  Paginador(
                    pagina: _pagina,
                    porPagina: _porPagina,
                    total: filtradas.length,
                    etiqueta: 'autopistas',
                    onPagina: (p) => setState(() => _pagina = p),
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
  }

  void _abrirDetalle(Concesionaria c) {
    mostrarPanelLateral<void>(
      context,
      ancho: 520,
      builder: (ctx) => _DetalleConcesionaria(concesionaria: c),
    );
  }
}

class _DetalleConcesionaria extends StatelessWidget {
  const _DetalleConcesionaria({required this.concesionaria});

  final Concesionaria concesionaria;

  void _exportar(BuildContext context) {
    final ahora = DateTime.now();
    final c = concesionaria;
    final nombreArchivo = '${c.clave.isEmpty ? 'concesionaria' : c.clave}_${fechaIso(ahora)}.json';
    saveFile(exportarConcesionariaJson(c, ahora), nombreArchivo);
    avisar(context, 'Se descargó $nombreArchivo');
  }

  @override
  Widget build(BuildContext context) {
    final c = concesionaria;
    final conUbicacion = c.porticos
        .where((p) => p.lat != null && p.lng != null)
        .toList();
    final puntos = conUbicacion.map((p) => LatLng(p.lat!, p.lng!)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: kTinta,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: kBorde),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(child: _Cifra('PÓRTICOS', '${c.porticos.length}')),
                    const VerticalDivider(width: 1, color: kBorde),
                    Expanded(
                      child: _Cifra(
                        'CON TARIFA',
                        '${c.porticos.where((p) => p.tieneTarifa).length}',
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kBorde),
              if (puntos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 260,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: puntos.first,
                          initialZoom: 13,
                          initialCameraFit: puntos.length > 1
                              ? CameraFit.bounds(
                                  bounds: LatLngBounds.fromPoints(puntos),
                                  padding: const EdgeInsets.all(36),
                                  maxZoom: 15,
                                )
                              : null,
                        ),
                        children: [
                          capaBaseMapa(),
                          MarkerLayer(
                            markers: [
                              for (final p in puntos)
                                Marker(
                                  point: p,
                                  width: 30,
                                  height: 36,
                                  alignment: Alignment.topCenter,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: kAzul,
                                    size: 32,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Ningún pórtico de esta autopista tiene coordenadas.',
                    style: TextStyle(color: kGris),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'PÓRTICOS (${c.porticos.length})',
                  style: const TextStyle(
                    color: kGris,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              for (final p in c.porticos) _FilaPortico(p: p),
              const SizedBox(height: 12),
            ],
          ),
        ),
        const Divider(height: 1, color: kBorde),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: BotonContorno(
                  texto: 'Exportar configuración (JSON)',
                  icono: Icons.download_outlined,
                  onPressed: () => _exportar(context),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Respaldo del estado actual de la autopista. Incluye el código y la fecha en el nombre del archivo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kGris, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            color: kGris,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: kTinta,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _FilaPortico extends StatelessWidget {
  const _FilaPortico({required this.p});

  final PorticoAdmin p;

  @override
  Widget build(BuildContext context) {
    final coords = (p.lat != null && p.lng != null)
        ? '${p.lat!.toStringAsFixed(5)}, ${p.lng!.toStringAsFixed(5)}'
        : 'sin coordenadas';
    final reglas = p.reglasTarifarias;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorde),
      ),
      child: Row(
        children: [
          const IconoCuadro(Icons.location_on_outlined, tam: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.etiquetaCodigo,
                      style: const TextStyle(
                        color: kGris,
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (p.sentido.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Pildora(p.sentido),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  p.nombre,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: kTinta,
                  ),
                ),
                Text(
                  '$coords · ${reglas == 0 ? 'sin reglas tarifarias' : reglas == 1 ? '1 regla tarifaria' : '$reglas reglas tarifarias'}',
                  style: const TextStyle(color: kGris, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Panel lateral para registrar una concesionaria con sus datos básicos.
class _PanelNuevaConcesionaria extends StatefulWidget {
  const _PanelNuevaConcesionaria();

  @override
  State<_PanelNuevaConcesionaria> createState() => _PanelNuevaConcesionariaState();
}

class _PanelNuevaConcesionariaState extends State<_PanelNuevaConcesionaria> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _codigo = TextEditingController();
  String? _errorNombre;

  @override
  void dispose() {
    _nombre.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _crear() {
    final n = _nombre.text.trim();
    if (n.isEmpty) {
      setState(() => _errorNombre = 'El nombre es obligatorio.');
      return;
    }
    Navigator.of(context).pop((
      nombre: n,
      codigo: _codigo.text.trim().toUpperCase(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CabeceraPanel(
          titulo: 'Nueva concesionaria',
          subtitulo: Text(
            'Registra la autopista con sus datos básicos. Sus pórticos se agregan después desde la sección Pórticos.',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              CampoEtiquetado(
                etiqueta: 'Nombre',
                controller: _nombre,
                hint: 'Ej: Costanera Norte',
                autofocus: true,
                error: _errorNombre,
                onChanged: (_) {
                  if (_errorNombre != null) setState(() => _errorNombre = null);
                },
              ),
              const SizedBox(height: 18),
              CampoEtiquetado(
                etiqueta: 'Código',
                controller: _codigo,
                hint: 'Ej: ACN',
                monoespaciado: true,
              ),
            ],
          ),
        ),
        PiePanel(
          textoPrincipal: 'Crear concesionaria',
          iconoPrincipal: Icons.add,
          onPrincipal: _crear,
        ),
      ],
    );
  }
}
