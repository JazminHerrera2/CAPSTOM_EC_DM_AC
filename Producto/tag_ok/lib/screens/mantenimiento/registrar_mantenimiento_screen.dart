import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/mantencion_service.dart';
import '../../data/services/vehiculo_service.dart';
import '../../features/registro_inteligente/boton_foto_velocimetro.dart';
import '../../features/registro_inteligente/mantencion_extraction.dart';
import '../../utils/titulo_mantencion.dart';
import '../../utils/validaciones_mantencion.dart';
import 'selector_tipo_mantencion.dart';
import 'tarjeta_mantencion.dart';

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

  bool _guardando = false;

  String get _usuarioId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  String? _vehiculoId;
  /// El título lo propuso la IA y el usuario aún no lo toca.
  bool _tipoSugeridoIa = false;

  /// Fecha de emisión del documento. Parte vacía: nunca se inventa ni se
  /// rellena con "hoy"; hay que leerla o elegirla.
  DateTime? _fecha;
  bool _errorFecha = false;

  /// Campos que la IA leyó con dudas (se resaltan hasta que el usuario los
  /// toca).
  final Set<String> _dudosos = {};

  /// Mantenciones realizadas del vehículo y su último km, para sugerir el
  /// kilometraje y para las advertencias (km menor, número repetido).
  List<MantencionModel> _existentes = const [];
  int? _kmVehiculo;

  DateTime? _proximaFecha;

  final _kilometrajeController = TextEditingController();
  final _tallerController = TextEditingController();
  final _costoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _tipoController = TextEditingController();
  final _numeroComprobanteController = TextEditingController();
  final _proximoKmController = TextEditingController();

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
    _cargarContexto();
  }

  /// Carga lo ya registrado del vehículo. Si falla, el formulario funciona
  /// igual (sin sugerencia ni advertencias).
  Future<void> _cargarContexto() async {
    final id = _vehiculoId;
    if (id == null) return;
    try {
      final lista = await _mantencionService
          .streamPorVehiculo(id, estado: EstadoMantencion.realizada)
          .first;
      final vehiculo = await _vehiculoService.obtenerVehiculo(id);
      if (!mounted) return;
      setState(() {
        _existentes = lista;
        _kmVehiculo = vehiculo?.kilometrajeActual;
      });
    } catch (e) {
      debugPrint('No se pudo cargar el contexto del vehículo: $e');
    }
  }

  bool get _desdeIa => widget.datosIa != null;

  void _precargarDatosIa() {
    final d = widget.datosIa;
    if (d == null) return;

    _tipoController.text = d.tipo ?? '';
    _tipoSugeridoIa = d.tipo != null;
    _dudosos.addAll(d.camposDudosos);
    if (d.fecha != null) _fecha = d.fecha;
    _kilometrajeController.text = d.kilometraje?.toString() ?? '';
    _tallerController.text = d.taller ?? '';
    _costoController.text = d.costo?.toString() ?? '';
    _descripcionController.text = d.descripcion ?? '';
    _observacionesController.text = d.observaciones ?? '';
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
    _tipoController.dispose();
    _numeroComprobanteController.dispose();
    _proximoKmController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final inicial = _fecha ?? hoy;
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(hoy) ? hoy : inicial,
      firstDate: DateTime(2000),
      // Una mantención no puede ser futura.
      lastDate: hoy,
    );

    if (fecha != null) {
      setState(() {
        _fecha = fecha;
        _errorFecha = false;
        _dudosos.remove(dudosoFecha);
      });
    }
  }

  Future<void> _seleccionarProximaFecha() async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fecha = await showDatePicker(
      context: context,
      initialDate: _proximaFecha ?? hoy,
      firstDate: hoy,
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _proximaFecha = fecha);
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
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
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

    final tipo = normalizarTituloMantencion(_tipoController.text);
    if (tipo == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Escribe el tipo de mantención.')),
      );
      return;
    }

    // --- Fecha: obligatoria y no futura (bloquean).
    final estadoFecha = estadoFechaMantencion(_fecha, DateTime.now());
    if (estadoFecha == EstadoFechaMantencion.vacia) {
      setState(() => _errorFecha = true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de la mantención.')),
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

    // --- Próxima mantención (opcional): debe ser posterior a esta.
    final proximoKm = _entero(_proximoKmController.text);
    if (proximoKm != null && km != null && proximoKm <= km) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('El próximo kilometraje debe ser mayor al actual.'),
        ),
      );
      return;
    }
    final proxima = _proximaFecha;
    if (proxima != null && !proxima.isAfter(fecha)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('La próxima fecha debe ser posterior a la de esta mantención.'),
        ),
      );
      return;
    }

    // --- Advertencias (no bloquean): el usuario confirma.
    if (estadoFecha == EstadoFechaMantencion.antigua &&
        !await _confirmarAdvertencia(
          'Documento antiguo',
          mensajeFechaAntigua(fecha),
        )) {
      return;
    }
    if (!mounted) return;

    final menor = km == null
        ? null
        : kilometrajeMenorAlAnterior(
            km: km,
            fecha: fecha,
            existentes: _existentes,
          );
    if (menor != null &&
        !await _confirmarAdvertencia(
          'Kilometraje menor al anterior',
          'Tu mantención del ${formatoFecha(menor.fecha)} registró '
          '${formatoMiles(menor.km)} km y este kilometraje es menor. '
          '¿Es correcto?',
        )) {
      return;
    }
    if (!mounted) return;

    if (_tipoComprobante != null &&
        numeroDocumentoDuplicado(
          _numeroComprobanteController.text,
          _existentes,
        ) &&
        !await _confirmarAdvertencia(
          'Posible duplicado',
          'Ya registraste una mantención con el número '
          '${_numeroComprobanteController.text.trim()} en este vehículo. '
          '¿Quieres guardarla igual?',
        )) {
      return;
    }
    if (!mounted) return;

    setState(() => _guardando = true);

    try {
      await _mantencionService.crear(
        vehiculoId: vehiculoId,
        estado: EstadoMantencion.realizada,
        tipo: tipo,
        fecha: fecha,
        kilometraje: km,
        taller: _tallerController.text,
        costo: _entero(_costoController.text),
        descripcion: _descripcionController.text,
        observaciones: _observacionesController.text,
        tipoComprobante: _tipoComprobante,
        // Sin comprobante no se guarda número aunque se haya escrito antes.
        numeroComprobante: _tipoComprobante == null
            ? null
            : _numeroComprobanteController.text,
        proximaFecha: proxima,
        proximoKilometraje: proximoKm,
        confianzaIa: _desdeIa ? widget.datosIa!.confianza : null,
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

                _campoTipo(),

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
                  claveDudosa: dudosoKilometraje,
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

                _sugerenciaKm(),

                const SizedBox(height: 10),

                BotonFotoVelocimetro(
                  onKilometraje: (km) => setState(
                    () => _kilometrajeController.text = km.toString(),
                  ),
                ),

                const SizedBox(height: 12),

                _campo(
                  controller: _tallerController,
                  label: 'Taller (recomendado)',
                  hint: 'Ej: Taller AutoPro',
                  icon: Icons.storefront_outlined,
                  claveDudosa: dudosoTaller,
                ),

                const SizedBox(height: 12),

                _campo(
                  controller: _costoController,
                  label: 'Costo',
                  hint: 'Ej: 45000',
                  icon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number,
                  obligatorio: true,
                  claveDudosa: dudosoCosto,
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
                    claveDudosa: dudosoNumero,
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
                  claveDudosa: dudosoDescripcion,
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

                const SizedBox(height: 22),

                _tituloSeccion('Próxima mantención (opcional)'),

                const SizedBox(height: 4),

                const Text(
                  'Anota cuándo toca la siguiente, por kilometraje y/o fecha. '
                  'Por ahora solo queda registrada, no genera avisos.',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 10),

                _campo(
                  controller: _proximoKmController,
                  label: 'Próximo kilometraje',
                  hint: 'Ej: 82450',
                  icon: Icons.speed_outlined,
                  keyboardType: TextInputType.number,
                  suffix: 'km',
                  validator: (value) {
                    final texto = (value ?? '').trim();
                    if (texto.isEmpty) return null;
                    final km = _entero(texto);
                    if (km == null || km > 5000000) {
                      return 'Ingresa un kilometraje válido.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _campoProximaFecha(),

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

  String _etiquetaVehiculo(VehiculoModel v) {
    final alias = (v.alias ?? '').trim();
    final nombre = alias.isNotEmpty
        ? alias
        : [v.marca, v.modelo]
            .where((e) => e != null && e.trim().isNotEmpty)
            .join(' ');
    return nombre.isEmpty ? v.patente : '$nombre · ${v.patente}';
  }

  /// Vehículo del filtro de Mantenciones desde donde se presionó el +: la
  /// mantención se registra en ese vehículo y no se puede cambiar acá (igual
  /// que el vehículo del historial). Null si no viene uno válido.
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
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_car_outlined,
            color: textMuted,
            size: 21,
          ),
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

  Widget _selectorVehiculo(
    List<VehiculoModel> vehiculos,
  ) {
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
      },
    );
  }

  /// Título de la mantención en texto libre. Si lo propuso la IA, se avisa y
  /// se resalta hasta que el usuario lo edite (o si venía como dudoso).
  Widget _campoTipo() {
    final dudoso = _dudosos.contains(dudosoTipo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _tipoController,
          maxLength: largoMaximoTituloMantencion,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => normalizarTituloMantencion(value) == null
              ? 'Escribe el tipo de mantención.'
              : null,
          onChanged: (_) => setState(() {
            _tipoSugeridoIa = false;
            _dudosos.remove(dudosoTipo);
          }),
          style: const TextStyle(color: textMain, fontSize: 14),
          decoration: _conDudoso(
            _decoracionCampo(
              label: 'Tipo de mantención *',
              hint: 'Ej: Cambio de aceite',
              icon: Icons.build_outlined,
            ),
            dudoso,
          ),
        ),
        if (_tipoSugeridoIa)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Sugerido por la IA',
              style: TextStyle(color: textMuted, fontSize: 11),
            ),
          ),
      ],
    );
  }

  static const Color _ambar = Color(0xFFF59E0B);

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

  /// Sugerencia del último kilometraje conocido; no se escribe sola.
  Widget _sugerenciaKm() {
    final sugerido = kilometrajeSugerido(
      kmVehiculo: _kmVehiculo,
      existentes: _existentes,
    );
    if (sugerido == null ||
        _entero(_kilometrajeController.text) == sugerido) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ActionChip(
          avatar: const Icon(Icons.history_rounded, size: 16, color: primaryColor),
          label: Text(
            'Usar último km conocido: ${formatoMiles(sugerido)} km',
            style: const TextStyle(color: textMain, fontSize: 12),
          ),
          backgroundColor: surfaceColor,
          side: const BorderSide(color: borderColor),
          onPressed: () => setState(() {
            _kilometrajeController.text = sugerido.toString();
            _dudosos.remove(dudosoKilometraje);
          }),
        ),
      ),
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

  Widget _campoProximaFecha() {
    final fecha = _proximaFecha;
    return InkWell(
      onTap: _seleccionarProximaFecha,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _decoracionCampo(
          label: 'Próxima fecha',
          icon: Icons.event_outlined,
        ),
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
            if (fecha != null)
              IconButton(
                tooltip: 'Quitar fecha',
                onPressed: () => setState(() => _proximaFecha = null),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: textMuted,
              )
            else
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

  Widget _selectorFecha() {
    final fecha = _fecha;
    final dudosa = _dudosos.contains(dudosoFecha);
    var decoracion = _decoracionCampo(
      label: 'Fecha del documento *',
      icon: Icons.calendar_today_outlined,
    );
    if (_errorFecha) {
      decoracion = decoracion.copyWith(
        errorText: 'Selecciona la fecha de la mantención.',
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
    int maxLines = 1,
    bool obligatorio = false,
    String? Function(String?)? validator,
    String? claveDudosa,
  }) {
    final dudoso = claveDudosa != null && _dudosos.contains(claveDudosa);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      // Al editar un campo resaltado, deja de estar resaltado (y se refresca
      // la sugerencia de kilometraje).
      onChanged: (_) => setState(() {
        if (claveDudosa != null) _dudosos.remove(claveDudosa);
      }),
      style: const TextStyle(
        color: textMain,
        fontSize: 14,
      ),
      decoration: _conDudoso(
        _decoracionCampo(
          label: obligatorio ? '$label *' : label,
          hint: hint,
          icon: icon,
          suffix: suffix,
        ),
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