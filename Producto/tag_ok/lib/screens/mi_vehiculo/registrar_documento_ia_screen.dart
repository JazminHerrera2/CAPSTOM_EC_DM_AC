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

class RegistrarDocumentoIaScreen extends StatefulWidget {
  final String vehiculoId;

  const RegistrarDocumentoIaScreen({
    super.key,
    required this.vehiculoId,
  });

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

TipoDocumentoVehicular _aTipoDocumentoVehicular(
  DocumentType tipo,
) {
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
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF27364D);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color primaryColor = Color(0xFF4F46E5);

  final SmartCaptureController _controller =
      SmartCaptureController();

  final DocumentoVehicularService _documentoService =
      DocumentoVehicularService();

  final StorageService _storageService = StorageService();

  bool _procesando = false;

  // ------------------------------------------------------------
  // TOMAR FOTO
  // ------------------------------------------------------------

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();

    final foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (foto == null) return;

    final bytes = await foto.readAsBytes();

    await _procesarEvidencia(
      bytes: bytes,
      mimeType: 'image/jpeg',
      nombre: foto.name,
    );
  }

  // ------------------------------------------------------------
  // ELEGIR ARCHIVO
  // ------------------------------------------------------------

  Future<void> _elegirArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'jpg',
        'jpeg',
        'png',
      ],
      withData: true,
    );

    if (resultado == null ||
        resultado.files.isEmpty) {
      return;
    }

    final archivo = resultado.files.first;
    final bytes = archivo.bytes;

    if (bytes == null) return;

    final nombreLower =
        archivo.name.toLowerCase();

    final mimeType =
        nombreLower.endsWith('.pdf')
            ? 'application/pdf'
            : nombreLower.endsWith('.png')
                ? 'image/png'
                : 'image/jpeg';

    await _procesarEvidencia(
      bytes: bytes,
      mimeType: mimeType,
      nombre: archivo.name,
    );
  }

  // ------------------------------------------------------------
  // PROCESAR CON IA
  // ------------------------------------------------------------

  Future<void> _procesarEvidencia({
    required Uint8List bytes,
    required String mimeType,
    required String nombre,
  }) async {
    setState(() {
      _procesando = true;
    });

    try {
      final resultado =
          await _controller.capturarYExtraer(
        bytes: bytes,
        mimeType: mimeType,
        nombreArchivo: nombre,
        tiposPermitidos:
            _tiposDocumentoVehiculo,
      );

      if (!mounted) return;

      await _abrirRevision(
        resultado: resultado,
        bytesOriginal: bytes,
        mimeType: mimeType,
      );
    } catch (e) {
      if (!mounted) return;

      final continuar =
          await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.orangeAccent,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No se pudo analizar',
                    style: TextStyle(
                      color: textMain,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'No pudimos extraer automáticamente '
              'los datos del documento. Puedes '
              'continuar ingresándolos manualmente.',
              style: TextStyle(
                color: textMuted,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                  false,
                ),
                child: const Text(
                  'Cancelar',
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                  true,
                ),
                child: const Text(
                  'Ingresar manualmente',
                ),
              ),
            ],
          );
        },
      );

      if (continuar == true) {
        await _abrirRevision(
          resultado: null,
          bytesOriginal: bytes,
          mimeType: mimeType,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // REVISIÓN Y GUARDADO
  // ------------------------------------------------------------

  Future<void> _abrirRevision({
    required SmartCaptureResult? resultado,
    required Uint8List bytesOriginal,
    required String mimeType,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SmartCaptureReviewScreen(
          resultado: resultado,
          tiposPermitidos:
              _tiposDocumentoVehiculo,
          onConfirm: ({
            required tipo,
            required campos,
            required esManual,
          }) async {
            DateTime? parseFecha(
              String? raw,
            ) =>
                raw != null
                    ? DateTime.tryParse(raw)
                    : null;

            String? archivoPath;

            if (bytesOriginal.isNotEmpty) {
              final extension =
                  mimeType ==
                          'application/pdf'
                      ? 'pdf'
                      : 'jpg';

              archivoPath =
                  await _storageService
                      .subirArchivo(
                path:
                    'documentos_vehiculares/'
                    '${widget.vehiculoId}/'
                    '${DateTime.now().millisecondsSinceEpoch}.'
                    '$extension',
                bytes: bytesOriginal,
                contentType: mimeType,
              );
            }

            if (esManual) {
              await _documentoService
                  .crearDocumentoManual(
                DocumentoVehicularModel(
                  id: '',
                  vehiculoId:
                      widget.vehiculoId,
                  tipoDocumento:
                      _aTipoDocumentoVehicular(
                    tipo,
                  ),
                  numero: campos['numero'],
                  fechaEmision: parseFecha(
                    campos['fecha_emision'],
                  ),
                  fechaVencimiento:
                      parseFecha(
                    campos[
                        'fecha_vencimiento'],
                  ),
                  compania:
                      campos['compania'],
                  numeroPoliza:
                      campos['numero_poliza'],
                  archivoPath:
                      archivoPath,
                  origenRegistro: 'manual',
                  fechaRegistro:
                      DateTime.now(),
                ),
              );
            } else {
              await _documentoService
                  .confirmarDesdeIA(
                vehiculoId:
                    widget.vehiculoId,
                tipoDocumento:
                    _aTipoDocumentoVehicular(
                  tipo,
                ),
                numero: campos['numero'],
                fechaEmision: parseFecha(
                  campos['fecha_emision'],
                ),
                fechaVencimiento:
                    parseFecha(
                  campos[
                      'fecha_vencimiento'],
                ),
                compania:
                    campos['compania'],
                numeroPoliza:
                    campos['numero_poliza'],
                archivoPath:
                    archivoPath,
                fechaCaptura:
                    resultado
                            ?.fechaCaptura ??
                        DateTime.now(),
              );
            }
          },
        ),
      ),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ------------------------------------------------------------
  // OPCIÓN DE CAPTURA
  // ------------------------------------------------------------

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
          color: principal
              ? primaryColor.withOpacity(0.12)
              : surfaceColor,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: principal
                ? primaryColor.withOpacity(0.65)
                : const Color(0xFF334155),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: principal
                    ? primaryColor
                    : surfaceLight,
                borderRadius:
                    BorderRadius.circular(15),
              ),
              child: Icon(
                icono,
                color: principal
                    ? Colors.white
                    : primaryColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: textMain,
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,
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
            const Icon(
              Icons.chevron_right,
              color: textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipDocumento(
    String texto,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
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

  // ------------------------------------------------------------
  // PANTALLA
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: textMain,
        ),
        title: Text(
          _procesando
              ? 'Procesando documento'
              : 'Agregar documento',
          style: const TextStyle(
            color: textMain,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _procesando
            ? _buildProcesando()
            : _buildAgregar(),
      ),
    );
  }

  // ------------------------------------------------------------
  // AGREGAR DOCUMENTO
  // ------------------------------------------------------------

  Widget _buildAgregar() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        30,
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF334155),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color:
                      primaryColor.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: primaryColor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escanea o sube un documento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMain,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La IA identificará el documento '
                'y extraerá sus datos para que '
                'puedas revisarlos antes de guardar.',
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
          descripcion:
              'Toma una fotografía clara del documento.',
          onTap: _tomarFoto,
          principal: true,
        ),

        const SizedBox(height: 12),

        _opcion(
          icono: Icons.upload_file_outlined,
          titulo: 'Subir archivo',
          descripcion:
              'Selecciona un archivo PDF, JPG o PNG.',
          onTap: _elegirArchivo,
        ),

        const SizedBox(height: 26),

        const Text(
          'Documentos compatibles',
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
            _chipDocumento(
              'Permiso de circulación',
            ),
            _chipDocumento(
              'Revisión técnica',
            ),
            _chipDocumento('SOAP'),
            _chipDocumento('Seguro'),
          ],
        ),

        const SizedBox(height: 30),

        Row(
          children: [
            const Expanded(
              child: Divider(
                color: Color(0xFF334155),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Text(
                'o',
                style: TextStyle(
                  color:
                      textMuted.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ),
            const Expanded(
              child: Divider(
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => _abrirRevision(
              resultado: null,
              bytesOriginal: Uint8List(0),
              mimeType: 'application/octet-stream',
            ),
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
              side: const BorderSide(
                color: Color(0xFF475569),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // PROCESANDO
  // ------------------------------------------------------------

  Widget _buildProcesando() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color:
                    primaryColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child:
                      CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Analizando documento...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMain,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Estamos identificando el tipo de '
              'documento y extrayendo la información.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color:
                      const Color(0xFF334155),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: primaryColor,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Procesamiento con IA',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
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