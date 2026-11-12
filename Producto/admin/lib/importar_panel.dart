import 'dart:convert';
import 'dart:ui' show PathMetric;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';
import 'carga_masiva_page.dart';
import 'file_downloader.dart';

/// Panel lateral "Importar concesionarias": plantilla descargable y zona para
/// arrastrar o elegir uno o varios archivos .json.
Future<bool?> mostrarPanelImportarConcesionarias(
  BuildContext context,
  AdminFirestoreService service,
) {
  return mostrarPanelLateral<bool>(
    context,
    ancho: 540,
    builder: (_) => _PanelImportar(service: service),
  );
}

class _PanelImportar extends StatefulWidget {
  const _PanelImportar({required this.service});

  final AdminFirestoreService service;

  @override
  State<_PanelImportar> createState() => _PanelImportarState();
}

class _PanelImportarState extends State<_PanelImportar> {
  bool _arrastrando = false;
  bool _ocupado = false;

  Future<void> _procesar(List<String> textos) async {
    if (textos.isEmpty || !mounted) return;
    final ok = await importarConcesionarias(
      context,
      widget.service,
      textos,
      onOcupado: (v) {
        if (mounted) setState(() => _ocupado = v);
      },
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _elegir() async {
    final textos = await elegirArchivosTexto(context, ['json'], multiple: true);
    await _procesar(textos);
  }

  Future<void> _soltados(DropDoneDetails d) async {
    setState(() => _arrastrando = false);
    final textos = <String>[];
    var ignorados = 0;
    for (final f in d.files) {
      if (!f.name.toLowerCase().endsWith('.json')) {
        ignorados++;
        continue;
      }
      textos.add(utf8.decode(await f.readAsBytes(), allowMalformed: true));
    }
    if (ignorados > 0 && mounted) {
      avisar(context, 'Se ignoraron $ignorados archivo(s) que no son .json.', error: true);
    }
    await _procesar(textos);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    const Text(
                      'Importar concesionarias',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: kTinta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(color: kGris, fontSize: 15, height: 1.35),
                        children: const [
                          TextSpan(text: 'Sube uno o varios archivos '),
                          TextSpan(
                            text: '.json',
                            style: TextStyle(fontFamily: 'monospace'),
                          ),
                          TextSpan(
                            text:
                                ' con el formato de Autopista (metadatos + pórticos + tarifas).',
                          ),
                        ],
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
        if (_ocupado) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: BotonContorno(
              texto: 'Descargar plantilla',
              icono: Icons.download_outlined,
              onPressed: () {
                saveFile(kPlantillaConcesionaria, 'plantilla_concesionaria.json');
                avisar(context, 'Se descargó plantilla_concesionaria.json');
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: DropTarget(
            onDragEntered: (_) => setState(() => _arrastrando = true),
            onDragExited: (_) => setState(() => _arrastrando = false),
            onDragDone: _soltados,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _ocupado ? null : _elegir,
              child: CustomPaint(
                painter: _BordePunteado(
                  color: _arrastrando ? kAzul : const Color(0xFFCBD5E1),
                ),
                child: Container(
                  height: 270,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _arrastrando
                        ? kAzul.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: kAzulSuave,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: kAzul,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Arrastra archivos aquí o haz click para seleccionar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: kTinta,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'JSON · múltiples archivos permitidos',
                        style: TextStyle(color: kGris, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Borde de rectángulo redondeado con línea punteada.
class _BordePunteado extends CustomPainter {
  _BordePunteado({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordePunteado old) => old.color != color;
}
