import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/vehiculo_model.dart';
import '../../data/services/mantenimiento_service.dart';
import '../../data/services/vehiculo_service.dart';

class RegistrarMantenimientoScreen extends StatefulWidget {
  const RegistrarMantenimientoScreen({super.key});

  @override
  State<RegistrarMantenimientoScreen> createState() =>
      _RegistrarMantenimientoScreenState();
}

class _RegistrarMantenimientoScreenState
    extends State<RegistrarMantenimientoScreen> {
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF334155);

  final _formKey = GlobalKey<FormState>();

  final VehiculoService _vehiculoService = VehiculoService();
  final MantenimientoService _mantenimientoService =
      MantenimientoService();

  String get _usuarioId =>
    FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  String? _vehiculoId;
  String _tipoMantenimiento = 'Cambio de aceite';
  DateTime _fecha = DateTime.now();

  final _kilometrajeController = TextEditingController();
  final _tallerController = TextEditingController();
  final _costoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _observacionesController = TextEditingController();

  bool _guardando = false;

  final List<String> _tiposMantenimiento = const [
    'Cambio de aceite',
    'Revisión general',
    'Cambio de filtros',
    'Frenos',
    'Neumáticos',
    'Alineación y balanceo',
    'Batería',
    'Sistema eléctrico',
    'Motor',
    'Preventiva',
    'Otra',
  ];

  @override
  void dispose() {
    _kilometrajeController.dispose();
    _tallerController.dispose();
    _costoController.dispose();
    _descripcionController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      setState(() {
        _fecha = fecha;
      });
    }
  }

  double? _obtenerCosto() {
    final texto = _costoController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll('\$', '');

    if (texto.isEmpty) {
      return null;
    }

    return double.tryParse(texto);
  }

  Future<void> _guardar() async {
    debugPrint('=== GUARDAR MANTENCION ===');
    debugPrint('Vehiculo ID: $_vehiculoId');
    debugPrint('Kilometraje: ${_kilometrajeController.text}');

    final formularioValido =
        _formKey.currentState?.validate() ?? false;

    debugPrint('Formulario valido: $formularioValido');

    if (!formularioValido) {
      debugPrint('DETENIDO: formulario invalido');
      return;
    }

    if (_vehiculoId == null) {
      debugPrint('DETENIDO: no hay vehiculo seleccionado');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un vehículo.'),
        ),
      );

      return;
    }

    final kilometraje =
        int.tryParse(_kilometrajeController.text.trim());

    if (kilometraje == null) {
      debugPrint('DETENIDO: kilometraje invalido');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un kilometraje válido.'),
        ),
      );

      return;
    }

    setState(() {
      _guardando = true;
    });

    debugPrint('Intentando guardar en Firestore...');

    try {
      final id =
          await _mantenimientoService.registrarMantenimiento(
        vehiculoId: _vehiculoId!,
        tipoMantenimiento: _tipoMantenimiento,
        fecha: _fecha,
        kilometraje: kilometraje,
        taller: _tallerController.text,
        costo: _obtenerCosto(),
        descripcion: _descripcionController.text,
        observaciones: _observacionesController.text,
      );

      debugPrint('GUARDADO CORRECTAMENTE');
      debugPrint('ID mantenimiento: $id');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mantención registrada correctamente.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e, stackTrace) {
      debugPrint('ERROR AL GUARDAR MANTENCION: $e');
      debugPrint('STACKTRACE: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'Registrar mantención',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(
          color: textMain,
        ),
      ),
      body: StreamBuilder<List<VehiculoModel>>(
        stream: _vehiculoService.streamVehiculosUsuario(_usuarioId),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'No fue posible cargar tus vehículos.',
                style: TextStyle(color: textMuted),
              ),
            );
          }

          final vehiculos = snapshot.data ?? [];

          if (vehiculos.isEmpty) {
            return _sinVehiculos();
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                32,
              ),
              children: [
                _cabecera(),

                const SizedBox(height: 22),

                _tituloSeccion('Vehículo'),

                const SizedBox(height: 10),

                _selectorVehiculo(vehiculos),

                const SizedBox(height: 22),

                _tituloSeccion('Información de la mantención'),

                const SizedBox(height: 10),

                _selectorTipo(),

                const SizedBox(height: 12),

                _selectorFecha(),

                const SizedBox(height: 12),

                _campo(
                  controller: _kilometrajeController,
                  label: 'Kilometraje',
                  hint: 'Ej: 72450',
                  icon: Icons.speed_outlined,
                  keyboardType: TextInputType.number,
                  suffix: 'km',
                  obligatorio: true,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Ingresa el kilometraje.';
                    }

                    final kilometraje =
                        int.tryParse(value.trim());

                    if (kilometraje == null ||
                        kilometraje < 0) {
                      return 'Ingresa un kilometraje válido.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _campo(
                  controller: _tallerController,
                  label: 'Taller',
                  hint: 'Ej: Taller AutoPro',
                  icon: Icons.storefront_outlined,
                ),

                const SizedBox(height: 12),

                _campo(
                  controller: _costoController,
                  label: 'Costo',
                  hint: 'Ej: 45000',
                  icon: Icons.attach_money_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),

                const SizedBox(height: 22),

                _tituloSeccion('Detalles'),

                const SizedBox(height: 10),

                _campo(
                  controller: _descripcionController,
                  label: 'Descripción',
                  hint:
                      'Ej: Cambio de aceite y filtro de aceite',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),

                const SizedBox(height: 12),

                _campo(
                  controller: _observacionesController,
                  label: 'Observaciones',
                  hint:
                      'Agrega información adicional si es necesario',
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                            color: Colors.white,
                          ),
                    label: Text(
                      _guardando
                          ? 'Guardando...'
                          : 'Guardar mantención',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor:
                          primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cabecera() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withOpacity(0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.handyman_outlined,
            color: primaryColor,
            size: 26,
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nueva mantención',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Registra el servicio realizado a uno de tus vehículos.',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        color: textMain,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _selectorVehiculo(
    List<VehiculoModel> vehiculos,
  ) {
    return DropdownButtonFormField<String>(
      value: _vehiculoId,
      dropdownColor: surfaceColor,
      iconEnabledColor: textMuted,
      decoration: _decoracionCampo(
        label: 'Seleccionar vehículo',
        icon: Icons.directions_car_outlined,
      ),
      style: const TextStyle(
        color: textMain,
        fontSize: 14,
      ),
      items: vehiculos.map((vehiculo) {
        final alias =
            (vehiculo.alias ?? '').trim();

        final nombre = alias.isNotEmpty
            ? alias
            : '${vehiculo.marca} ${vehiculo.modelo}';

        return DropdownMenuItem<String>(
          value: vehiculo.id,
          child: Text(
            '$nombre · ${vehiculo.patente}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _vehiculoId = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Selecciona un vehículo.';
        }
        return null;
      },
    );
  }

  Widget _selectorTipo() {
    return DropdownButtonFormField<String>(
      value: _tipoMantenimiento,
      dropdownColor: surfaceColor,
      iconEnabledColor: textMuted,
      decoration: _decoracionCampo(
        label: 'Tipo de mantención',
        icon: Icons.build_outlined,
      ),
      style: const TextStyle(
        color: textMain,
        fontSize: 14,
      ),
      items: _tiposMantenimiento
          .map(
            (tipo) => DropdownMenuItem<String>(
              value: tipo,
              child: Text(tipo),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _tipoMantenimiento = value;
        });
      },
    );
  }

  Widget _selectorFecha() {
    return InkWell(
      onTap: _seleccionarFecha,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _decoracionCampo(
          label: 'Fecha',
          icon: Icons.calendar_today_outlined,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy').format(_fecha),
                style: const TextStyle(
                  color: textMain,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_month_outlined,
              color: textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? suffix,
    int maxLines = 1,
    bool obligatorio = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        color: textMain,
        fontSize: 14,
      ),
      decoration: _decoracionCampo(
        label: obligatorio ? '$label *' : label,
        hint: hint,
        icon: icon,
        suffix: suffix,
      ),
    );
  }

  InputDecoration _decoracionCampo({
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      labelStyle: const TextStyle(
        color: textMuted,
      ),
      hintStyle: TextStyle(
        color: textMuted.withOpacity(0.65),
      ),
      suffixStyle: const TextStyle(
        color: textMuted,
      ),
      prefixIcon: Icon(
        icon,
        color: textMuted,
        size: 21,
      ),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Widget _sinVehiculos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              color: textMuted,
              size: 55,
            ),
            const SizedBox(height: 16),
            const Text(
              'No tienes vehículos registrados',
              style: TextStyle(
                color: textMain,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Primero registra un vehículo desde Mi Vehículo para poder asociarle una mantención.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}