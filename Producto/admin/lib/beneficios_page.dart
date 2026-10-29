import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'beneficio_imagen_service.dart';

/// Categorías de beneficio (RF-034). Mismo texto que valida firestore.rules y
/// que muestra la app del conductor.
const List<String> categoriasBeneficio = [
  'Combustible',
  'Talleres',
  'Mantenciones',
  'Estacionamientos',
  'Lavado',
  'Neumáticos',
  'Seguros',
  'Accesorios',
  'Otros',
];

IconData _iconoCategoria(String? categoria) {
  switch (categoria) {
    case 'Combustible':
      return Icons.local_gas_station_outlined;
    case 'Talleres':
      return Icons.build_circle_outlined;
    case 'Mantenciones':
      return Icons.handyman_outlined;
    case 'Estacionamientos':
      return Icons.local_parking_outlined;
    case 'Lavado':
      return Icons.local_car_wash_outlined;
    case 'Neumáticos':
      return Icons.tire_repair_outlined;
    case 'Seguros':
      return Icons.shield_outlined;
    case 'Accesorios':
      return Icons.shopping_bag_outlined;
    case 'Otros':
      return Icons.category_outlined;
    default:
      return Icons.card_giftcard_outlined;
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

/// Administración del catálogo de beneficios (RF-031, RF-032, RF-034):
/// crear, editar, activar/desactivar, destacar y eliminar. Cada cambio queda
/// en la auditoría del panel.
class BeneficiosPage extends StatefulWidget {
  const BeneficiosPage({super.key, required this.service});

  final AdminFirestoreService service;

  @override
  State<BeneficiosPage> createState() => _BeneficiosPageState();
}

class _BeneficiosPageState extends State<BeneficiosPage> {
  String? _filtroCategoria;

  void _avisar(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  final BeneficioImagenService _imagenes = BeneficioImagenService();

  Future<bool> _ejecutar(
    Future<void> Function() accion, {
    required String exito,
    required String auditoriaAccion,
    required String target,
    required String detalle,
  }) async {
    try {
      await accion();
    } catch (e) {
      _avisar('No se pudo guardar el cambio: $e', error: true);
      return false;
    }
    // La auditoría es complementaria: si falla, el cambio ya quedó hecho.
    try {
      await widget.service.logAction(
        action: auditoriaAccion,
        target: target,
        details: detalle,
      );
    } catch (_) {}
    _avisar(exito);
    return true;
  }

  /// Borra una imagen del bucket sin molestar si falla (queda huérfana).
  Future<void> _borrarImagen(String? path) async {
    if (path == null || !path.startsWith('beneficios/')) return;
    try {
      await _imagenes.eliminar(path);
    } catch (_) {}
  }

  Future<void> _abrirFormulario({QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final resultado = await showDialog<_ResultadoFormulario>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioBeneficio(inicial: doc?.data()),
    );
    if (resultado == null) return;

    final datos = resultado.datos;
    final anterior = doc?.data()['imagen_path']?.toString();

    // 1) Si se eligió una imagen nueva, se sube primero y su ruta se guarda.
    String? subida;
    if (resultado.bytes != null) {
      _avisar('Subiendo imagen…');
      try {
        subida = await _imagenes.subir(
          bytes: resultado.bytes!,
          extension: resultado.extension!,
        );
      } catch (e) {
        _avisar('No se pudo subir la imagen: $e', error: true);
        return;
      }
      datos['imagen_path'] = subida;
    }

    final titulo = datos['titulo'] as String;
    final guardado = await _ejecutar(
      () => widget.service.guardarBeneficio(datos, id: doc?.id),
      exito: doc == null ? 'Beneficio creado' : 'Beneficio actualizado',
      auditoriaAccion: doc == null ? 'CREATE_BENEFICIO' : 'UPDATE_BENEFICIO',
      target: titulo,
      detalle: '${doc == null ? 'Creó' : 'Editó'} el beneficio "$titulo" '
          '(${datos['categoria']}).',
    );

    // 2) Si el guardado falló, la imagen recién subida queda huérfana: se borra.
    //    Si salió bien y la imagen cambió o se quitó, se borra la anterior.
    if (!guardado) {
      await _borrarImagen(subida);
    } else if (subida != null || resultado.quitarImagen) {
      await _borrarImagen(anterior);
    }
  }

  Future<void> _eliminar(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final titulo = (doc.data()['titulo'] ?? 'este beneficio').toString();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar beneficio'),
        content: Text(
          '¿Eliminar "$titulo"? Dejará de verse en la app y no se puede deshacer. '
          'Si solo quieres ocultarlo, desactívalo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final eliminado = await _ejecutar(
      () => widget.service.eliminarBeneficio(doc.id),
      exito: 'Beneficio eliminado',
      auditoriaAccion: 'DELETE_BENEFICIO',
      target: titulo,
      detalle: 'Eliminó el beneficio "$titulo".',
    );
    if (eliminado) await _borrarImagen(doc.data()['imagen_path']?.toString());
  }

  Future<void> _cambiar(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String campo,
    bool valor,
  ) {
    final titulo = (doc.data()['titulo'] ?? '').toString();
    final etiqueta = campo == 'activo'
        ? (valor ? 'Activó' : 'Desactivó')
        : (valor ? 'Destacó' : 'Quitó de destacados');
    return _ejecutar(
      () => widget.service.cambiarEstadoBeneficio(doc.id, campo, valor),
      exito: '$etiqueta "$titulo"',
      auditoriaAccion: 'UPDATE_BENEFICIO',
      target: titulo,
      detalle: '$etiqueta el beneficio "$titulo".',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beneficios',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Catálogo de beneficios que ven los conductores en la app. '
                        'Los activos y vigentes aparecen en su pantalla de inicio.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => _abrirFormulario(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo beneficio'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                initialValue: _filtroCategoria,
                decoration: const InputDecoration(
                  labelText: 'Filtrar por categoría',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las categorías'),
                  ),
                  for (final c in categoriasBeneficio)
                    DropdownMenuItem<String?>(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _filtroCategoria = v),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.service.streamBeneficios(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _Mensaje(
                      icono: Icons.lock_outline,
                      texto: 'No se pudo leer el catálogo: ${snapshot.error}\n'
                          'Verifica que las reglas de Firestore de "beneficios" '
                          'estén publicadas.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs.where((d) {
                    return _filtroCategoria == null ||
                        d.data()['categoria'] == _filtroCategoria;
                  }).toList()
                    ..sort((a, b) {
                      final da = a.data()['destacado'] == true;
                      final db = b.data()['destacado'] == true;
                      if (da != db) return da ? -1 : 1;
                      return (a.data()['titulo'] ?? '')
                          .toString()
                          .toLowerCase()
                          .compareTo((b.data()['titulo'] ?? '').toString().toLowerCase());
                    });

                  if (docs.isEmpty) {
                    return const _Mensaje(
                      icono: Icons.card_giftcard_outlined,
                      texto: 'Aún no hay beneficios. Crea el primero con '
                          '"Nuevo beneficio".',
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _FilaBeneficio(
                      doc: docs[i],
                      onEditar: () => _abrirFormulario(doc: docs[i]),
                      onEliminar: () => _eliminar(docs[i]),
                      onCambiar: (campo, valor) => _cambiar(docs[i], campo, valor),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 44, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _FilaBeneficio extends StatelessWidget {
  const _FilaBeneficio({
    required this.doc,
    required this.onEditar,
    required this.onEliminar,
    required this.onCambiar,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final void Function(String campo, bool valor) onCambiar;

  /// "Vigente", "Vencido" o "Programado", según las fechas.
  (String, Color) _vigencia(Map<String, dynamic> d) {
    final hoy = _soloFecha(DateTime.now());
    final inicio = (d['fecha_inicio'] as Timestamp?)?.toDate();
    final fin = (d['fecha_fin'] as Timestamp?)?.toDate();
    if (fin != null && _soloFecha(fin).isBefore(hoy)) {
      return ('Vencido', Colors.red.shade700);
    }
    if (inicio != null && _soloFecha(inicio).isAfter(hoy)) {
      return ('Programado', Colors.orange.shade800);
    }
    return ('Vigente', Colors.green.shade700);
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final activo = d['activo'] != false;
    final destacado = d['destacado'] == true;
    final categoria = d['categoria']?.toString();
    final imagen = d['imagen_path']?.toString();
    final inicio = (d['fecha_inicio'] as Timestamp?)?.toDate();
    final fin = (d['fecha_fin'] as Timestamp?)?.toDate();
    final (vigencia, colorVigencia) = _vigencia(d);

    final rango = [
      if (inicio != null) 'Desde ${_fecha(inicio)}',
      if (fin != null) 'hasta ${_fecha(fin)}',
    ].join(' ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 96,
                child: _ImagenGuardada(path: imagen, categoria: categoria),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (d['titulo'] ?? 'Sin título').toString(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (destacado) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star, size: 18, color: Color(0xFFF59E0B)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      ?d['empresa']?.toString(),
                      ?(categoria == 'Otros'
                          ? (d['categoria_otra']?.toString() ?? 'Otros')
                          : categoria),
                      ?d['ubicacion']?.toString(),
                    ].join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Etiqueta(vigencia, colorVigencia),
                      if (!activo) _Etiqueta('Inactivo', const Color(0xFF64748B)),
                      if (rango.isNotEmpty)
                        Text(
                          rango,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Activo', style: TextStyle(fontSize: 12)),
                    Switch(value: activo, onChanged: (v) => onCambiar('activo', v)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: destacado ? 'Quitar de destacados' : 'Destacar',
                      onPressed: () => onCambiar('destacado', !destacado),
                      icon: Icon(
                        destacado ? Icons.star : Icons.star_border,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: onEditar,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: onEliminar,
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Imagen ya guardada: ruta del bucket (URL firmada) o URL https. Sin imagen
/// o si falla, el ícono de la categoría.
class _ImagenGuardada extends StatefulWidget {
  const _ImagenGuardada({required this.path, required this.categoria});

  final String? path;
  final String? categoria;

  @override
  State<_ImagenGuardada> createState() => _ImagenGuardadaState();
}

class _ImagenGuardadaState extends State<_ImagenGuardada> {
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void didUpdateWidget(_ImagenGuardada old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _preparar();
  }

  void _preparar() {
    final p = widget.path;
    if (p == null) {
      _url = null;
    } else if (p.startsWith('https://')) {
      _url = Future.value(p);
    } else if (p.startsWith('beneficios/') && BeneficioImagenService.configurado) {
      _url = BeneficioImagenService().urlFirmada(p);
    } else {
      _url = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final futuro = _url;
    if (futuro == null) return _Miniatura(categoria: widget.categoria);
    return FutureBuilder<String>(
      future: futuro,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return _Miniatura(categoria: widget.categoria);
        return Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => _Miniatura(categoria: widget.categoria),
        );
      },
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.categoria});

  final String? categoria;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE0F2FE),
      child: Icon(_iconoCategoria(categoria), color: const Color(0xFF0EA5E9), size: 32),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, this.color);

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Lo que devuelve el formulario: los datos del beneficio y, si corresponde,
/// la imagen nueva por subir (o la orden de quitar la que había).
class _ResultadoFormulario {
  _ResultadoFormulario({
    required this.datos,
    this.bytes,
    this.extension,
    this.quitarImagen = false,
  });

  final Map<String, dynamic> datos;
  final Uint8List? bytes;
  final String? extension;
  final bool quitarImagen;
}

/// Formulario de crear/editar. Devuelve el resultado listo para guardar o `null`.
/// Las mismas validaciones las exigen las reglas de Firestore.
class _FormularioBeneficio extends StatefulWidget {
  const _FormularioBeneficio({this.inicial});

  final Map<String, dynamic>? inicial;

  @override
  State<_FormularioBeneficio> createState() => _FormularioBeneficioState();
}

class _FormularioBeneficioState extends State<_FormularioBeneficio> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _empresa;
  late final TextEditingController _descripcion;
  late final TextEditingController _categoriaOtra;
  late final TextEditingController _url;
  late final TextEditingController _ubicacion;
  late final TextEditingController _condiciones;
  String? _categoria;
  DateTime? _inicio;
  DateTime? _fin;
  bool _destacado = false;
  bool _activo = true;
  String? _errorFechas;

  /// Imagen ya guardada (ruta), la imagen nueva elegida y su estado.
  String? _imagenActual;
  Uint8List? _bytesNuevos;
  String? _extensionNueva;
  String? _nombreNuevo;
  String? _errorImagen;

  @override
  void initState() {
    super.initState();
    final d = widget.inicial ?? const <String, dynamic>{};
    String texto(String k) => (d[k] ?? '').toString();
    _titulo = TextEditingController(text: texto('titulo'));
    _empresa = TextEditingController(text: texto('empresa'));
    _descripcion = TextEditingController(text: texto('descripcion'));
    _imagenActual = d['imagen_path']?.toString();
    _categoriaOtra = TextEditingController(text: texto('categoria_otra'));
    _url = TextEditingController(text: texto('url_externa'));
    _ubicacion = TextEditingController(text: texto('ubicacion'));
    _condiciones = TextEditingController(text: texto('condiciones'));
    final categoria = d['categoria']?.toString();
    _categoria = categoriasBeneficio.contains(categoria) ? categoria : null;
    _inicio = (d['fecha_inicio'] as Timestamp?)?.toDate();
    _fin = (d['fecha_fin'] as Timestamp?)?.toDate();
    _destacado = d['destacado'] == true;
    _activo = d['activo'] != false;
  }

  @override
  void dispose() {
    for (final c in [_titulo, _empresa, _descripcion, _categoriaOtra, _url, _ubicacion, _condiciones]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obligatorio(String? v, int max) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Obligatorio';
    if (t.length > max) return 'Máximo $max caracteres';
    return null;
  }

  String? _opcional(String? v, int max) {
    if ((v ?? '').trim().length > max) return 'Máximo $max caracteres';
    return null;
  }

  String? _enlaceHttps(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    if (t.length > 500) return 'Máximo 500 caracteres';
    final uri = Uri.tryParse(t);
    if (!t.startsWith('https://') || uri == null || uri.host.isEmpty) {
      return 'Debe ser un enlace que empiece con https://';
    }
    return null;
  }

  Future<void> _elegirImagen() async {
    FilePickerResult? r;
    try {
      r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: BeneficioImagenService.extensionesPermitidas,
        withData: true,
      );
    } catch (e) {
      setState(() => _errorImagen =
          'No se pudo abrir el selector de archivos ($e). '
          'Cierra el panel y vuelve a ejecutarlo desde cero (no hot reload).');
      return;
    }
    final archivo = r?.files.single;
    if (archivo == null) return;
    final bytes = archivo.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _errorImagen = 'No se pudo leer la imagen.');
      return;
    }
    if (bytes.length > BeneficioImagenService.maxBytes) {
      setState(() => _errorImagen = 'La imagen debe pesar menos de 5 MB.');
      return;
    }
    setState(() {
      _bytesNuevos = bytes;
      _extensionNueva = (archivo.extension ?? '').toLowerCase();
      _nombreNuevo = archivo.name;
      _errorImagen = null;
    });
  }

  void _quitarImagen() => setState(() {
        _bytesNuevos = null;
        _extensionNueva = null;
        _nombreNuevo = null;
        _imagenActual = null;
        _errorImagen = null;
      });

  Widget _selectorImagen() {
    final hayImagen = _bytesNuevos != null || _imagenActual != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Imagen', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            width: 165,
            child: _bytesNuevos != null
                ? Image.memory(_bytesNuevos!, fit: BoxFit.cover)
                : _ImagenGuardada(path: _imagenActual, categoria: _categoria),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _elegirImagen,
              icon: const Icon(Icons.upload_file),
              label: Text(hayImagen ? 'Cambiar imagen' : 'Subir imagen'),
            ),
            if (hayImagen) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: _quitarImagen, child: const Text('Quitar')),
            ],
            if (_nombreNuevo != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _nombreNuevo!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _errorImagen ??
                (BeneficioImagenService.configurado
                    ? 'Se muestra en vertical (3:4). JPG, PNG o WEBP, hasta 5 MB. '
                        'Sin imagen, la app muestra el ícono de la categoría.'
                    : 'Falta SUPABASE_URL en el archivo .env del panel. Agrégala y '
                        'vuelve a ejecutar el panel desde cero para poder subir imágenes.'),
            style: TextStyle(
              fontSize: 12,
              color: (_errorImagen != null || !BeneficioImagenService.configurado)
                  ? Colors.red.shade700
                  : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _elegirFecha(bool esInicio) async {
    final actual = (esInicio ? _inicio : _fin) ?? DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida == null) return;
    setState(() {
      if (esInicio) {
        _inicio = elegida;
      } else {
        _fin = elegida;
      }
      _errorFechas = null;
    });
  }

  void _guardar() {
    final fechasMal = _inicio != null &&
        _fin != null &&
        _soloFecha(_fin!).isBefore(_soloFecha(_inicio!));
    setState(() => _errorFechas =
        fechasMal ? 'La fecha de fin no puede ser anterior a la de inicio' : null);
    if (!_form.currentState!.validate() || fechasMal) return;

    String? limpio(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final datos = <String, dynamic>{
      'categoria': _categoria,
      if (_categoria == 'Otros') 'categoria_otra': _categoriaOtra.text.trim(),
      'titulo': _titulo.text.trim(),
      'empresa': _empresa.text.trim(),
      if (limpio(_descripcion) != null) 'descripcion': limpio(_descripcion),
      if (_bytesNuevos == null && _imagenActual != null) 'imagen_path': _imagenActual,
      if (limpio(_url) != null) 'url_externa': limpio(_url),
      if (limpio(_ubicacion) != null) 'ubicacion': limpio(_ubicacion),
      if (_inicio != null) 'fecha_inicio': Timestamp.fromDate(_soloFecha(_inicio!)),
      if (_fin != null) 'fecha_fin': Timestamp.fromDate(_soloFecha(_fin!)),
      if (limpio(_condiciones) != null) 'condiciones': limpio(_condiciones),
      'destacado': _destacado,
      'activo': _activo,
    };

    Navigator.pop(
      context,
      _ResultadoFormulario(
        datos: datos,
        bytes: _bytesNuevos,
        extension: _extensionNueva,
        quitarImagen: _bytesNuevos == null &&
            _imagenActual == null &&
            widget.inicial?['imagen_path'] != null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.inicial != null;
    return AlertDialog(
      title: Text(editando ? 'Editar beneficio' : 'Nuevo beneficio'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(labelText: 'Categoría *'),
                  items: [
                    for (final c in categoriasBeneficio)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  validator: (v) => v == null ? 'Elige una categoría' : null,
                  onChanged: (v) => setState(() => _categoria = v),
                ),
                if (_categoria == 'Otros')
                  TextFormField(
                    controller: _categoriaOtra,
                    decoration: const InputDecoration(
                      labelText: 'Escribe la categoría *',
                      helperText: 'Por ejemplo: Lavado a domicilio.',
                    ),
                    validator: (v) => _obligatorio(v, 60),
                  ),
                TextFormField(
                  controller: _titulo,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: (v) => _obligatorio(v, 120),
                ),
                TextFormField(
                  controller: _empresa,
                  decoration: const InputDecoration(labelText: 'Empresa o comercio *'),
                  validator: (v) => _obligatorio(v, 120),
                ),
                TextFormField(
                  controller: _descripcion,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                  validator: (v) => _opcional(v, 1000),
                ),
                const SizedBox(height: 8),
                _selectorImagen(),
                TextFormField(
                  controller: _url,
                  decoration: const InputDecoration(
                    labelText: 'Enlace al beneficio (URL https)',
                  ),
                  validator: _enlaceHttps,
                ),
                TextFormField(
                  controller: _ubicacion,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación',
                    helperText: 'Ciudad, comuna o región donde aplica.',
                  ),
                  validator: (v) => _opcional(v, 200),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _elegirFecha(true),
                        icon: const Icon(Icons.event),
                        label: Text(_inicio == null ? 'Inicio' : 'Inicio: ${_fecha(_inicio!)}'),
                      ),
                    ),
                    if (_inicio != null)
                      IconButton(
                        tooltip: 'Quitar fecha de inicio',
                        onPressed: () => setState(() => _inicio = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _elegirFecha(false),
                        icon: const Icon(Icons.event_busy),
                        label: Text(_fin == null ? 'Fin' : 'Fin: ${_fecha(_fin!)}'),
                      ),
                    ),
                    if (_fin != null)
                      IconButton(
                        tooltip: 'Quitar fecha de fin',
                        onPressed: () => setState(() => _fin = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                  ],
                ),
                if (_errorFechas != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _errorFechas!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _condiciones,
                  decoration: const InputDecoration(labelText: 'Condiciones'),
                  maxLines: 3,
                  validator: (v) => _opcional(v, 2000),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Destacado'),
                  subtitle: const Text('Aparece primero en el catálogo.'),
                  value: _destacado,
                  onChanged: (v) => setState(() => _destacado = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  subtitle: const Text('Si está desactivado, no se muestra en la app.'),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(editando ? 'Guardar cambios' : 'Crear beneficio'),
        ),
      ],
    );
  }
}
