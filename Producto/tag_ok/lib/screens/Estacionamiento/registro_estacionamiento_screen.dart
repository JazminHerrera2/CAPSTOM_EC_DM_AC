
import 'package:flutter/material.dart';

import '../../data/models/vehiculo_model.dart';
import '../../data/services/estacionamiento_service.dart';
import 'seleccionar_ubicacion_screen.dart';

class RegistroEstacionamientoScreen extends StatefulWidget {
  final VehiculoModel vehiculo;

  const RegistroEstacionamientoScreen({
    super.key,
    required this.vehiculo,
  });

  @override
  State<RegistroEstacionamientoScreen> createState() =>
      _RegistroEstacionamientoScreenState();
}

class _RegistroEstacionamientoScreenState extends State<RegistroEstacionamientoScreen>  {
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Colors.white;
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final _lugarController = TextEditingController();
  final _direccionController = TextEditingController();
  final _nivelController = TextEditingController();
  final _sectorController = TextEditingController();
  final _observacionesController = TextEditingController();

  final _service = EstacionamientoService();

  late DateTime _fechaEntrada;

  bool _guardando = false;
  double? _latitud;
  double? _longitud;

  @override
  void initState() {
    super.initState();

    _fechaEntrada = DateTime.now();
  }

  @override
  void dispose() {
    _lugarController.dispose();
    _direccionController.dispose();
    _nivelController.dispose();
    _sectorController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  String _dosDigitos(int numero) =>
      numero.toString().padLeft(2, '0');

  String _formatoFechaHora(DateTime fecha) {
    return '${_dosDigitos(fecha.day)}/'
        '${_dosDigitos(fecha.month)}/'
        '${fecha.year}  '
        '${_dosDigitos(fecha.hour)}:'
        '${_dosDigitos(fecha.minute)}';
  }

  Future<void> _seleccionarFechaHora() async {
    final ahora = DateTime.now();
    final actual = _fechaEntrada.isAfter(ahora) ? ahora : _fechaEntrada;

    final fecha = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2020),
      lastDate: ahora,
      locale: const Locale('es'),
    );
    if (fecha == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (hora == null || !mounted) return;

    final seleccion = DateTime(
      fecha.year, fecha.month, fecha.day, hora.hour, hora.minute,
    );
    if (seleccion.isAfter(DateTime.now())) {
      _mostrarMensaje('La entrada no puede ser una fecha futura.');
      return;
    }
    setState(() => _fechaEntrada = seleccion);
  }

  InputDecoration _decoracion({
    required String hint,
    IconData? icono,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: textMuted,
        fontSize: 14,
      ),
      prefixIcon: icono == null
          ? null
          : Icon(icono, color: primaryColor, size: 21),
      filled: true,
      fillColor: bgColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Widget _etiqueta(String texto, {bool obligatorio = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        obligatorio ? '$texto *' : texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textMain,
        ),
      ),
    );
  }

  Widget _campoFechaHora({
    required String titulo,
    required DateTime fecha,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(titulo, obligatorio: true),
        InkWell(
          onTap: _guardando ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: primaryColor,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatoFechaHora(fecha),
                    style: const TextStyle(
                      fontSize: 14,
                      color: textMain,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.edit_outlined,
                  color: textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(18),
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
      MaterialPageRoute(
        builder: (_) => const SeleccionarUbicacionScreen(),
      ),
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

    if (_fechaEntrada.isAfter(DateTime.now())) {
      _mostrarMensaje(
        'La entrada no puede ser una fecha futura.',
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Iniciar estacionamiento'),
          content: const Text(
            '¿Deseas iniciar el estacionamiento? El tiempo comenzará a contarse desde la fecha y hora de entrada seleccionadas.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
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
        lugar: _lugarController.text.trim(),
        direccion: _direccionController.text.trim(),
        nivel: _nivelController.text.trim(),
        sector: _sectorController.text.trim(),
        latitud: _latitud,
        longitud: _longitud,
        fechaEntrada: _fechaEntrada,
        observaciones: _observacionesController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Estacionamiento iniciado. Ya aparece en tu historial.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      _mostrarMensaje(
        error is StateError || error is ArgumentError
            ? error.toString().replaceFirst(RegExp(r'^(Bad state|Invalid argument\(s\)?):\s*'), '')
            : 'No fue posible iniciar el estacionamiento. Comprueba la conexión y los permisos de Firebase.',
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
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
          'Iniciar estacionamiento',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Container(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  widget.vehiculo.patente,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            _tarjeta(
              titulo: 'Ubicación',
              icono: Icons.location_on_outlined,
              contenido: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _etiqueta(
                    'Nombre del estacionamiento',
                    obligatorio: true,
                  ),
                  TextFormField(
                    controller: _lugarController,
                    textCapitalization:
                        TextCapitalization.sentences,
                    decoration: _decoracion(
                      hint: 'Ej. Mall Plaza Oeste',
                      icono: Icons.local_parking_outlined,
                    ),
                    validator: (valor) {
                      if (valor == null ||
                          valor.trim().isEmpty) {
                        return 'Ingresa el lugar del estacionamiento.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _etiqueta('Dirección (opcional)'),
                  TextFormField(
                    controller: _direccionController,
                    textCapitalization:
                        TextCapitalization.sentences,
                    decoration: _decoracion(
                      hint: 'Ej. Av. Américo Vespucio',
                      icono: Icons.map_outlined,
                    ),
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
                          borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 18),
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            _tarjeta(
               titulo: 'Fecha y hora de entrada',
               icono: Icons.access_time_outlined,
               contenido: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _campoFechaHora(
                     titulo: 'Fecha y hora de entrada',
                     fecha: _fechaEntrada,
                     onTap: _seleccionarFechaHora,
                   ),
                   const SizedBox(height: 12),
                   const Text(
                     'El cronómetro comenzará desde esta fecha y hora al iniciar el estacionamiento.',
                     style: TextStyle(color: textMuted, fontSize: 12),
                   ),
                 ],
               ),
             ),

            const SizedBox(height: 16),

            _tarjeta(
              titulo: 'Observaciones',
              icono: Icons.notes_outlined,
              contenido: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _etiqueta('Observaciones (opcional)'),
                  TextFormField(
                    controller: _observacionesController,
                    maxLines: 3,
                    textCapitalization:
                        TextCapitalization.sentences,
                    decoration: _decoracion(
                      hint: 'Agrega algún detalle...',
                    ),
                  ),
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
                    borderRadius: BorderRadius.circular(14),
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
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _guardando
                      ? 'Iniciando...'
                      : 'Iniciar estacionamiento',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            const Center(
              child: Text(
                '* Campos obligatorios',
                style: TextStyle(
                  fontSize: 12,
                  color: textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
