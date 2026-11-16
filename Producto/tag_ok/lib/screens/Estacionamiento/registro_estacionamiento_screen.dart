import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

import 'package:flutter/material.dart';

import '../../data/models/vehiculo_model.dart';
import '../../data/services/estacionamiento_service.dart';
import 'seleccionar_ubicacion_screen.dart';

class RegistroEstacionamientoScreen extends StatefulWidget {
  final VehiculoModel vehiculo;

  const RegistroEstacionamientoScreen({super.key, required this.vehiculo});

  @override
  State<RegistroEstacionamientoScreen> createState() =>
      _RegistroEstacionamientoScreenState();
}

class _RegistroEstacionamientoScreenState
    extends State<RegistroEstacionamientoScreen> {
  static const Color bgColor = AppColors.fondo;
  static const Color surfaceColor = AppColors.superficie;
  static const Color primaryColor = AppColors.primario;
  static const Color textMain = AppColors.texto;
  static const Color textMuted = AppColors.textoSecundario;

  final _formKey = GlobalKey<FormState>();
  final _direccionController = TextEditingController();
  final _nivelController = TextEditingController();
  final _sectorController = TextEditingController();

  final _service = EstacionamientoService();

  bool _guardando = false;
  double? _latitud;
  double? _longitud;

  @override
  void dispose() {
    _direccionController.dispose();
    _nivelController.dispose();
    _sectorController.dispose();
    super.dispose();
  }

  InputDecoration _decoracion({required String hint, IconData? icono}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      prefixIcon: icono == null
          ? null
          : Icon(icono, color: primaryColor, size: 21),
      filled: true,
      fillColor: bgColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadios.control),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadios.control),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadios.control),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  Widget _etiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textMain,
        ),
      ),
    );
  }

  Widget _tarjeta({
    required String titulo,
    required IconData icono,
    required Widget contenido,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: primaryColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          contenido,
        ],
      ),
    );
  }

  Future<void> _abrirMapa() async {
    if (_guardando) return;

    final resultado = await Navigator.push<UbicacionEstacionamiento>(
      context,
      MaterialPageRoute(builder: (_) => const SeleccionarUbicacionScreen()),
    );

    if (!mounted || resultado == null) return;

    setState(() {
      _latitud = resultado.coordenadas.latitude;
      _longitud = resultado.coordenadas.longitude;
      if (resultado.direccion.trim().isNotEmpty) {
        _direccionController.text = resultado.direccion.trim();
      }
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_formKey.currentState!.validate()) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Iniciar cronómetro'),
          content: const Text(
            '¿Deseas iniciar el cronómetro? El tiempo comenzará a contarse '
            'desde ahora.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Iniciar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);

    try {
      await _service.iniciar(
        vehiculoId: widget.vehiculo.id,
        direccion: _direccionController.text.trim(),
        nivel: _nivelController.text.trim(),
        sector: _sectorController.text.trim(),
        latitud: _latitud,
        longitud: _longitud,
        fechaEntrada: DateTime.now(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cronómetro iniciado. Ya aparece en tu historial.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      _mostrarMensaje(
        error is StateError || error is ArgumentError
            ? error.toString().replaceFirst(
                RegExp(r'^(Bad state|Invalid argument\(s\)?):\s*'),
                '',
              )
            : 'No fue posible iniciar el cronómetro. Comprueba la conexión y los permisos de Firebase.',
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textMain,
        elevation: 0,
        title: const Text(
          'Ubicación del auto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            _tarjeta(
              titulo: 'Ubicación del auto',
              icono: Icons.location_on_outlined,
              contenido: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _etiqueta('Nivel o piso (opcional)'),
                  TextFormField(
                    controller: _nivelController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _decoracion(
                      hint: 'Ej. -2',
                      icono: Icons.layers_outlined,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _etiqueta('Sector (opcional)'),
                  TextFormField(
                    controller: _sectorController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _decoracion(
                      hint: 'Ej. B14',
                      icono: Icons.grid_view_outlined,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _etiqueta('Dirección (obligatoria)'),
                  TextFormField(
                    controller: _direccionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoracion(
                      hint: 'Ej. Av. Américo Vespucio',
                      icono: Icons.map_outlined,
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa la dirección o elígela en el mapa.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _guardando ? null : _abrirMapa,
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Seleccionar ubicación en el mapa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadios.control,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_latitud != null && _longitud != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Ubicación del mapa seleccionada',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadios.control),
                  ),
                ),
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.timer_outlined),
                label: Text(
                  _guardando ? 'Iniciando...' : 'Iniciar cronómetro',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
