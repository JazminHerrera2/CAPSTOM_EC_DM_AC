import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';
import 'carga_masiva_page.dart';
import 'file_downloader.dart';

// ---------------------------------------------------------------------------
// Piezas comunes de los paneles laterales
// ---------------------------------------------------------------------------

/// Cabecera de un panel lateral: título, subtítulo y botón de cerrar.
class CabeceraPanel extends StatelessWidget {
  const CabeceraPanel({super.key, required this.titulo, required this.subtitulo});

  final String titulo;
  final Widget subtitulo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: kTinta,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: const TextStyle(color: kGris, fontSize: 14, height: 1.35),
                    child: subtitulo,
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
    ],
  );
}

/// Pie de un panel lateral: Cancelar a la izquierda del botón principal.
class PiePanel extends StatelessWidget {
  const PiePanel({
    super.key,
    required this.textoPrincipal,
    required this.iconoPrincipal,
    required this.onPrincipal,
  });

  final String textoPrincipal;
  final IconData iconoPrincipal;
  final VoidCallback? onPrincipal;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Divider(height: 1, color: kBorde),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 10),
            BotonPrimario(
              texto: textoPrincipal,
              icono: iconoPrincipal,
              onPressed: onPrincipal,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Campo con la etiqueta encima, como en los formularios de los paneles.
class CampoEtiquetado extends StatelessWidget {
  const CampoEtiquetado({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.hint,
    this.monoespaciado = false,
    this.numerico = false,
    this.error,
    this.onChanged,
    this.autofocus = false,
    this.sufijo,
    this.maxLines = 1,
    this.oculto = false,
    this.teclado,
    this.horario,
  });

  final String etiqueta;
  final TextEditingController controller;
  final String hint;
  final bool monoespaciado;
  final bool numerico;
  final String? error;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String? sufijo;
  final int maxLines;
  final bool oculto;
  final TextInputType? teclado;

  /// Texto con el horario en que aplica (se muestra bajo la etiqueta).
  final String? horario;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        etiqueta,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: kTinta,
        ),
      ),
      if (horario != null) ...[
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.schedule, size: 14, color: kGris),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                horario!,
                style: const TextStyle(color: kGris, fontSize: 12.5, height: 1.3),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        maxLines: oculto ? 1 : maxLines,
        obscureText: oculto,
        keyboardType: teclado ??
            (numerico
                ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                : null),
        style: TextStyle(
          fontSize: 14,
          color: kTinta,
          fontFamily: monoespaciado ? 'monospace' : null,
        ),
        decoration: InputDecoration(
          hintText: hint,
          errorText: error,
          suffixText: sufijo,
          hintStyle: TextStyle(
            color: kGris,
            fontSize: 14,
            fontFamily: monoespaciado ? 'monospace' : null,
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Nuevo / Editar pórtico
// ---------------------------------------------------------------------------

/// Datos que devuelve el panel de pórtico.
typedef DatosPortico = ({
  String autopista,
  String codigo,
  String sentido,
  String nombre,
  double lat,
  double lng,
});

Future<DatosPortico?> mostrarPanelPortico(
  BuildContext context, {
  required List<String> autopistas,
  String? autopista,
  String codigo = '',
  String sentido = '',
  String nombre = '',
  double? lat,
  double? lng,
  bool edicion = false,
}) {
  return mostrarPanelLateral<DatosPortico>(
    context,
    ancho: 460,
    builder: (_) => _PanelPortico(
      autopistas: autopistas,
      autopista: autopista,
      codigo: codigo,
      sentido: sentido,
      nombre: nombre,
      lat: lat,
      lng: lng,
      edicion: edicion,
    ),
  );
}

class _PanelPortico extends StatefulWidget {
  const _PanelPortico({
    required this.autopistas,
    required this.autopista,
    required this.codigo,
    required this.sentido,
    required this.nombre,
    required this.lat,
    required this.lng,
    required this.edicion,
  });

  final List<String> autopistas;
  final String? autopista;
  final String codigo;
  final String sentido;
  final String nombre;
  final double? lat;
  final double? lng;
  final bool edicion;

  @override
  State<_PanelPortico> createState() => _PanelPorticoState();
}

class _PanelPorticoState extends State<_PanelPortico> {
  late final TextEditingController _codigo = TextEditingController(text: widget.codigo);
  late final TextEditingController _sentido = TextEditingController(text: widget.sentido);
  late final TextEditingController _nombre = TextEditingController(text: widget.nombre);
  late final TextEditingController _lat = TextEditingController(text: widget.lat?.toString() ?? '');
  late final TextEditingController _lng = TextEditingController(text: widget.lng?.toString() ?? '');
  late String? _autopista = widget.autopista;
  String? _errorAutopista;
  String? _errorNombre;
  String? _errorLat;
  String? _errorLng;

  @override
  void dispose() {
    _codigo.dispose();
    _sentido.dispose();
    _nombre.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _guardar() {
    final la = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lo = double.tryParse(_lng.text.trim().replaceAll(',', '.'));
    setState(() {
      _errorAutopista = _autopista == null ? 'Selecciona una autopista.' : null;
      _errorNombre = _nombre.text.trim().isEmpty ? 'El nombre es obligatorio.' : null;
      _errorLat = (la == null || la.abs() > 90) ? 'Latitud no válida.' : null;
      _errorLng = (lo == null || lo.abs() > 180) ? 'Longitud no válida.' : null;
    });
    if (_errorAutopista != null ||
        _errorNombre != null ||
        _errorLat != null ||
        _errorLng != null) {
      return;
    }
    Navigator.of(context).pop((
      autopista: _autopista!,
      codigo: _codigo.text.trim().toUpperCase(),
      sentido: _sentido.text.trim().toUpperCase(),
      nombre: _nombre.text.trim(),
      lat: la!,
      lng: lo!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CabeceraPanel(
          titulo: widget.edicion ? 'Editar pórtico' : 'Nuevo pórtico',
          subtitulo: Text(
            widget.edicion
                ? 'Modifica los datos del pórtico.'
                : 'Registra un pórtico y asócialo a una autopista concesionada.',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              const Text(
                'Autopista',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTinta,
                ),
              ),
              const SizedBox(height: 6),
              SelectorAcordeon(
                valor: _autopista,
                hint: widget.autopistas.isEmpty
                    ? 'Primero crea una concesionaria'
                    : 'Selecciona una autopista',
                opciones: widget.autopistas,
                deshabilitado: widget.autopistas.isEmpty,
                compacto: true,
                onChanged: (v) => setState(() {
                  _autopista = v;
                  _errorAutopista = null;
                }),
              ),
              if (_errorAutopista != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    _errorAutopista!,
                    style: const TextStyle(color: kRojo, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoEtiquetado(
                      etiqueta: 'Código',
                      controller: _codigo,
                      hint: 'Ej: P0',
                      monoespaciado: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: CampoEtiquetado(
                      etiqueta: 'Sentido',
                      controller: _sentido,
                      hint: 'Ej: PO / N-S',
                      monoespaciado: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              CampoEtiquetado(
                etiqueta: 'Nombre',
                controller: _nombre,
                hint: 'Ej: P. San Francisco',
                error: _errorNombre,
                onChanged: (_) {
                  if (_errorNombre != null) setState(() => _errorNombre = null);
                },
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoEtiquetado(
                      etiqueta: 'Latitud',
                      controller: _lat,
                      hint: '-33.371363',
                      monoespaciado: true,
                      numerico: true,
                      error: _errorLat,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: CampoEtiquetado(
                      etiqueta: 'Longitud',
                      controller: _lng,
                      hint: '-70.523380',
                      monoespaciado: true,
                      numerico: true,
                      error: _errorLng,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        PiePanel(
          textoPrincipal: widget.edicion ? 'Guardar cambios' : 'Crear pórtico',
          iconoPrincipal: Icons.save_outlined,
          onPrincipal: _guardar,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reajuste masivo de tarifas
// ---------------------------------------------------------------------------

typedef DatosReajuste = ({double porcentaje, String alcance});

Future<DatosReajuste?> mostrarPanelReajuste(
  BuildContext context, {
  required List<String> autopistas,
  required int Function(String alcance) contar,
  String alcanceInicial = 'Todas',
}) {
  return mostrarPanelLateral<DatosReajuste>(
    context,
    ancho: 460,
    builder: (_) => _PanelReajuste(
      autopistas: autopistas,
      contar: contar,
      alcanceInicial: alcanceInicial,
    ),
  );
}

class _PanelReajuste extends StatefulWidget {
  const _PanelReajuste({
    required this.autopistas,
    required this.contar,
    required this.alcanceInicial,
  });

  final List<String> autopistas;
  final int Function(String) contar;
  final String alcanceInicial;

  @override
  State<_PanelReajuste> createState() => _PanelReajusteState();
}

class _PanelReajusteState extends State<_PanelReajuste> {
  final TextEditingController _pct = TextEditingController();
  late String _alcance = widget.autopistas.contains(widget.alcanceInicial) ||
          widget.alcanceInicial == 'Todas'
      ? widget.alcanceInicial
      : 'Todas';
  String? _error;

  @override
  void dispose() {
    _pct.dispose();
    super.dispose();
  }

  double? get _valor => double.tryParse(_pct.text.trim().replaceAll(',', '.'));

  void _aplicar() {
    final v = _valor;
    if (v == null || v <= -100 || v > 100 || v == 0) {
      setState(() => _error = 'Ingresa un porcentaje distinto de 0, entre -100 y 100.');
      return;
    }
    Navigator.of(context).pop((porcentaje: v, alcance: _alcance));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.contar(_alcance);
    final v = _valor;
    return Column(
      children: [
        const CabeceraPanel(
          titulo: 'Reajuste masivo de tarifas',
          subtitulo: Text(
            'Aplica un porcentaje (por ejemplo, IPC) a las tarifas base, punta y saturación.',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              const Text(
                'Alcance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTinta,
                ),
              ),
              const SizedBox(height: 6),
              SelectorAcordeon(
                valor: _alcance,
                opciones: ['Todas', ...widget.autopistas],
                etiquetas: const {'Todas': 'Todas las autopistas'},
                compacto: true,
                onChanged: (x) => setState(() => _alcance = x),
              ),
              const SizedBox(height: 18),
              CampoEtiquetado(
                etiqueta: 'Porcentaje de reajuste',
                controller: _pct,
                hint: 'Ej: 3.5',
                numerico: true,
                sufijo: '%',
                error: _error,
                autofocus: true,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 8),
              const Text(
                'Usa un valor negativo para rebajar las tarifas.',
                style: TextStyle(color: kGris, fontSize: 13),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorde),
                ),
                child: Text(
                  v == null || v == 0
                      ? 'Se modificarán las tarifas de $n pórtico${n == 1 ? '' : 's'}.'
                      : 'Se modificarán las tarifas de $n pórtico${n == 1 ? '' : 's'} (${v > 0 ? '+' : ''}${v.toString()}%).',
                  style: const TextStyle(color: kTinta, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        PiePanel(
          textoPrincipal: 'Aplicar reajuste',
          iconoPrincipal: Icons.percent,
          onPrincipal: n == 0 ? null : _aplicar,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Carga masiva de pórticos
// ---------------------------------------------------------------------------

Future<bool?> mostrarPanelCargaPorticos(
  BuildContext context,
  AdminFirestoreService service,
) {
  return mostrarPanelLateral<bool>(
    context,
    ancho: 520,
    builder: (_) => _PanelCargaPorticos(service: service),
  );
}

class _PanelCargaPorticos extends StatefulWidget {
  const _PanelCargaPorticos({required this.service});

  final AdminFirestoreService service;

  @override
  State<_PanelCargaPorticos> createState() => _PanelCargaPorticosState();
}

class _PanelCargaPorticosState extends State<_PanelCargaPorticos> {
  List<PorticoPorImportar> _validos = [];
  List<String> _errores = [];
  String? _archivo;
  bool _ocupado = false;

  Future<void> _seleccionar() async {
    final textos = await elegirArchivosTexto(context, ['csv', 'json']);
    if (textos.isEmpty || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final r = await validarArchivoPorticos(widget.service, textos.first);
      if (!mounted) return;
      setState(() {
        _validos = r.validos;
        _errores = r.errores;
        _archivo = 'archivo cargado';
      });
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo leer el archivo: $e', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _crear() async {
    setState(() => _ocupado = true);
    try {
      final n = await escribirPorticosImportados(widget.service, _validos);
      if (!mounted) return;
      avisar(context, 'Importados $n pórticos.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        avisar(context, 'No se pudo importar: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CabeceraPanel(
          titulo: 'Carga masiva de pórticos',
          subtitulo: Text.rich(
            TextSpan(
              children: const [
                TextSpan(text: 'Sube un archivo '),
                TextSpan(text: '.json', style: TextStyle(fontFamily: 'monospace')),
                TextSpan(text: ' o '),
                TextSpan(text: '.csv', style: TextStyle(fontFamily: 'monospace')),
                TextSpan(text: '. Cada pórtico se asocia a una autopista por su código.'),
              ],
            ),
          ),
        ),
        if (_ocupado) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              BotonContorno(
                texto: 'Seleccionar archivo',
                icono: Icons.description_outlined,
                onPressed: _ocupado ? null : _seleccionar,
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  saveFile(kPlantillaPorticos, 'plantilla_porticos.csv');
                  avisar(context, 'Se descargó plantilla_porticos.csv');
                },
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Plantilla'),
                style: TextButton.styleFrom(foregroundColor: kTinta),
              ),
            ],
          ),
        ),
        Expanded(
          child: _archivo == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  children: [
                    Text(
                      '${_validos.length} pórtico(s) válidos'
                      '${_errores.isEmpty ? '' : ' · ${_errores.length} fila(s) con problemas'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kTinta,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final p in _validos.take(200))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorde),
                        ),
                        child: Row(
                          children: [
                            const IconoCuadro(Icons.location_on_outlined, tam: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p.codigo}  ${p.nombre}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: kTinta,
                                    ),
                                  ),
                                  Text(
                                    '${p.autopista} · ${p.sentido.isEmpty ? 'sin sentido' : p.sentido} · ${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
                                    style: const TextStyle(color: kGris, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_validos.length > 200)
                      Text(
                        '…y ${_validos.length - 200} más',
                        style: const TextStyle(color: kGris),
                      ),
                    if (_errores.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Filas que no se importarán',
                        style: TextStyle(fontWeight: FontWeight.w600, color: kRojo),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errores.take(40).join('\n') +
                            (_errores.length > 40 ? '\n…y ${_errores.length - 40} más' : ''),
                        style: const TextStyle(color: kRojo, fontSize: 13),
                      ),
                    ],
                  ],
                ),
        ),
        PiePanel(
          textoPrincipal: 'Crear ${_validos.length} pórtico(s)',
          iconoPrincipal: Icons.cloud_upload_outlined,
          onPrincipal: (_validos.isEmpty || _ocupado) ? null : _crear,
        ),
      ],
    );
  }
}
