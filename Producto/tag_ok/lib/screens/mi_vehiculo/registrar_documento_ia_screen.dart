import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/documento_vehicular_model.dart';
import '../../data/services/documento_vehicular_service.dart';
import '../../data/services/storage_service.dart';
import '../../features/registro_inteligente/document_type.dart';
import '../../features/registro_inteligente/smart_capture_controller.dart';
import '../../features/registro_inteligente/smart_capture_result.dart';
import '../../features/registro_inteligente/smart_capture_review_screen.dart';

/// CU6 (entrada) — captura evidencia y delega en el componente transversal
/// de Registro Inteligente (CU33-CU38). El guardado final (CU7/CU39) es
/// responsabilidad de este módulo, no del componente compartido.
class RegistrarDocumentoIaScreen extends StatefulWidget {
  final String vehiculoId;

  const RegistrarDocumentoIaScreen({super.key, required this.vehiculoId});

  @override
  State<RegistrarDocumentoIaScreen> createState() =>
      _RegistrarDocumentoIaScreenState();
}

const _tiposDocumentoVehiculo = [
  DocumentType.permisoCirculacion,
  DocumentType.revisionTecnica,
  DocumentType.soap,
  DocumentType.seguro,
];

TipoDocumentoVehicular _aTipoDocumentoVehicular(DocumentType tipo) {
  switch (tipo) {
    case DocumentType.permisoCirculacion:
      return TipoDocumentoVehicular.permisoCirculacion;
    case DocumentType.revisionTecnica:
      return TipoDocumentoVehicular.revisionTecnica;
    case DocumentType.soap:
      return TipoDocumentoVehicular.soap;
    case DocumentType.seguro:
      return TipoDocumentoVehicular.seguro;
  }
}

class _RegistrarDocumentoIaScreenState
    extends State<RegistrarDocumentoIaScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color surfaceColor = const Color(0xFF1E293B);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF4F46E5);

  final SmartCaptureController _controller = SmartCaptureController();
  final DocumentoVehicularService _documentoService =
      DocumentoVehicularService();
  final StorageService _storageService = StorageService();

  bool _procesando = false;

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (foto == null) return; // E1 CU33: cancelado, no continúa
    final bytes = await foto.readAsBytes();
    await _procesarEvidencia(bytes: bytes, mimeType: 'image/jpeg', nombre: foto.name);
  }

  Future<void> _elegirArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) return;
    final archivo = resultado.files.first;
    final bytes = archivo.bytes;
    if (bytes == null) return;

    final nombreLower = archivo.name.toLowerCase();
    final mimeType = nombreLower.endsWith('.pdf')
        ? 'application/pdf'
        : nombreLower.endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';

    await _procesarEvidencia(bytes: bytes, mimeType: mimeType, nombre: archivo.name);
  }

  Future<void> _procesarEvidencia({
    required Uint8List bytes,
    required String mimeType,
    required String nombre,
  }) async {
    setState(() => _procesando = true);

    try {
      final resultado = await _controller.capturarYExtraer(
        bytes: bytes,
        mimeType: mimeType,
        nombreArchivo: nombre,
        tiposPermitidos: _tiposDocumentoVehiculo,
      );

      if (!mounted) return;
      await _abrirRevision(resultado: resultado, bytesOriginal: bytes, mimeType: mimeType);
    } catch (e) {
      // RNF-011: la IA falló — se informa y se ofrece ingreso manual (CU40),
      // sin bloquear el flujo.
      if (!mounted) return;
      final continuar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: surfaceColor,
          title: Text('No se pudo analizar el documento', style: TextStyle(color: textMain)),
          content: Text(
            'Ocurrió un problema con el motor de IA. Puedes ingresar los datos manualmente.\n\n$e',
            style: TextStyle(color: textMuted),
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
      if (continuar == true) {
        await _abrirRevision(resultado: null, bytesOriginal: bytes, mimeType: mimeType);
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _abrirRevision({
    required SmartCaptureResult? resultado,
    required Uint8List bytesOriginal,
    required String mimeType,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartCaptureReviewScreen(
          resultado: resultado,
          tiposPermitidos: _tiposDocumentoVehiculo,
          onConfirm: ({required tipo, required campos, required esManual}) async {
            DateTime? parseFecha(String? raw) =>
                raw != null ? DateTime.tryParse(raw) : null;

            String? archivoPath;
            if (bytesOriginal.isNotEmpty) {
              final extension = mimeType == 'application/pdf' ? 'pdf' : 'jpg';
              archivoPath = await _storageService.subirArchivo(
                path:
                    'documentos_vehiculares/${widget.vehiculoId}/${DateTime.now().millisecondsSinceEpoch}.$extension',
                bytes: bytesOriginal,
                contentType: mimeType,
              );
            }

            if (esManual) {
              await _documentoService.crearDocumentoManual(
                DocumentoVehicularModel(
                  id: '',
                  vehiculoId: widget.vehiculoId,
                  tipoDocumento: _aTipoDocumentoVehicular(tipo),
                  numero: campos['numero'],
                  fechaEmision: parseFecha(campos['fecha_emision']),
                  fechaVencimiento: parseFecha(campos['fecha_vencimiento']),
                  compania: campos['compania'],
                  numeroPoliza: campos['numero_poliza'],
                  archivoPath: archivoPath,
                  origenRegistro: 'manual',
                  fechaRegistro: DateTime.now(),
                ),
              );
            } else {
              await _documentoService.confirmarDesdeIA(
                vehiculoId: widget.vehiculoId,
                tipoDocumento: _aTipoDocumentoVehicular(tipo),
                numero: campos['numero'],
                fechaEmision: parseFecha(campos['fecha_emision']),
                fechaVencimiento: parseFecha(campos['fecha_vencimiento']),
                compania: campos['compania'],
                numeroPoliza: campos['numero_poliza'],
                archivoPath: archivoPath,
                fechaCaptura: resultado?.fechaCaptura ?? DateTime.now(),
              );
            }
          },
        ),
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('Registrar documento con IA', style: TextStyle(color: textMain)),
        iconTheme: IconThemeData(color: textMain),
      ),
      body: Center(
        child: _procesando
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Analizando documento...', style: TextStyle(color: textMuted)),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Fotografía tu Permiso de Circulación, Revisión Técnica, SOAP o Seguro, '
                      'y la IA detectará el tipo y los datos por ti.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMuted),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _tomarFoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Tomar foto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _elegirArchivo,
                      icon: Icon(Icons.attach_file, color: textMain),
                      label: Text('Elegir archivo', style: TextStyle(color: textMain)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => _abrirRevision(
                        resultado: null,
                        bytesOriginal: Uint8List(0),
                        mimeType: 'application/octet-stream',
                      ),
                      child: Text(
                        'Ingresar manualmente sin IA',
                        style: TextStyle(color: textMuted),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
