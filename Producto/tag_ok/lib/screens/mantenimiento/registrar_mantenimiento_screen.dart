import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/componente_mantencion_model.dart';
import '../../data/models/mantencion_model.dart';
import '../../data/models/tipo_mantencion.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/componente_mantencion_service.dart';
import '../../data/services/mantencion_service.dart';
import '../../data/services/vehiculo_service.dart';
import '../../features/registro_inteligente/boton_foto_velocimetro.dart';
import '../../features/registro_inteligente/mantencion_extraction.dart';
import 'selector_tipo_mantencion.dart';

class RegistrarMantenimientoScreen extends StatefulWidget {
  /// Vehículo preseleccionado (el elegido en Mantenciones).
  final String? vehiculoIdInicial;

  /// Datos leídos por la IA desde una boleta o factura. Si vienen, el
  /// formulario se abre precargado para que el usuario los revise y la
  /// mantención se guarda con origen 'ia'.
  final MantencionExtraida? datosIa;

  /// Momento en que se analizó el comprobante (solo con [datosIa]).
  final DateTime? fechaCaptura;

  const RegistrarMantenimientoScreen({
    super.key,
    this.vehiculoIdInicial,
    this.datosIa,
    this.fechaCaptura,
  });

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
  final MantencionService _mantencionService = MantencionService();
  final Stream<List<ComponenteMantencion>> _componentesStream =
      ComponenteMantencionService().streamActivos();

  /// Ids de los componentes marcados: los que detectó la IA y los que el
  /// usuario marque o desmarque a mano.
  final Set<String> _componentesMarcados = {};

  bool _guardando = false;

  String get _usuarioId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  String? _vehiculoId;
  String _tipoMantenimiento = TipoMantencion.cambioAceite.etiqueta;
  DateTime _fecha = DateTime.now();

  final _kilometrajeController = TextEditingController();
  final _tallerController = TextEditingController();
  final _costoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _otroTipoController = TextEditingController();
  final _numeroComprobanteController = TextEditingController();

  final List<String> _tiposMantenimiento = TipoMantencion.etiquetas;

  static const String _sinComprobante = 'Sin comprobante';
  final List<String> _opcionesComprobante = [
    _sinComprobante,
    ...TipoComprobante.values.map((t) => t.etiqueta),
  ];
  String _comprobante = _sinComprobante;

  TipoComprobante? get _tipoComprobante =>
      TipoComprobante.fromEtiqueta(_comprobante);

  @override
  void initState() {
    super.initState();
    _vehiculoId = widget.vehiculoIdInicial;
    _precargarDatosIa();
  }

  bool get _desdeIa => widget.datosIa != null;

  void _precargarDatosIa() {
    final d = widget.datosIa;
    if (d == null) return;

    if (d.tipo != null) _tipoMantenimiento = d.tipo!.etiqueta;
    _otroTipoController.text = d.tipoOtro ?? '';
    if (d.fecha != null) _fecha = d.fecha!;
    _kilometrajeController.text = d.kilometraje?.toString() ?? '';
    _tallerController.text = d.taller ?? '';
    _costoController.text = d.costo?.toString() ?? '';
    _descripcionController.text = d.descripcion ?? '';
    _observacionesController.text = d.observaciones ?? '';
    _componentesMarcados.addAll(d.componentes);
    if (d.tipoComprobante != null) _comprobante = d.tipoComprobante!.etiqueta;
    _numeroComprobanteController.text = d.numeroComprobante ?? '';
  }

  @override
  void dispose() {
    _kilometrajeController.dispose();
    _tallerController.dispose();
    _costoController.dispose();
    _descripcionController.dispose();
    _observacionesController.dispose();
    _otroTipoController.dispose();
    _numeroComprobanteController.dispose();
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

  int? _entero(String texto) =>
      int.tryParse(texto.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _guardar() async {
    final formularioValido =
        _formKey.currentState?.validate() ?? false;

    if (!formularioValido) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    final vehiculoId = _vehiculoId;
    if (vehiculoId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecciona un vehículo.')),
      );
      return;
    }

    final tipo = TipoMantencion.fromEtiqueta(_tipoMantenimiento);
    if (tipo == TipoMantencion.otra &&
        _otroTipoController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Escribe el tipo de mantención.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await _mantencionService.crear(
        vehiculoId: vehiculoId,
        estado: EstadoMantencion.realizada,
        tipo: tipo,
        tipoOtro: _otroTipoController.text,
        fecha: _fecha,
        kilometraje: _entero(_kilometrajeController.text),
        taller: _tallerController.text,
        costo: _entero(_costoController.text),
        descripcion: _descripcionController.text,
        observaciones: _observacionesController.text,
        tipoComprobante: _tipoComprobante,
        // Sin comprobante no se guarda número aunque se haya escrito antes.
        numeroComprobante: _tipoComprobante == null
            ? null
            : _numeroComprobanteController.text,
        componentes: _componentesMarcados.toList(),
        origenRegistro: _desdeIa ? 'ia' : 'manual',
        fechaCaptura: _desdeIa ? (widget.fechaCaptura ?? DateTime.now()) : null,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Mantención registrada.')),
      );
      // `true` avisa a la pantalla de IA que ya se guardó, para que se cierre.
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('No se pudo guardar la mantención: $e');
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible guardar la mantención. Intenta nuevamente.',
          ),
        ),
      );
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
          if (snapshot.connectionState == ConnectionState.waiting) {
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
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el kilometraje.';
                    }

                    final kilometraje = int.tryParse(value.trim());

                    if (kilometraje == null || kilometraje < 0 || kilometraje > 5000000) {
                      return 'Ingresa un kilometraje válido.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                BotonFotoVelocimetro(
                  onKilometraje: (km) => setState(
                    () => _kilometrajeController.text = km.toString(),
                  ),
                ),

                const SizedBox(height: 12),

                _campo(
                  controller: _tallerController,
                  label: 'Taller',
                  hint: 'Ej: Taller AutoPro',
                  icon: Icons.storefront_outlined,
                  obligatorio: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el taller.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _campo(
                  controller: _costoController,
                  label: 'Costo',
                  hint: 'Ej: 45000',
                  icon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number,
                  obligatorio: true,
                  validator: (value) {
                    final texto = (value ?? '').trim();
                    if (texto.isEmpty) return 'Ingresa el costo.';
                    final costo = _entero(texto);
                    if (costo == null || costo > 1000000000) {
                      return 'Ingresa un costo válido.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 22),

                _tituloSeccion('Componentes revisados'),

                const SizedBox(height: 4),

                Text(
                  _desdeIa
                      ? 'Marcados según lo que la IA leyó en el comprobante. Puedes marcar o desmarcar a mano.'
                      : 'Marca los componentes a los que se les hizo mantención.',
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 6),

                _listaComponentes(),

                const SizedBox(height: 22),

                _tituloSeccion('Comprobante'),

                const SizedBox(height: 10),

                _selectorComprobante(),

                if (_tipoComprobante != null) ...[
                  const SizedBox(height: 12),
                  _campo(
                    controller: _numeroComprobanteController,
                    label: 'Número de ${_comprobante.toLowerCase()}',
                    hint: 'Ej: 458123',
                    icon: Icons.tag_rounded,
                    validator: (value) {
                      if ((value ?? '').trim().length > 50) {
                        return 'Máximo 50 caracteres.';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 22),

                _tituloSeccion('Detalles'),

                const SizedBox(height: 10),

                _campo(
                  controller: _descripcionController,
                  label: 'Descripción',
                  hint: 'Ej: Cambio de aceite y filtro de aceite',
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
                    onPressed: _guardando ? null : _guardar,
                    icon: const Icon(
                      Icons.save_outlined,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Guardar mantención',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _desdeIa ? Icons.auto_awesome_outlined : Icons.handyman_outlined,
            color: primaryColor,
            size: 26,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _desdeIa ? 'Revisa los datos detectados' : 'Nueva mantención',
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _desdeIa
                      ? 'La IA leyó tu comprobante. Corrige lo que haga falta y completa los campos obligatorios antes de guardar.'
                      : 'Registra el servicio realizado a uno de tus vehículos.',
                  style: const TextStyle(
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
    String etiqueta(VehiculoModel v) {
      final alias = (v.alias ?? '').trim();
      final nombre = alias.isNotEmpty
          ? alias
          : [v.marca, v.modelo]
              .where((e) => e != null && e.trim().isNotEmpty)
              .join(' ');
      return nombre.isEmpty ? v.patente : '$nombre · ${v.patente}';
    }

    final etiquetas = {for (final v in vehiculos) v.id: etiqueta(v)};

    return SelectorTipoMantencion(
      label: 'Vehículo',
      hint: 'Seleccionar vehículo',
      icono: Icons.directions_car_outlined,
      opciones: etiquetas.values.toList(),
      valor: etiquetas[_vehiculoId],
      flotante: true,
      onChanged: (etiquetaElegida) {
        setState(() {
          _vehiculoId = etiquetas.entries
              .firstWhere((e) => e.value == etiquetaElegida)
              .key;
        });
      },
    );
  }

  Widget _selectorTipo() {
    return SelectorTipoMantencion(
      opciones: _tiposMantenimiento,
      valor: _tipoMantenimiento,
      onChanged: (v) => setState(() => _tipoMantenimiento = v),
      otroController: _otroTipoController,
      flotante: true,
    );
  }

  Widget _listaComponentes() {
    return StreamBuilder<List<ComponenteMantencion>>(
      stream: _componentesStream,
      initialData: componentesPorDefecto,
      builder: (context, snapshot) {
        final componentes = snapshot.data ?? componentesPorDefecto;
        return Column(
          children: [
            for (final c in componentes)
              CheckboxListTile(
                value: _componentesMarcados.contains(c.id),
                onChanged: (marcado) => setState(() {
                  if (marcado == true) {
                    _componentesMarcados.add(c.id);
                  } else {
                    _componentesMarcados.remove(c.id);
                  }
                }),
                title: Text(
                  c.nombre,
                  style: const TextStyle(color: textMain, fontSize: 14),
                ),
                activeColor: primaryColor,
                checkColor: Colors.white,
                side: const BorderSide(color: textMuted),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
          ],
        );
      },
    );
  }

  /// Referencia del comprobante para el historial (RF-010). Solo se guarda el
  /// tipo y el número, nunca la imagen de la boleta o factura.
  Widget _selectorComprobante() {
    return SelectorTipoMantencion(
      label: 'Tipo de comprobante',
      hint: 'Seleccionar comprobante',
      icono: Icons.receipt_long_outlined,
      opciones: _opcionesComprobante,
      valor: _comprobante,
      onChanged: (v) => setState(() => _comprobante = v),
      flotante: true,
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