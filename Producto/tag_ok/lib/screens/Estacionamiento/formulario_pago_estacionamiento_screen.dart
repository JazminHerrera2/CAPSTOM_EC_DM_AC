import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

import '../../data/models/estacionamiento_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/estacionamiento_service.dart';
import '../../data/services/vehiculo_service.dart';
import '../../features/registro_inteligente/estacionamiento_extraction.dart';

/// Formulario con los datos del pago de un estacionamiento detenido: nombre,
/// hora de entrada, hora de salida y precio total.
///
/// Se abre desde "Registrar comprobante", igual que el formulario de
/// Combustible: con los datos que leyó la IA de la boleta ([datosIa]) o con lo
/// que ya tenía el cronómetro si se ingresa a mano. El usuario revisa, corrige
/// lo que haga falta y guarda. Al guardar, el estacionamiento queda finalizado.
class FormularioPagoEstacionamientoScreen extends StatefulWidget {
  /// Estacionamiento detenido que se está cerrando. Null si el documento crea
  /// un registro nuevo (botón + de Estacionamientos): en ese caso se necesita
  /// [vehiculoId].
  final EstacionamientoModel? estacionamiento;

  /// Vehículo del registro nuevo, cuando no hay [estacionamiento].
  final String? vehiculoId;

  /// Hora de salida del cronómetro, si se acaba de detener y el modelo que se
  /// recibió todavía no la trae.
  final DateTime? salidaInicial;

  /// Datos leídos de la boleta. Null si el pago se ingresa a mano.
  final EstacionamientoExtraido? datosIa;

  /// Cuándo se leyó la boleta con IA.
  final DateTime? fechaCaptura;

  const FormularioPagoEstacionamientoScreen({
    super.key,
    this.estacionamiento,
    this.vehiculoId,
    this.salidaInicial,
    this.datosIa,
    this.fechaCaptura,
  }) : assert(
         estacionamiento != null || vehiculoId != null,
         'Se necesita el estacionamiento o el vehículo.',
       );

  @override
  State<FormularioPagoEstacionamientoScreen> createState() =>
      _FormularioPagoEstacionamientoScreenState();
}

class _FormularioPagoEstacionamientoScreenState
    extends State<FormularioPagoEstacionamientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = EstacionamientoService();
  final _lugarController = TextEditingController();
  final _costoController = TextEditingController();
  final _observacionesController = TextEditingController();

  late DateTime _entrada;
  late DateTime _salida;
  bool _guardando = false;

  /// Vehículo del estacionamiento (se muestra fijo, como en Combustible).
  VehiculoModel? _vehiculo;

  EstacionamientoExtraido? get _ia => widget.datosIa;

  @override
  void initState() {
    super.initState();
    final e = widget.estacionamiento;
    final ia = _ia;
    _entrada = ia?.entrada ?? e?.fechaEntrada ?? DateTime.now();
    _salida =
        ia?.salida ?? widget.salidaInicial ?? e?.fechaSalida ?? DateTime.now();
    // Una salida anterior a la entrada no es válida: se parte de la entrada.
    if (_salida.isBefore(_entrada)) _salida = _entrada;
    _lugarController.text = (ia?.lugar ?? e?.lugar ?? '').trim();
    _observacionesController.text = (e?.observaciones ?? '').trim();
    _costoController.text = ia?.costo?.toString() ?? '';
    _cargarVehiculo();
  }

  Future<void> _cargarVehiculo() async {
    try {
      final v = await VehiculoService().obtenerVehiculo(
        widget.estacionamiento?.vehiculoId ?? widget.vehiculoId!,
      );
      if (mounted) setState(() => _vehiculo = v);
    } catch (_) {
      // Es solo informativo: sin el vehículo igual se puede guardar.
    }
  }

  String _etiquetaVehiculo(VehiculoModel v) {
    final alias = (v.alias ?? '').trim();
    final nombre = alias.isNotEmpty
        ? alias
        : [
            v.marca,
            v.modelo,
          ].where((e) => e != null && e.trim().isNotEmpty).join(' ');
    return nombre.isEmpty ? v.patente : '$nombre · ${v.patente}';
  }

  Widget _vehiculoFijo(VehiculoModel vehiculo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(AppRadios.control),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_car_outlined,
            color: AppColors.textoSecundario,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo',
                  style: TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _etiquetaVehiculo(vehiculo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lugarController.dispose();
    _costoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  String _dos(int n) => n.toString().padLeft(2, '0');

  String _fechaHora(DateTime f) =>
      '${_dos(f.day)}/${_dos(f.month)}/${f.year}  ${_dos(f.hour)}:${_dos(f.minute)}';

  String _duracion() {
    final minutos = duracionEnMinutos(_entrada, _salida);
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    if (horas == 0) return '$resto min';
    return resto == 0 ? '$horas h' : '$horas h $resto min';
  }

  /// Un campo que la IA marcó como dudoso se avisa debajo para que se revise.
  bool _dudoso(List<String> claves) =>
      _ia != null && claves.any(_ia!.camposDudosos.contains);

  Future<DateTime?> _elegirFechaHora(DateTime actual) async {
    final ahora = DateTime.now();
    final inicial = actual.isAfter(ahora) ? ahora : actual;
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: ahora,
      locale: const Locale('es'),
    );
    if (fecha == null || !mounted) return null;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
    );
    if (hora == null) return null;
    return DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
  }

  Future<void> _cambiarEntrada() async {
    final nueva = await _elegirFechaHora(_entrada);
    if (nueva != null && mounted) setState(() => _entrada = nueva);
  }

  Future<void> _cambiarSalida() async {
    final nueva = await _elegirFechaHora(_salida);
    if (nueva != null && mounted) setState(() => _salida = nueva);
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_formKey.currentState!.validate()) return;
    if (_salida.isBefore(_entrada)) {
      _mensaje('La salida no puede ser anterior a la entrada.');
      return;
    }
    if (_salida.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      _mensaje('La salida no puede ser una fecha futura.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final conIa = _ia != null;
      final costo = int.parse(_costoController.text.trim());
      final existente = widget.estacionamiento;
      if (existente != null) {
        await _service.registrarComprobante(
          estacionamientoId: existente.id,
          costo: costo,
          origenRegistro: conIa ? 'ia' : 'manual',
          fechaCaptura: conIa ? (widget.fechaCaptura ?? DateTime.now()) : null,
          confianzaIa: _ia?.confianza,
          lugar: _lugarController.text,
          horaEntrada: _entrada,
          horaSalida: _salida,
          observacion: _observacionesController.text,
        );
      } else {
        // Documento nuevo (botón +): se crea un registro ya finalizado.
        await _service.registrarManual(
          vehiculoId: widget.vehiculoId!,
          fecha: _entrada,
          lugar: _lugarController.text,
          horaEntrada: _entrada,
          horaSalida: _salida,
          costo: costo,
          observacion: _observacionesController.text,
          origenRegistro: conIa ? 'ia' : 'manual',
          fechaCaptura: conIa ? (widget.fechaCaptura ?? DateTime.now()) : null,
          confianzaIa: _ia?.confianza,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estacionamiento registrado.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _mensaje(
        error is StateError || error is ArgumentError
            ? error.toString().replaceFirst(
                RegExp(r'^(Bad state|Invalid argument\(s\)?):\s*'),
                '',
              )
            : 'No se pudo guardar el pago. Comprueba la conexión e inténtalo '
                  'de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ------------------------------------------------------------
  // PANTALLA
  // ------------------------------------------------------------

  InputDecoration _decoracion({required String hint, IconData? icono}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textoSecundario, fontSize: 14),
      prefixIcon: icono == null
          ? null
          : Icon(icono, color: AppColors.primario, size: 21),
      filled: true,
      fillColor: AppColors.fondo,
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

  Widget _etiqueta(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.texto,
      ),
    ),
  );

  Widget _avisoDudoso() => const Padding(
    padding: EdgeInsets.only(top: 6),
    child: Text(
      'La IA no estaba segura de este dato. Revísalo con la boleta.',
      style: TextStyle(color: AppColors.alerta, fontSize: 12),
    ),
  );

  Widget _campoFechaHora({
    required String titulo,
    required DateTime fecha,
    required VoidCallback onTap,
    bool dudoso = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(titulo),
        InkWell(
          onTap: _guardando ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadios.control),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.fondo,
              borderRadius: BorderRadius.circular(AppRadios.control),
              border: dudoso ? Border.all(color: AppColors.alerta) : null,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primario,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _fechaHora(fecha),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.texto,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.edit_outlined,
                  color: AppColors.textoSecundario,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (dudoso) _avisoDudoso(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ia = _ia;
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          backgroundColor: AppColors.fondo,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: AppColors.texto),
          title: Text(
            ia == null ? 'Datos del pago' : 'Revisa los datos',
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              if (ia != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primario.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadios.control),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        color: AppColors.primario,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ia.camposDudosos.isEmpty
                              ? 'La IA leyó la boleta. Revisa los datos y '
                                    'corrígelos si hace falta antes de guardar.'
                              : 'La IA leyó la boleta, pero algunos datos son '
                                    'dudosos y están marcados. Revísalos antes '
                                    'de guardar.',
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_vehiculo != null) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 10),
                  child: Text(
                    'Vehículo',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _vehiculoFijo(_vehiculo!),
                const SizedBox(height: 22),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(AppRadios.tarjeta),
                  boxShadow: AppSombras.tarjeta,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiqueta('Nombre del estacionamiento (opcional)'),
                    TextFormField(
                      controller: _lugarController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoracion(
                        hint: 'Ej. Mall Plaza Oeste',
                        icono: Icons.local_parking_outlined,
                      ),
                    ),
                    if (_dudoso(const [dudosoEstLugar])) _avisoDudoso(),
                    const SizedBox(height: 18),
                    _campoFechaHora(
                      titulo: 'Hora de entrada',
                      fecha: _entrada,
                      onTap: _cambiarEntrada,
                      dudoso: _dudoso(const [dudosoEstEntrada, dudosoEstFecha]),
                    ),
                    const SizedBox(height: 18),
                    _campoFechaHora(
                      titulo: 'Hora de salida',
                      fecha: _salida,
                      onTap: _cambiarSalida,
                      dudoso: _dudoso(const [dudosoEstSalida, dudosoEstDuracion]),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: AppColors.primario,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Duración: ${_duracion()}',
                          style: const TextStyle(
                            color: AppColors.textoSecundario,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _etiqueta('Precio total (CLP)'),
                    TextFormField(
                      controller: _costoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _decoracion(
                        hint: 'Ej. 3500',
                        icono: Icons.attach_money,
                      ),
                      validator: (valor) {
                        final monto = int.tryParse((valor ?? '').trim());
                        if (monto == null || monto < 0 || monto > 10000000) {
                          return 'Ingresa un monto válido en pesos.';
                        }
                        return null;
                      },
                    ),
                    if (_dudoso(const [dudosoEstCosto])) _avisoDudoso(),
                    const SizedBox(height: 18),
                    _etiqueta('Observaciones (opcional)'),
                    TextFormField(
                      controller: _observacionesController,
                      maxLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoracion(hint: 'Agrega algún detalle...'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primario,
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
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  label: Text(
                    _guardando ? 'Guardando...' : 'Guardar estacionamiento',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
