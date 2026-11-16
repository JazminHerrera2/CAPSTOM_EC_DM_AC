import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/models/estacionamiento_model.dart';
import '../../data/services/estacionamiento_service.dart';
import '../../features/registro_inteligente/consejos_captura.dart';
import '../../features/registro_inteligente/estacionamiento_extraction.dart';
import '../../features/registro_inteligente/preparar_imagen.dart';

/// Registra el pago sobre un estacionamiento existente, sin crear otro registro.
class RegistroComprobanteScreen extends StatefulWidget {
  final EstacionamientoModel estacionamiento;

  const RegistroComprobanteScreen({
    super.key,
    required this.estacionamiento,
  });

  @override
  State<RegistroComprobanteScreen> createState() =>
      _RegistroComprobanteScreenState();
}

class _RegistroComprobanteScreenState extends State<RegistroComprobanteScreen> {
  static const _fondo = Color(0xFFF1F5F9);
  static const _azul = Color(0xFF1E3A8A);
  static const _texto = Color(0xFF0F172A);
  static const _secundario = Color(0xFF64748B);
  static const _grisIcono = Color(0xFFE2E8F0);

  bool _guardando = false;
  bool _procesando = false;
  String _etapa = etapaAnalizando;
  EstacionamientoExtraido? _datosIa;

  Future<void> _tomarFoto() async {
    if (_procesando || _guardando) return;
    if (!await mostrarConsejosCaptura(context)) return;
    if (!mounted) return;
    try {
      final foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (foto == null || !mounted) return;
      await _analizar(bytes: await foto.readAsBytes(), mimeType: 'image/jpeg');
    } catch (e) {
      if (!mounted) return;
      _mostrarError('No se pudo abrir la cámara: $e');
    }
  }

  Future<void> _elegirArchivo() async {
    if (_procesando || _guardando) return;
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (resultado == null || resultado.files.isEmpty || !mounted) return;
      final archivo = resultado.files.first;
      final bytes = archivo.bytes;
      if (bytes == null) {
        _mostrarError('No se pudo leer el archivo seleccionado.');
        return;
      }
      final nombre = archivo.name.toLowerCase();
      final mimeType = nombre.endsWith('.pdf')
          ? 'application/pdf'
          : nombre.endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
      await _analizar(bytes: bytes, mimeType: mimeType);
    } catch (e) {
      if (!mounted) return;
      _mostrarError('No se pudo seleccionar el archivo: $e');
    }
  }

  Future<void> _analizar({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!mounted) return;
    setState(() {
      _procesando = true;
      _etapa = etapaAnalizando;
    });
    try {
      final datos = await extraerEstacionamiento(
        bytes: bytes,
        mimeType: mimeType,
        alCambiarEtapa: (etapa) {
          if (mounted) setState(() => _etapa = etapa);
        },
      );
      if (!mounted) return;
      if (datos.vacia) {
        await _ofrecerManual(
          'No encontramos datos',
          'No pudimos identificar información de un estacionamiento en este '
              'comprobante. Prueba con otra imagen o ingresa el pago manualmente.',
        );
        return;
      }
      setState(() => _datosIa = datos);
    } catch (e) {
      debugPrint('Error al analizar comprobante de estacionamiento: $e');
      if (!mounted) return;
      await _ofrecerManual(
        'No se pudo analizar',
        'No fue posible leer el comprobante con IA. Puedes intentar otra vez '
            'o ingresar el pago manualmente.',
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _ofrecerManual(String titulo, String mensaje) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ingresar manualmente'),
          ),
        ],
      ),
    );
    if (continuar == true && mounted) await _ingresarMonto();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardarPago(int monto, {required String origen}) async {
    if (_guardando || _procesando) return;
    setState(() => _guardando = true);
    try {
      await EstacionamientoService().registrarComprobante(
        estacionamientoId: widget.estacionamiento.id,
        costo: monto,
        origenRegistro: origen,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _mostrarError('No se pudo guardar el pago: $error');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Reutilizado para ingreso manual y revisión de monto extraído por IA.
  Future<void> _ingresarMonto({EstacionamientoExtraido? datosIa}) async {
    final formulario = GlobalKey<FormState>();
    final montoController = TextEditingController(
      text: datosIa?.total?.toString() ?? '',
    );
    try {
      final monto = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (modalContext) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.viewInsetsOf(modalContext).bottom + 24,
            ),
            child: Form(
              key: formulario,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    datosIa == null ? 'Ingresar pago manualmente' : 'Revisar pago detectado',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _texto,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    datosIa == null
                        ? 'Ingresa el total pagado por este estacionamiento.'
                        : 'Comprueba el monto detectado por la IA y corrígelo si es necesario.',
                    style: const TextStyle(color: _secundario),
                  ),
                  if (datosIa != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Estacionamiento registrado: ${widget.estacionamiento.lugar}',
                      style: const TextStyle(color: _texto),
                    ),
                    if (datosIa.lugar != null) ...[
                      const SizedBox(height: 6),
                      Text('Emisor de la boleta: ${datosIa.lugar}',
                          style: const TextStyle(color: _secundario)),
                    ],
                    if (datosIa.fecha != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Fecha de emisión: ${DateFormat('dd/MM/yyyy').format(datosIa.fecha!)}',
                        style: const TextStyle(color: _secundario),
                      ),
                    ],
                    if (datosIa.camposDudosos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'La IA identificó datos dudosos. Verifica el comprobante antes de guardar.',
                        style: TextStyle(color: Color(0xFFB45309)),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: montoController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Monto pagado (CLP)',
                      prefixText: r'$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (valor) {
                      final monto = int.tryParse((valor ?? '').trim());
                      if (monto == null || monto < 0 || monto > 1000000000) {
                        return 'Ingresa un monto válido en pesos.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _azul,
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: () {
                        if (formulario.currentState!.validate()) {
                          Navigator.pop(
                            modalContext,
                            int.parse(montoController.text.trim()),
                          );
                        }
                      },
                      child: const Text('Guardar pago'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (monto == null || !mounted) return;
      await _guardarPago(monto, origen: datosIa == null ? 'manual' : 'ia');
    } finally {
      // El controlador del modal es local. Se libera al concluir su ruta.
      // No hacerlo inmediatamente tras pop evita conflictos de animación.
    }
  }

  Widget _opcion({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
    bool destacada = false,
  }) {
    return Material(
      color: destacada ? const Color(0xFFDCE2EF) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: (_guardando || _procesando) ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 27),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: destacada
                ? Border.all(color: const Color(0xFF5872C0), width: 1.3)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: destacada ? _azul : _grisIcono,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icono,
                  color: destacada ? Colors.white : _azul,
                  size: 31,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        color: _secundario,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _secundario, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pantallaProcesando() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _azul),
          const SizedBox(height: 24),
          Text(
            _etapa == etapaPreparandoImagen
                ? 'Preparando imagen...'
                : 'Analizando comprobante...',
            style: const TextStyle(
              color: _texto,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Estamos extrayendo los datos del pago con IA.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _secundario),
          ),
        ],
      ),
    );
  }

  Widget _pantallaOpciones() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E8F2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: _azul,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Escanea o sube tu boleta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _texto,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'La IA leerá la boleta o factura del estacionamiento y extraerá '
                'los datos del pago para que puedas revisarlos antes de guardar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secundario, fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _opcion(
          icono: Icons.photo_camera_outlined,
          titulo: 'Escanear con cámara',
          descripcion: 'Toma una fotografía clara de la boleta o factura.',
          destacada: true,
          onTap: _tomarFoto,
        ),
        const SizedBox(height: 16),
        _opcion(
          icono: Icons.upload_file_outlined,
          titulo: 'Subir archivo',
          descripcion: 'Selecciona un archivo PDF, JPG o PNG.',
          onTap: _elegirArchivo,
        ),
        const SizedBox(height: 16),
        _opcion(
          icono: Icons.edit_note_outlined,
          titulo: 'Ingresar datos manualmente',
          descripcion: 'Completa solo los datos que necesites, sin usar la IA.',
          onTap: () => _ingresarMonto(),
        ),
        if (_guardando) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator(color: _azul)),
        ],
      ],
    );
  }

  Widget _pantallaRevision() {
    final datos = _datosIa!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.fact_check_outlined, color: _azul, size: 56),
        const SizedBox(height: 18),
        const Text(
          'Revisa los datos detectados',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _texto,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'El monto se puede corregir antes de guardarlo. El lugar y la fecha '
          'de emisión se muestran como referencia y no modificarán el '
          'estacionamiento registrado.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _secundario, height: 1.4),
        ),
        const SizedBox(height: 24),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lugar: ${datos.lugar ?? 'No detectado'}'),
                const SizedBox(height: 10),
                Text(
                  'Fecha de emisión: ${datos.fecha == null ? 'No detectada' : DateFormat('dd/MM/yyyy').format(datos.fecha!)}',
                ),
                const SizedBox(height: 10),
                Text('Total: ${datos.total == null ? 'No detectado' : '\$${datos.total} CLP'}'),
                if (datos.camposDudosos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Algunos datos son dudosos. Revisa la boleta original.',
                    style: TextStyle(color: Color(0xFFB45309)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _guardando ? null : () => _ingresarMonto(datosIa: datos),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Revisar monto y guardar'),
          style: FilledButton.styleFrom(
            backgroundColor: _azul,
            padding: const EdgeInsets.all(17),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _guardando ? null : () => setState(() => _datosIa = null),
          child: const Text('Elegir otro comprobante'),
        ),
        if (_guardando) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator(color: _azul)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_procesando && !_guardando,
      child: Scaffold(
        backgroundColor: _fondo,
        appBar: AppBar(
          backgroundColor: _fondo,
          foregroundColor: _texto,
          elevation: 0,
          automaticallyImplyLeading: !_procesando && !_guardando,
          title: Text(
            _procesando ? 'Analizando comprobante' : 'Registrar comprobante',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: _procesando
              ? _pantallaProcesando()
              : _datosIa != null
                  ? _pantallaRevision()
                  : _pantallaOpciones(),
        ),
      ),
    );
  }
}
