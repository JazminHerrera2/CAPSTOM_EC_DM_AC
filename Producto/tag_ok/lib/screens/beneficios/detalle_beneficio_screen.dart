import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/beneficio_model.dart';
import '../dashboard/dashboard_logica.dart';
import 'imagen_beneficio.dart';

/// Detalle de un beneficio: imagen, descripción, vigencia, condiciones y
/// enlace externo.
class DetalleBeneficioScreen extends StatelessWidget {
  final BeneficioModel beneficio;

  const DetalleBeneficioScreen({super.key, required this.beneficio});

  static const Color _bgColor = Color(0xFFF1F5F9);
  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _primaryColor = Color(0xFF1E3A8A);

  Future<void> _abrirEnlace(BuildContext context) async {
    final uri = Uri.tryParse(beneficio.urlExterna ?? '');
    final mensajes = ScaffoldMessenger.of(context);
    if (uri == null || !uri.isScheme('https')) {
      mensajes.showSnackBar(const SnackBar(content: Text('El enlace no es válido.')));
      return;
    }
    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto) {
      mensajes.showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
    }
  }

  String? get _vigencia {
    final inicio = beneficio.fechaInicio;
    final fin = beneficio.fechaFin;
    if (inicio == null && fin == null) return null;
    if (inicio != null && fin != null) {
      return 'Del ${formatearFecha(inicio)} al ${formatearFecha(fin)}';
    }
    if (fin != null) return 'Hasta el ${formatearFecha(fin)}';
    return 'Desde el ${formatearFecha(inicio!)}';
  }

  @override
  Widget build(BuildContext context) {
    final b = beneficio;
    final vigencia = _vigencia;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textMain),
        title: const Text('Beneficio', style: TextStyle(color: _textMain)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Horizontal a propósito: en el catálogo y el inicio la imagen
                // es vertical, y al abrir el beneficio se ve apaisada.
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(height: 190, child: ImagenBeneficio(beneficio: b)),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    if (b.categoria != null) _chip(b.etiquetaCategoria, _primaryColor),
                    if (b.destacado) _chip('Destacado', const Color(0xFFF59E0B)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  b.titulo,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (b.empresa != null) ...[
                  const SizedBox(height: 4),
                  Text(b.empresa!, style: const TextStyle(color: _textMuted, fontSize: 15)),
                ],
                if (b.descripcion != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    b.descripcion!,
                    style: const TextStyle(color: _textMain, fontSize: 14, height: 1.5),
                  ),
                ],
                const SizedBox(height: 16),
                if (vigencia != null) _dato(Icons.event_outlined, 'Vigencia', vigencia),
                if (b.ubicacion != null)
                  _dato(Icons.place_outlined, 'Ubicación', b.ubicacion!),
                if (b.condiciones != null)
                  _dato(Icons.info_outline, 'Condiciones', b.condiciones!),
                const SizedBox(height: 12),
                if (b.urlExterna != null)
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirEnlace(context),
                      icon: const Icon(Icons.open_in_new, color: Colors.white),
                      label: const Text(
                        'Ir al beneficio',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _dato(IconData icono, String titulo, String valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: _textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(valor, style: const TextStyle(color: _textMain, fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
