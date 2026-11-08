import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models/abastecimiento_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/abastecimiento_service.dart';
import '../../data/services/vehiculo_service.dart';
import '../../features/registro_inteligente/boton_foto_velocimetro.dart';
import '../../features/registro_inteligente/combustible_extraction.dart';
import '../../utils/validaciones_mantencion.dart';
import '../mantenimiento/selector_tipo_mantencion.dart';
import '../mantenimiento/tarjeta_mantencion.dart';
import 'gasto_combustible.dart';

/// Formulario de una carga de combustible (o de energía eléctrica). Solo la
/// fecha es obligatoria: el usuario no tiene que completar lo que no necesita.
/// Si falta uno de litros, precio o total y se conocen los otros dos, se
/// calcula al guardar.
class RegistrarCombustibleScreen extends StatefulWidget {
  /// Vehículo preseleccionado (el elegido en Combustible).
  final String? vehiculoIdInicial;

  /// Datos leídos por la IA desde una boleta o factura. Si vienen, el
  /// formulario se abre precargado para que el usuario los revise y la carga
  /// se guarda con origen 'ia'.
  final AbastecimientoExtraido? datosIa;

  /// Momento en que se analizó el comprobante (solo con [datosIa]).
  final DateTime? fechaCaptura;

  const RegistrarCombustibleScreen({
    super.key,
    this.vehiculoIdInicial,
    this.datosIa,
    this.fechaCaptura,
  });

  @override
  State<RegistrarCombustibleScreen> createState() =>
      _RegistrarCombustibleScreenState();
}

class _RegistrarCombustibleScreenState
    extends State<RegistrarCombustibleScreen> {
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFCBD5E1);
  static const Color _ambar = Color(0xFFF59E0B);

  final _formKey = GlobalKey<FormState>();

  final VehiculoService _vehiculoService = VehiculoService();
  final AbastecimientoService _service = AbastecimientoService();

  bool _guardando = false;

  String get _usuarioId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  /// Vehículos del usuario. Se crea una sola vez: si se creara dentro de
  /// build(), cada letra escrita (setState) abriría una suscripción nueva, el
  /// formulario mostraría un instante el indicador de carga y el campo
  /// perdería el foco.
  late final Stream<List<VehiculoModel>> _vehiculos =
      _vehiculoService.streamVehiculosUsuario(_usuarioId);

  String? _vehiculoId;

  TipoAbastecimiento _tipo = TipoAbastecimiento.combustible;

  /// Combustible elegido (solo en cargas de combustible).
  String? _combustible;

  /// Fecha de la boleta. Parte vacía: nunca se inventa ni se rellena con
  /// "hoy"; hay que leerla o elegirla.
  DateTime? _fecha;
  bool _errorFecha = false;

  /// Campos que la IA leyó con dudas (se resaltan hasta que el usuario los
  /// toca).
  final Set<String> _dudosos = {};

  /// Cargas ya registradas del vehículo, para advertir un kilometraje menor.
  List<AbastecimientoModel> _existentes = const [];

  final _kilometrajeController = TextEditingController();
  final _estacionController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _precioController = TextEditingController();
  final _totalController = TextEditingController();

  bool get _desdeIa => widget.datosIa != null;
  bool get _esElectrica => _tipo == TipoAbastecimiento.cargaElectrica;

  @override
  void initState() {
    super.initState();
    _vehiculoId = widget.vehiculoIdInicial;
    _precargarDatosIa();
    _cargarContexto();
  }

  /// Carga lo ya registrado del vehículo y, en el registro manual, deja el tipo
  /// de carga acorde al combustible del vehículo (eléctrico → carga
  /// eléctrica). Si falla, el formulario funciona igual.
  Future<void> _cargarContexto() async {
    final id = _vehiculoId;
    if (id == null) return;
    try {
      final lista = await _service.streamPorVehiculo(id).first;
      final vehiculo = await _vehiculoService.obtenerVehiculo(id);
      if (!mounted) return;
      setState(() {
        _existentes = lista;
        if (!_desdeIa &&
            (vehiculo?.tipoCombustible ?? '').trim().toLowerCase() ==
                combustibleElectrico.toLowerCase()) {
          _tipo = TipoAbastecimiento.cargaElectrica;
        }
      });
    } catch (e) {
      debugPrint('No se pudo cargar el contexto del vehículo: $e');
    }
  }

  void _precargarDatosIa() {
    final d = widget.datosIa;
    if (d == null) return;

    _dudosos.addAll(d.camposDudosos);
    _tipo = d.tipoAbastecimiento ?? TipoAbastecimiento.combustible;
    if (!_esElectrica && combustiblesDeCarga.contains(d.tipoCombustible)) {
      _combustible = d.tipoCombustible;
    }
    if (d.fecha != null) _fecha = d.fecha;
    _kilometrajeController.text = d.kilometraje?.toString() ?? '';
    _estacionController.text = d.estacion ?? '';
    _cantidadController.text = d.cantidad == null
        ? ''
        : formatoCantidad(d.cantidad!);
    _precioController.text = d.precioUnitario == null
        ? ''
        : formatoCantidad(d.precioUnitario!);
    _totalController.text = d.total?.toString() ?? '';
  }

  @override
  void dispose() {
    _kilometrajeController.dispose();
    _estacionController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LECTURA DE NÚMEROS
  // ------------------------------------------------------------

  int? _entero(String texto) =>
      int.tryParse(texto.replaceAll(RegExp(r'[^0-9]'), ''));

  /// Litros o kWh: acepta "32,451" y "32.451" (punto o coma decimal).
  double? _cantidad(String texto) =>
      texto.trim().isEmpty ? null : decimalDeTexto(texto);

  /// Precio por unidad: "1.289" son mil doscientos ochenta y nueve pesos (el
  /// punto separa los miles), no 1,289.
  double? _precio(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      return double.tryParse(t.replaceAll('.', ''));
    }
    return decimalDeTexto(t);
  }

  // ------------------------------------------------------------
  // FECHA
  // ------------------------------------------------------------

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final inicial = _fecha ?? hoy;
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(hoy) ? hoy : inicial,
      firstDate: DateTime(2000),
      // Una carga no puede ser futura.
      lastDate: hoy,
    );

    if (fecha != null) {
      setState(() {
        _fecha = fecha;
        _errorFecha = false;
        _dudosos.remove(dudosoCargaFecha);
      });
    }
  }

  /// Advertencia que no bloquea: el usuario decide si sigue.
  Future<bool> _confirmarAdvertencia(String titulo, String mensaje) async {
    final seguir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _ambar),
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
            child: const Text('Corregir'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Es correcto'),
          ),
        ],
      ),
    );
    return seguir == true;
  }

  /// Mayor kilometraje de una carga anterior (o del mismo día) del vehículo,
  /// si es mayor que [km].
  ({int km, DateTime fecha})? _kmMenorAlAnterior(int km, DateTime fecha) {
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    ({int km, DateTime fecha})? mayor;
    for (final c in _existentes) {
      final k = c.kilometraje;
      if (k == null) continue;
      final f = DateTime(c.fecha.year, c.fecha.month, c.fecha.day);
      if (f.isAfter(dia)) continue;
      if (mayor == null || k > mayor.km) mayor = (km: k, fecha: c.fecha);
    }
    return (mayor != null && km < mayor.km) ? mayor : null;
  }

  // ------------------------------------------------------------
  // GUARDAR
  // ------------------------------------------------------------

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);

    final vehiculoId = _vehiculoId;
    if (vehiculoId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecciona un vehículo.')),
      );
      return;
    }

    // --- Fecha: obligatoria y no futura (bloquean).
    final estadoFecha = estadoFechaMantencion(_fecha, DateTime.now());
    if (estadoFecha == EstadoFechaMantencion.vacia) {
      setState(() => _errorFecha = true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de la carga.')),
      );
      return;
    }
    if (estadoFecha == EstadoFechaMantencion.futura) {
      messenger.showSnackBar(
        const SnackBar(content: Text('La fecha no puede ser futura.')),
      );
      return;
    }
    final fecha = _fecha!;
    final km = _entero(_kilometrajeController.text);

    // Completa el dato que falta si se conocen los otros dos.
    final datos = completarCarga(
      cantidad: _cantidad(_cantidadController.text),
      precioUnitario: _precio(_precioController.text),
      total: _entero(_totalController.text),
    );

    // --- Advertencias (no bloquean): el usuario confirma.
    if (estadoFecha == EstadoFechaMantencion.antigua &&
        !await _confirmarAdvertencia(
          'Documento antiguo',
          mensajeFechaAntigua(fecha),
        )) {
      return;
    }
    if (!mounted) return;

    final menor = km == null ? null : _kmMenorAlAnterior(km, fecha);
    if (menor != null &&
        !await _confirmarAdvertencia(
          'Kilometraje menor al anterior',
          'Tu carga del ${formatoFecha(menor.fecha)} registró '
              '${formatoMiles(menor.km)} km y este kilometraje es menor. '
              '¿Es correcto?',
        )) {
      return;
    }
    if (!mounted) return;

    final cantidad = datos.cantidad;
    final precio = datos.precioUnitario;
    final total = datos.total;
    if (cantidad != null &&
        precio != null &&
        total != null &&
        !totalCuadraConCantidad(
          cantidad: cantidad,
          precioUnitario: precio,
          total: total,
        ) &&
        !await _confirmarAdvertencia(
          'El total no cuadra',
          '${formatoCantidad(cantidad)} ${_tipo.unidad} × '
              '\$${formatoMiles(precio.round())} no da '
              '\$${formatoMiles(total)}. ¿Es correcto?',
        )) {
      return;
    }
    if (!mounted) return;

    setState(() => _guardando = true);

    try {
      await _service.crear(
        vehiculoId: vehiculoId,
        fecha: fecha,
        tipoAbastecimiento: _tipo,
        kilometraje: km,
        estacionServicio: _estacionController.text,
        tipoCombustible: _esElectrica ? combustibleElectrico : _combustible,
        cantidad: cantidad,
        precioUnitario: precio,
        total: total,
        confianzaIa: _desdeIa ? widget.datosIa!.confianza : null,
        origenRegistro: _desdeIa ? 'ia' : 'manual',
        fechaCaptura: _desdeIa ? (widget.fechaCaptura ?? DateTime.now()) : null,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Carga registrada.')),
      );
      // `true` avisa a la pantalla de IA que ya se guardó, para que se cierre.
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('No se pudo guardar la carga: $e');
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No fue posible guardar la carga. Intenta nuevamente.'),
        ),
      );
    }
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
        title: const Text(
          'Registrar carga',
          style: TextStyle(color: textMain, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: textMain),
      ),
      body: StreamBuilder<List<VehiculoModel>>(
        stream: _vehiculos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
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
          if (vehiculos.isEmpty) return _sinVehiculos();

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _cabecera(),
                const SizedBox(height: 22),
                _tituloSeccion('Vehículo'),
                const SizedBox(height: 10),
                _selectorVehiculo(vehiculos),
                const SizedBox(height: 22),
                _tituloSeccion('Tipo de carga'),
                const SizedBox(height: 10),
                _selectorTipo(),
                const SizedBox(height: 22),
                _tituloSeccion('Información de la carga'),
                const SizedBox(height: 4),
                const Text(
                  'Solo la fecha es obligatoria. Completa lo que tengas a mano.',
                  style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 10),
                _selectorFecha(),
                const SizedBox(height: 12),
                _campo(
                  controller: _estacionController,
                  label: _esElectrica
                      ? 'Estación o cargador'
                      : 'Estación de servicio',
                  hint: 'Ej: Copec Av. Providencia',
                  icon: Icons.local_gas_station_outlined,
                  claveDudosa: dudosoCargaEstacion,
                  maxLength: 100,
                ),
                if (!_esElectrica) ...[
                  const SizedBox(height: 12),
                  _selectorCombustible(),
                ],
                const SizedBox(height: 12),
                _campo(
                  controller: _cantidadController,
                  label: _esElectrica ? 'Energía cargada' : 'Litros',
                  hint: _esElectrica ? 'Ej: 32,5' : 'Ej: 32,451',
                  icon: Icons.water_drop_outlined,
                  suffix: _tipo.unidad,
                  decimal: true,
                  claveDudosa: dudosoCargaCantidad,
                  validator: (v) {
                    final texto = (v ?? '').trim();
                    if (texto.isEmpty) return null;
                    final cantidad = _cantidad(texto);
                    if (cantidad == null ||
                        cantidad <= 0 ||
                        cantidad > 100000) {
                      return 'Ingresa una cantidad válida.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _campo(
                  controller: _precioController,
                  label: _esElectrica ? 'Precio por kWh' : 'Precio por litro',
                  hint: 'Ej: 1289',
                  icon: Icons.sell_outlined,
                  suffix: '\$/${_tipo.unidad}',
                  decimal: true,
                  claveDudosa: dudosoCargaPrecio,
                  validator: (v) {
                    final texto = (v ?? '').trim();
                    if (texto.isEmpty) return null;
                    final precio = _precio(texto);
                    if (precio == null || precio <= 0 || precio > 1000000) {
                      return 'Ingresa un precio válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _campo(
                  controller: _totalController,
                  label: 'Total',
                  hint: 'Ej: 45000',
                  icon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number,
                  claveDudosa: dudosoCargaTotal,
                  validator: (v) {
                    final texto = (v ?? '').trim();
                    if (texto.isEmpty) return null;
                    final total = _entero(texto);
                    if (total == null || total > 1000000000) {
                      return 'Ingresa un total válido.';
                    }
                    return null;
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    'Si dejas vacío uno de litros, precio o total y completas '
                    'los otros dos, se calcula solo.',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _campo(
                  controller: _kilometrajeController,
                  label: 'Kilometraje',
                  hint: 'Ej: 72450',
                  icon: Icons.speed_outlined,
                  keyboardType: TextInputType.number,
                  suffix: 'km',
                  claveDudosa: dudosoCargaKilometraje,
                  validator: (v) {
                    final texto = (v ?? '').trim();
                    if (texto.isEmpty) return null;
                    final km = _entero(texto);
                    if (km == null || km > 5000000) {
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
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: const Text(
                      'Guardar carga',
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
        color: primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _desdeIa
                ? Icons.auto_awesome_outlined
                : Icons.local_gas_station_outlined,
            color: primaryColor,
            size: 26,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _desdeIa ? 'Revisa los datos detectados' : 'Nueva carga',
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _desdeIa
                      ? 'La IA leyó tu boleta. Corrige lo que haga falta y '
                            'completa la fecha antes de guardar.'
                      : 'Registra una carga de combustible o de energía de '
                            'uno de tus vehículos.',
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

  /// Vehículo del filtro de Combustible desde donde se presionó el +: la carga
  /// se registra en ese vehículo y no se puede cambiar acá. Null si no viene
  /// uno válido.
  VehiculoModel? _vehiculoDelFiltro(List<VehiculoModel> vehiculos) {
    final id = widget.vehiculoIdInicial;
    if (id == null) return null;
    return vehiculos.where((v) => v.id == id).firstOrNull;
  }

  Widget _vehiculoFijo(VehiculoModel vehiculo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_outlined, color: textMuted, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo',
                  style: TextStyle(color: textMuted, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  _etiquetaVehiculo(vehiculo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textMain,
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

  Widget _selectorVehiculo(List<VehiculoModel> vehiculos) {
    final fijo = _vehiculoDelFiltro(vehiculos);
    if (fijo != null) return _vehiculoFijo(fijo);

    final etiquetas = {for (final v in vehiculos) v.id: _etiquetaVehiculo(v)};

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
        _cargarContexto();
      },
    );
  }

  /// Combustible o carga eléctrica. Siempre visible para que un híbrido pueda
  /// registrar los dos tipos de carga.
  Widget _selectorTipo() {
    return Row(
      children: [
        for (final t in TipoAbastecimiento.values) ...[
          if (t != TipoAbastecimiento.values.first) const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _tipo = t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _tipo == t ? primaryColor : surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      t == TipoAbastecimiento.combustible
                          ? Icons.local_gas_station_outlined
                          : Icons.ev_station_outlined,
                      size: 20,
                      color: _tipo == t ? Colors.white : textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.etiqueta,
                      style: TextStyle(
                        color: _tipo == t ? Colors.white : textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectorCombustible() {
    return SelectorTipoMantencion(
      label: 'Tipo de combustible',
      hint: 'Seleccionar combustible',
      icono: Icons.opacity_outlined,
      opciones: combustiblesDeCarga,
      valor: _combustible,
      flotante: true,
      onChanged: (v) => setState(() {
        _combustible = v;
        _dudosos.remove(dudosoCargaCombustible);
      }),
    );
  }

  /// Borde ámbar y aviso cuando el campo está marcado como dudoso.
  InputDecoration _conDudoso(InputDecoration base, bool dudoso) {
    if (!dudoso) return base;
    const borde = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: _ambar),
    );
    return base.copyWith(
      enabledBorder: borde,
      focusedBorder: borde,
      helperText: 'Revisa este dato antes de guardar.',
      helperStyle: const TextStyle(color: _ambar, fontSize: 11),
    );
  }

  Widget _selectorFecha() {
    final fecha = _fecha;
    final dudosa = _dudosos.contains(dudosoCargaFecha);
    var decoracion = _decoracionCampo(
      label: 'Fecha de la boleta *',
      icon: Icons.calendar_today_outlined,
    );
    if (_errorFecha) {
      decoracion = decoracion.copyWith(
        errorText: 'Selecciona la fecha de la carga.',
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.redAccent),
        ),
      );
    } else {
      decoracion = _conDudoso(decoracion, dudosa);
    }

    return InkWell(
      onTap: _seleccionarFecha,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: decoracion,
        child: Row(
          children: [
            Expanded(
              child: Text(
                fecha == null
                    ? 'Seleccionar fecha'
                    : DateFormat('dd/MM/yyyy').format(fecha),
                style: TextStyle(
                  color: fecha == null ? textMuted : textMain,
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
    bool decimal = false,
    int? maxLength,
    String? Function(String?)? validator,
    String? claveDudosa,
  }) {
    final dudoso = claveDudosa != null && _dudosos.contains(claveDudosa);
    return TextFormField(
      controller: controller,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : keyboardType,
      inputFormatters: [
        if (decimal) FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      validator: validator,
      // Al editar un campo resaltado, deja de estar resaltado.
      onChanged: (_) => setState(() {
        if (claveDudosa != null) _dudosos.remove(claveDudosa);
      }),
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: _conDudoso(
        _decoracionCampo(label: label, hint: hint, icon: icon, suffix: suffix),
        dudoso,
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
      labelStyle: const TextStyle(color: textMuted),
      hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.65)),
      suffixStyle: const TextStyle(color: textMuted),
      prefixIcon: Icon(icon, color: textMuted, size: 21),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
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
              'Primero registra un vehículo desde Mi Vehículo para poder '
              'asociarle una carga.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, height: 1.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
