import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/registro_inteligente/combustible_extraction.dart';
import '../../features/registro_inteligente/consejos_captura.dart';
import '../../features/registro_inteligente/preparar_imagen.dart';
import 'registrar_combustible_screen.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

/// "Registrar carga": el usuario sube o fotografía la boleta o factura de la
/// bencinera, la IA la lee en cuanto el archivo está cargado y se abre el
/// formulario precargado para revisar y guardar. Si la IA falla (o el usuario
/// prefiere), el ingreso manual está al final de la pantalla.
class RegistroIaCombustibleScreen extends StatefulWidget {
  /// Vehículo preseleccionado (el elegido en Combustible).
  final String? vehiculoIdInicial;

  const RegistroIaCombustibleScreen({super.key, this.vehiculoIdInicial});

  @override
  State<RegistroIaCombustibleScreen> createState() =>
      _RegistroIaCombustibleScreenState();
}

class _RegistroIaCombustibleScreenState
    extends State<RegistroIaCombustibleScreen> {

  bool _procesando = false;

  /// Etapa visible mientras se procesa (preparando imagen / analizando).
  String _etapa = etapaAnalizando;

  // ------------------------------------------------------------
  // CAPTURA
  // ------------------------------------------------------------

  Future<void> _tomarFoto() async {
    if (!await mostrarConsejosCaptura(context)) return;
    if (!mounted) return;

    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (foto == null) return;

    await _analizar(bytes: await foto.readAsBytes(), mimeType: 'image/jpeg');
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
    setState(() {
      _procesando = true;
      _etapa = etapaAnalizando;
    });

    try {
      final datos = await extraerAbastecimiento(
        bytes: bytes,
        mimeType: mimeType,
        alCambiarEtapa: (etapa) {
          if (mounted) setState(() => _etapa = etapa);
        },
      );
      if (!mounted) return;

      if (datos.vacia) {
        await _avisoSinDatos();
        return;
      }
      await _abrirFormulario(datosIa: datos);
    } catch (e) {
      debugPrint('No se pudo analizar la boleta de combustible: $e');
      if (!mounted) return;
      await _avisoFalloIa();
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// Abre el formulario (precargado si hay [datosIa]). Si se guardó, cierra
  /// también esta pantalla y vuelve a Combustible.
  Future<void> _abrirFormulario({AbastecimientoExtraido? datosIa}) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrarCombustibleScreen(
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
    mensaje:
        'No pudimos extraer automáticamente los datos de la boleta. '
        'Puedes continuar ingresándolos manualmente.',
  );

  Future<void> _avisoSinDatos() => _dialogoManual(
    titulo: 'No encontramos datos',
    mensaje:
        'No pudimos leer información de una carga de combustible en '
        'este archivo. Prueba con una foto más clara o ingrésala '
        'manualmente.',
  );

  Future<void> _dialogoManual({
    required String titulo,
    required String mensaje,
  }) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(titulo, style: const TextStyle(color: AppColors.texto)),
            ),
          ],
        ),
        content: Text(
          mensaje,
          style: const TextStyle(color: AppColors.textoSecundario, height: 1.4),
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
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          backgroundColor: AppColors.fondo,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: !_procesando,
          iconTheme: const IconThemeData(color: AppColors.texto),
          title: Text(
            _procesando ? 'Analizando boleta' : 'Registrar carga',
            style: const TextStyle(
              color: AppColors.texto,
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
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            boxShadow: AppSombras.tarjeta,
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primario.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadios.tarjeta),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: AppColors.primario,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escanea o sube tu boleta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La IA leerá la boleta o factura de la bencinera y extraerá '
                'los datos de la carga para que puedas revisarlos antes de '
                'guardar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textoSecundario, fontSize: 13, height: 1.5),
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
        const SizedBox(height: 12),
        // Debajo de los otros botones, como una opción más.
        _opcion(
          icono: Icons.edit_note_outlined,
          titulo: 'Ingresar datos manualmente',
          descripcion: 'Completa solo los datos que necesites, sin usar la IA.',
          onTap: () => _abrirFormulario(),
        ),
        const SizedBox(height: 26),
        const Text(
          '¿Qué información se detectará?',
          style: TextStyle(
            color: AppColors.texto,
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
              'Estación de servicio',
              'Fecha',
              'Tipo de combustible',
              'Litros',
              'Precio por litro',
              'Total',
            ])
              _chip(t),
          ],
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
      borderRadius: BorderRadius.circular(AppRadios.tarjeta),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: principal
              ? AppColors.primario.withValues(alpha: 0.12)
              : AppColors.superficie,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          border: Border.all(
            color: principal
                ? AppColors.primario.withValues(alpha: 0.65)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: principal ? AppColors.primario : AppColors.contenedorSuave,
                borderRadius: BorderRadius.circular(AppRadios.control),
              ),
              child: Icon(
                icono,
                color: principal ? Colors.white : AppColors.primario,
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
                      color: AppColors.texto,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
          ],
        ),
      ),
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.contenedorSuave,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        border: Border.all(color: Colors.transparent),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textoSecundario,
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
                color: AppColors.primario.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    color: AppColors.primario,
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              _etapa == etapaPreparandoImagen
                  ? 'Preparando imagen...'
                  : 'Analizando boleta...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Estamos leyendo la boleta o factura y extrayendo los datos de '
              'la carga.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSecundario, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.superficie,
                borderRadius: BorderRadius.circular(AppRadios.control),
                border: Border.all(color: Colors.transparent),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.primario,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Procesamiento con IA',
                    style: TextStyle(
                      color: AppColors.textoSecundario,
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
