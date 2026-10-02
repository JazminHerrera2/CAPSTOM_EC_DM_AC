import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/storage_service.dart';

/// Muestra el archivo asociado a un documento vehicular.
///
/// `archivo_path` es una ruta dentro del bucket privado, no una URL: al abrir
/// el detalle se pide una URL firmada (dura ~10 min) a la Edge Function, que
/// valida el ID Token de Firebase. Las fotos se muestran en pantalla; los PDF
/// se abren en el visor del navegador/dispositivo.
class ArchivoDocumentoView extends StatefulWidget {
  final String archivoPath;

  const ArchivoDocumentoView({super.key, required this.archivoPath});

  @override
  State<ArchivoDocumentoView> createState() => _ArchivoDocumentoViewState();
}

class _ArchivoDocumentoViewState extends State<ArchivoDocumentoView> {
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color borderColor = Color(0xFF334155);

  final StorageService _storage = StorageService();
  late Future<String> _urlFuture;

  bool get _esPdf => widget.archivoPath.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    _urlFuture = _storage.obtenerUrlFirmada(widget.archivoPath);
  }

  void _reintentar() {
    setState(() {
      _urlFuture = _storage.obtenerUrlFirmada(widget.archivoPath);
    });
  }

  Future<void> _abrirPdf(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento.')),
      );
    }
  }

  void _verPantallaCompleta(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, _) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: textMuted, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _caja({required Widget child, double? height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _caja(
            height: 120,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _caja(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: textMuted),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No se pudo cargar el documento guardado.',
                      style: TextStyle(color: textMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: _reintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final url = snapshot.data!;

        if (_esPdf) {
          return _caja(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined,
                      color: primaryColor, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Documento original (PDF)',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _abrirPdf(url),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Abrir'),
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => _verPantallaCompleta(url),
          child: _caja(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, _, _) => SizedBox(
                height: 120,
                child: Center(
                  child: TextButton.icon(
                    onPressed: _reintentar,
                    icon: const Icon(Icons.broken_image_outlined),
                    label: const Text('No se pudo cargar la imagen. Reintentar'),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
