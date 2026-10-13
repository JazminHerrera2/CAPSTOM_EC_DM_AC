import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/registro_inteligente/mantencion_extraction.dart';
import 'registrar_mantenimiento_screen.dart';

/// "Registrar mantención": el usuario sube o fotografía su boleta o factura,
/// la IA la lee en cuanto el archivo está cargado y se abre el formulario
/// precargado para revisar y guardar. Si la IA falla (o el usuario prefiere),
/// el ingreso manual está al final de la pantalla.
class RegistrarMantenimientoIaScreen extends StatefulWidget {
  /// Vehículo preseleccionado (el elegido en Mantenciones).
  final String? vehiculoIdInicial;

  const RegistrarMantenimientoIaScreen({super.key, this.vehiculoIdInicial});

  @override
  State<RegistrarMantenimientoIaScreen> createState() =>
      _RegistrarMantenimientoIaScreenState();
}

class _RegistrarMantenimientoIaScreenState
    extends State<RegistrarMantenimientoIaScreen> {
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF27364D);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF334155);

  bool _procesando = false;

  // ------------------------------------------------------------
  // CAPTURA
  // ------------------------------------------------------------

  Future<void> _tomarFoto() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (foto == null) return;

    await _analizar(
      bytes: await foto.readAsBytes(),
      mimeType: 'image/jpeg',
    );
  }

  Future<void> _elegirArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) return;

    final archivo = resultado.files.first;
    final bytes = archivo.bytes;
    if (bytes == null) return;

    final nombre = archivo.name.toLowerCase();
    final mimeType = nombre.endsWith('.pdf')
        ? 'application/pdf'
        : nombre.endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';

    await _analizar(bytes: bytes, mimeType: mimeType);
  }

  // ------------------------------------------------------------
  // ANÁLISIS CON IA (automático al cargar el archivo)
  // ------------------------------------------------------------

  Future<void> _analizar({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    setState(() => _procesando = true);

    try {
      final datos = await extraerMantencion(bytes: bytes, mimeType: mimeType);
      if (!mounted) return;

      if (datos.vacia) {
        await _avisoSinDatos();
        return;
      }
      await _abrirFormulario(datosIa: datos);
    } catch (e) {
      debugPrint('No se pudo analizar el comprobante: $e');
      if (!mounted) return;
      await _avisoFalloIa();
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// Abre el formulario (precargado si hay [datosIa]). Si se guardó, cierra
  /// también esta pantalla y vuelve a Mantenciones.
  Future<void> _abrirFormulario({MantencionExtraida? datosIa}) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrarMantenimientoScreen(
          vehiculoIdInicial: widget.vehiculoIdInicial,
          datosIa: datosIa,
          fechaCaptura: datosIa == null ? null : DateTime.now(),
        ),
      ),
    );

    if (guardado == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _avisoFalloIa() => _dialogoManual(
        titulo: 'No se pudo analizar',
        mensaje: 'No pudimos extraer automáticamente los datos del '
            'comprobante. Puedes continuar ingresándolos manualmente.',
      );

  Future<void> _avisoSinDatos() => _dialogoManual(
        titulo: 'No encontramos datos',
        mensaje: 'No pudimos leer información de mantención en este '
            'archivo. Prueba con una foto más clara o ingrésala manualmente.',
      );

  Future<void> _dialogoManual({
    required String titulo,
    required String mensaje,
  }) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(titulo, style: const TextStyle(color: textMain)),
            ),
          ],
        ),
        content: Text(
          mensaje,
          style: const TextStyle(color: textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ingresar manualmente'),
          ),
        ],
      ),
    );

    if (continuar == true && mounted) {
      await _abrirFormulario();
    }
  }

  // ------------------------------------------------------------
  // PANTALLA
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Mientras la IA analiza no se puede salir: evita abrir el formulario
      // sobre una pantalla que ya se cerró.
      canPop: !_procesando,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: !_procesando,
          iconTheme: const IconThemeData(color: textMain),
          title: Text(
            _procesando ? 'Analizando comprobante' : 'Registrar mantención',
            style: const TextStyle(
              color: textMain,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: _procesando ? _buildProcesando() : _buildAgregar(),
        ),
      ),
    );
  }

  Widget _buildAgregar() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: primaryColor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escanea o sube tu comprobante',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMain,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La IA leerá la boleta o factura del taller y extraerá los '
                'datos de la mantención para que puedas revisarlos antes de '
                'guardar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _opcion(
          icono: Icons.camera_alt_outlined,
          titulo: 'Escanear con cámara',
          descripcion: 'Toma una fotografía clara de la boleta o factura.',
          onTap: _tomarFoto,
          principal: true,
        ),
        const SizedBox(height: 12),
        _opcion(
          icono: Icons.upload_file_outlined,
          titulo: 'Subir archivo',
          descripcion: 'Selecciona un archivo PDF, JPG o PNG.',
          onTap: _elegirArchivo,
        ),
        const SizedBox(height: 26),
        const Text(
          '¿Qué información se detectará?',
          style: TextStyle(
            color: textMain,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in const [
              'Tipo de mantención',
              'Fecha',
              'Kilometraje',
              'Taller',
              'Monto total',
              'Servicios y repuestos',
            ])
              _chip(t),
          ],
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            const Expanded(child: Divider(color: borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o',
                style: TextStyle(
                  color: textMuted.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ),
            const Expanded(child: Divider(color: borderColor)),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => _abrirFormulario(),
            icon: const Icon(
              Icons.edit_note_outlined,
              color: textMain,
              size: 22,
            ),
            label: const Text(
              'Ingresar datos manualmente',
              style: TextStyle(
                color: textMain,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: surfaceColor,
              side: const BorderSide(color: Color(0xFF475569)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _opcion({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
    bool principal = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: principal ? primaryColor.withOpacity(0.12) : surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: principal ? primaryColor.withOpacity(0.65) : borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: principal ? primaryColor : surfaceLight,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icono,
                color: principal ? Colors.white : primaryColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: textMuted),
          ],
        ),
      ),
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProcesando() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Analizando comprobante...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMain,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Estamos leyendo la boleta o factura y extrayendo los datos de '
              'la mantención.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      color: primaryColor, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Procesamiento con IA',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
