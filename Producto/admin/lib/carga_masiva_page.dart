import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';
import 'concesionarios_page.dart' show Concesionaria, armarConcesionarias;
import 'file_downloader.dart';
import 'importar_panel.dart';
import 'porticos_paneles.dart';

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

double? _num(dynamic v) {
  if (v is num) return v.toDouble();
  final s = v?.toString().trim().replaceAll(',', '.') ?? '';
  return s.isEmpty ? null : double.tryParse(s);
}

bool _bool(dynamic v, {bool defecto = true}) {
  if (v is bool) return v;
  final s = v?.toString().trim().toLowerCase() ?? '';
  if (s.isEmpty) return defecto;
  return !{'false', '0', 'no', 'inactivo', 'n'}.contains(s);
}

/// Pórtico leído de un archivo, ya validado.
class _PorticoImport {
  _PorticoImport({
    required this.codigo,
    required this.nombre,
    required this.sentido,
    required this.lat,
    required this.lng,
    required this.activo,
    required this.base,
    required this.punta,
    required this.saturacion,
  });

  final String codigo;
  final String nombre;
  final String sentido;
  final double lat;
  final double lng;
  final bool activo;
  final double base;
  final double punta;
  final double saturacion;

  /// null si es válido; si no, el motivo del rechazo.
  static (_PorticoImport?, String?) leer(Map<String, dynamic> m, int fila) {
    final codigo = (m['codigo'] ?? m['codigo_portico'] ?? '').toString().trim();
    final nombre = (m['nombre'] ?? '').toString().trim();
    if (codigo.isEmpty && nombre.isEmpty) {
      return (null, 'Fila $fila: falta el código o el nombre del pórtico.');
    }
    final lat = _num(m['lat'] ?? m['latitud']);
    final lng = _num(m['lng'] ?? m['longitud']);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return (null, 'Fila $fila (${codigo.isEmpty ? nombre : codigo}): coordenadas inválidas.');
    }
    return (
      _PorticoImport(
        codigo: codigo.isEmpty ? _slug(nombre) : codigo,
        nombre: nombre,
        sentido: (m['sentido'] ?? '').toString().trim(),
        lat: lat,
        lng: lng,
        activo: _bool(m['activo']),
        base: _num(m['tarifa_base']) ?? 0,
        punta: _num(m['tarifa_punta']) ?? 0,
        saturacion: _num(m['tarifa_saturacion']) ?? 0,
      ),
      null,
    );
  }
}

class _ConcesionariaImport {
  _ConcesionariaImport({
    required this.codigo,
    required this.nombre,
    required this.porticos,
  });

  final String codigo;
  final String nombre;
  final List<_PorticoImport> porticos;

  String get clave => _slug(codigo.isNotEmpty ? codigo : nombre);
}

/// CSV con encabezado. Acepta coma o punto y coma, y campos entre comillas.
List<Map<String, String>> parsearCsv(String texto) {
  final lineas = const LineSplitter()
      .convert(texto.replaceFirst('﻿', ''))
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lineas.length < 2) return [];
  final sep = lineas.first.contains(';') && !lineas.first.contains(',') ? ';' : ',';

  List<String> campos(String linea) {
    final r = <String>[];
    final b = StringBuffer();
    var comillas = false;
    for (var i = 0; i < linea.length; i++) {
      final c = linea[i];
      if (c == '"') {
        if (comillas && i + 1 < linea.length && linea[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          comillas = !comillas;
        }
      } else if (c == sep && !comillas) {
        r.add(b.toString().trim());
        b.clear();
      } else {
        b.write(c);
      }
    }
    r.add(b.toString().trim());
    return r;
  }

  final enc = campos(lineas.first).map((e) => e.toLowerCase()).toList();
  return [
    for (final l in lineas.skip(1))
      () {
        final v = campos(l);
        return {
          for (var i = 0; i < enc.length; i++) enc[i]: i < v.length ? v[i] : '',
        };
      }(),
  ];
}

const String kPlantillaConcesionaria = '''{
  "codigo": "AV01",
  "nombre": "Vespucio Oriente",
  "porticos": [
    {
      "codigo": "PA2",
      "nombre": "Pórtico de ejemplo",
      "sentido": "N-S",
      "lat": -33.45,
      "lng": -70.66,
      "activo": true,
      "tarifa_base": 500,
      "tarifa_punta": 900,
      "tarifa_saturacion": 1200
    }
  ]
}
''';

const String kPlantillaPorticos =
    'autopista_codigo,codigo,nombre,sentido,lat,lng,activo,tarifa_base,tarifa_punta,tarifa_saturacion\n'
    'AV01,PA2,Pórtico de ejemplo,N-S,-33.45,-70.66,true,500,900,1200\n';

Future<List<String>> elegirArchivosTexto(
  BuildContext context,
  List<String> extensiones, {
  bool multiple = false,
}) async {
  try {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensiones,
      allowMultiple: multiple,
      withData: true,
    );
    if (r == null) return [];
    return [
      for (final f in r.files)
        if (f.bytes != null) utf8.decode(f.bytes!, allowMalformed: true),
    ];
  } catch (e) {
    if (context.mounted) {
      avisar(
        context,
        'No se pudo abrir el selector de archivos ($e). Reinicia la app (no hot reload).',
        error: true,
      );
    }
    return [];
  }
}

Map<String, dynamic> _camposPortico(
  _PorticoImport p,
  String autopista,
  String autopistaCodigo,
) => {
  'codigo': p.codigo,
  'nombre': p.nombre,
  'autopista': autopista,
  'autopista_codigo': autopistaCodigo,
  'sentido': p.sentido,
  'lat': p.lat,
  'lng': p.lng,
  'activo': p.activo,
  'tarifa_base': p.base,
  'tarifa_punta': p.punta,
  'tarifa_saturacion': p.saturacion,
};

Future<void> escribirLote(
  AdminFirestoreService service,
  List<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)> ops,
) async {
  final db = service.firestore;
  for (var i = 0; i < ops.length; i += 400) {
    final batch = db.batch();
    for (final (ref, datos) in ops.skip(i).take(400)) {
      batch.set(ref, datos, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

Future<bool> vistaPreviaImportacion(
  BuildContext context, {
  required String titulo,
  required String resumen,
  required List<String> errores,
  bool soloInformar = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(titulo),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(resumen),
            if (errores.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Avisos (${errores.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Text(
                    errores.take(30).join('\n') +
                        (errores.length > 30 ? '\n…y ${errores.length - 30} más' : ''),
                    style: const TextStyle(color: kRojo, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(soloInformar ? 'Cerrar' : 'Cancelar'),
        ),
        if (!soloInformar)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAzul),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
          ),
      ],
    ),
  );
  return r ?? false;
}

/// Lee uno o varios JSON de concesionarias, muestra la vista previa y, si se
/// confirma, escribe en Firestore. Devuelve true si se importó algo.
Future<bool> importarConcesionarias(
  BuildContext context,
  AdminFirestoreService service,
  List<String> textos, {
  void Function(bool ocupado)? onOcupado,
}) async {
  final lista = <_ConcesionariaImport>[];
  final errores = <String>[];
  for (var t = 0; t < textos.length; t++) {
    final prefijo = textos.length > 1 ? 'Archivo ${t + 1}: ' : '';
    try {
      final crudo = jsonDecode(textos[t]);
      final items = crudo is List ? crudo : [crudo];
      for (var i = 0; i < items.length; i++) {
        final m = items[i];
        if (m is! Map) {
          errores.add('$prefijo Elemento ${i + 1}: no es un objeto.');
          continue;
        }
        final nombre = (m['nombre'] ?? '').toString().trim();
        final codigo = (m['codigo'] ?? '').toString().trim();
        if (nombre.isEmpty) {
          errores.add('$prefijo Elemento ${i + 1}: falta "nombre".');
          continue;
        }
        final porticos = <_PorticoImport>[];
        final lp = m['porticos'];
        if (lp is List) {
          for (var j = 0; j < lp.length; j++) {
            final p = lp[j];
            if (p is! Map) {
              errores.add('$prefijo$nombre, pórtico ${j + 1}: no es un objeto.');
              continue;
            }
            final (ok, err) = _PorticoImport.leer(Map<String, dynamic>.from(p), j + 1);
            if (ok != null) porticos.add(ok);
            if (err != null) errores.add('$prefijo$nombre · $err');
          }
        }
        lista.add(
          _ConcesionariaImport(
            codigo: codigo,
            nombre: nombre,
            porticos: porticos,
          ),
        );
      }
    } catch (e) {
      errores.add('${prefijo}No es un JSON válido: $e');
    }
  }
  if (!context.mounted) return false;
  if (lista.isEmpty) {
    await vistaPreviaImportacion(
      context,
      titulo: 'Importar concesionarias',
      resumen: 'No se encontró ninguna concesionaria válida en los archivos.',
      errores: errores,
      soloInformar: true,
    );
    return false;
  }
  final totalPorticos = lista.fold<int>(0, (a, c) => a + c.porticos.length);
  final ok = await vistaPreviaImportacion(
    context,
    titulo: 'Importar concesionarias',
    resumen:
        '${lista.length} concesionaria(s) y $totalPorticos pórtico(s) listos para cargar. '
        'Si ya existen (mismo código), se actualizan.',
    errores: errores,
  );
  if (!ok) return false;

  onOcupado?.call(true);
  try {
    final db = service.firestore;
    final ops = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
    for (final c in lista) {
      ops.add((
        db.collection('concesionarias').doc(c.clave),
        {
          'nombre': c.nombre,
          'codigo': c.codigo,
        },
      ));
      for (final p in c.porticos) {
        ops.add((
          db.collection('porticos').doc('${c.clave}_${_slug(p.codigo)}'),
          _camposPortico(p, c.nombre, c.codigo),
        ));
      }
    }
    await escribirLote(service, ops);
    await service.logAction(
      action: 'IMPORT_CONCESIONARIAS',
      target: 'Carga masiva',
      details: 'Importó ${lista.length} concesionarias y $totalPorticos pórticos desde JSON.',
    );
    if (context.mounted) {
      avisar(context, 'Importadas ${lista.length} concesionarias y $totalPorticos pórticos.');
    }
    return true;
  } catch (e) {
    if (context.mounted) avisar(context, 'No se pudo importar: $e', error: true);
    return false;
  } finally {
    onOcupado?.call(false);
  }
}


/// Pórtico de un archivo, ya validado y asociado a su concesionaria.
class PorticoPorImportar {
  PorticoPorImportar._(this._raw, this.concesionaria);

  final _PorticoImport _raw;
  final Concesionaria concesionaria;

  String get codigo => _raw.codigo;
  String get nombre => _raw.nombre;
  String get sentido => _raw.sentido;
  double get lat => _raw.lat;
  double get lng => _raw.lng;
  String get autopista => concesionaria.nombre;
}

/// Lee un archivo CSV o JSON de pórticos y lo valida contra las autopistas
/// existentes (se asocian por código o nombre).
Future<({List<PorticoPorImportar> validos, List<String> errores})>
validarArchivoPorticos(AdminFirestoreService service, String texto) async {
  final t = texto.trimLeft();
  List<Map<String, dynamic>> filas;
  if (t.startsWith('[') || t.startsWith('{')) {
    final crudo = jsonDecode(t);
    final lista = crudo is List ? crudo : (crudo['porticos'] as List? ?? []);
    filas = [
      for (final f in lista)
        if (f is Map) Map<String, dynamic>.from(f),
    ];
  } else {
    filas = parsearCsv(texto);
  }
  if (filas.isEmpty) {
    return (validos: <PorticoPorImportar>[], errores: ['El archivo no trae filas.']);
  }

  final snapPorticos = await service.firestore.collection('porticos').get();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docsConc = const [];
  try {
    docsConc = (await service.firestore.collection('concesionarias').get()).docs;
  } catch (_) {}
  final existentes = armarConcesionarias(
    docsConc,
    snapPorticos.docs.map(PorticoAdmin.new).toList(),
  );
  Concesionaria? buscar(String ref) {
    final r = ref.trim().toLowerCase();
    if (r.isEmpty) return null;
    for (final c in existentes) {
      if (c.codigo.toLowerCase() == r || c.nombre.toLowerCase() == r) return c;
    }
    return null;
  }

  final validos = <PorticoPorImportar>[];
  final errores = <String>[];
  for (var i = 0; i < filas.length; i++) {
    final f = filas[i];
    final ref = (f['autopista_codigo'] ?? f['codigo_autopista'] ?? f['autopista'] ?? '')
        .toString();
    final c = buscar(ref);
    if (c == null) {
      errores.add(
        'Fila ${i + 1}: la autopista "${ref.isEmpty ? '(vacía)' : ref}" no existe. Crea la concesionaria primero.',
      );
      continue;
    }
    final (p, err) = _PorticoImport.leer(f, i + 1);
    if (p == null) {
      errores.add(err!);
      continue;
    }
    validos.add(PorticoPorImportar._(p, c));
  }
  return (validos: validos, errores: errores);
}

/// Escribe en Firestore los pórticos validados. Devuelve cuántos escribió.
Future<int> escribirPorticosImportados(
  AdminFirestoreService service,
  List<PorticoPorImportar> lista,
) async {
  final db = service.firestore;
  final ops = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[
    for (final x in lista)
      (
        db.collection('porticos').doc('${x.concesionaria.clave}_${_slug(x.codigo)}'),
        _camposPortico(x._raw, x.concesionaria.nombre, x.concesionaria.codigo),
      ),
  ];
  await escribirLote(service, ops);
  await service.logAction(
    action: 'IMPORT_PORTICOS',
    target: 'Carga masiva',
    details: 'Importó ${lista.length} pórticos desde archivo.',
  );
  return lista.length;
}

class CargaMasivaPage extends StatefulWidget {
  const CargaMasivaPage({super.key, required this.service});

  final AdminFirestoreService service;

  @override
  State<CargaMasivaPage> createState() => _CargaMasivaPageState();
}

class _CargaMasivaPageState extends State<CargaMasivaPage> {
  bool _ocupado = false;

  Future<void> _cargarConcesionarias() =>
      mostrarPanelImportarConcesionarias(context, widget.service);

  Future<void> _cargarPorticos() =>
      mostrarPanelCargaPorticos(context, widget.service);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final tarjetas = [
      _TarjetaCarga(
        icono: Icons.apartment_outlined,
        titulo: 'Concesionarias',
        formatos: 'JSON',
        descripcion:
            'Sube el JSON completo de una autopista: metadatos, pórticos y sus tarifas.',
        ocupado: _ocupado,
        onCargar: _cargarConcesionarias,
        onPlantilla: () {
          saveFile(kPlantillaConcesionaria, 'plantilla_concesionaria.json');
          avisar(context, 'Se descargó plantilla_concesionaria.json');
        },
      ),
      _TarjetaCarga(
        icono: Icons.location_on_outlined,
        titulo: 'Pórticos',
        formatos: 'JSON · CSV',
        descripcion:
            'Añade pórticos a autopistas existentes a partir de un archivo. Cada fila se asocia por el código de autopista.',
        ocupado: _ocupado,
        onCargar: _cargarPorticos,
        onPlantilla: () {
          saveFile(kPlantillaPorticos, 'plantilla_porticos.csv');
          avisar(context, 'Se descargó plantilla_porticos.csv');
        },
      ),
    ];

    return SafeArea(
      child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
              titulo: 'Carga masiva de datos',
              subtitulo:
                  'Importa datos al sistema desde archivos. Elige qué tipo de información quieres cargar.',
            ),
            children: [

            if (_ocupado) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],
            LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < 760) {
                  return Column(
                    children: [
                      tarjetas[0],
                      const SizedBox(height: 16),
                      tarjetas[1],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tarjetas[0]),
                    const SizedBox(width: 16),
                    Expanded(child: tarjetas[1]),
                  ],
                );
              },
            ),
          
            ],
          ),
    );
  }
}

class _TarjetaCarga extends StatelessWidget {
  const _TarjetaCarga({
    required this.icono,
    required this.titulo,
    required this.formatos,
    required this.descripcion,
    required this.onCargar,
    required this.onPlantilla,
    required this.ocupado,
  });

  final IconData icono;
  final String titulo;
  final String formatos;
  final String descripcion;
  final VoidCallback onCargar;
  final VoidCallback onPlantilla;
  final bool ocupado;

  @override
  Widget build(BuildContext context) => TarjetaBlanca(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconoCuadro(icono, tam: 46),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kTinta,
                  ),
                ),
                Text(
                  formatos,
                  style: const TextStyle(
                    color: kGris,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(descripcion, style: const TextStyle(color: kGris, fontSize: 14.5)),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            BotonPrimario(
              texto: 'Cargar archivo',
              icono: Icons.upload_outlined,
              onPressed: ocupado ? null : onCargar,
            ),
            BotonContorno(
              texto: 'Plantilla',
              icono: Icons.download_outlined,
              onPressed: onPlantilla,
            ),
          ],
        ),
      ],
    ),
  );
}
