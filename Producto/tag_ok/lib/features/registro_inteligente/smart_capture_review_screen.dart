import 'package:flutter/material.dart';

import '../../utils/permiso_circulacion.dart';

import 'document_type.dart';
import 'extraction_schema_registry.dart';
import 'smart_capture_result.dart';
import 'validacion_campos.dart';

class SmartCaptureReviewScreen extends StatefulWidget {
  final SmartCaptureResult? resultado;
  final List<DocumentType> tiposPermitidos;

  final Future<void> Function({
    required DocumentType tipo,
    required Map<String, dynamic> campos,
    required bool esManual,
  }) onConfirm;

  const SmartCaptureReviewScreen({
    super.key,
    required this.resultado,
    required this.tiposPermitidos,
    required this.onConfirm,
  });

  @override
  State<SmartCaptureReviewScreen> createState() =>
      _SmartCaptureReviewScreenState();
}

class _SmartCaptureReviewScreenState
    extends State<SmartCaptureReviewScreen> {
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF27364D);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoMorado = Color(0xFF8B5CF6);

  DocumentType? _tipoSeleccionado;

  /// Casilla de pago marcada en el permiso: la propone la IA y el usuario la
  /// confirma.
  FormaPagoPermiso? _formaPago;

  final Map<String, TextEditingController> _controllers = {};

  bool _guardando = false;
  String? _errorValidacion;

  // ------------------------------------------------------------
  // INICIO
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _tipoSeleccionado =
        widget.resultado?.tipoDetectado;

    _inicializarControllers();
  }

  void _inicializarControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    _controllers.clear();

    final tipo = _tipoSeleccionado;

    _formaPago = FormaPagoPermiso.fromFirestore(
      widget.resultado?.campos[claveFormaPago]?.toString(),
    );

    if (tipo == null) return;

    for (final campo
        in extractionSchemas[tipo]!.campos) {
      final valorPrevio = widget
          .resultado
          ?.campos[campo.clave]
          ?.toString();

      _controllers[campo.clave] =
          TextEditingController(
        text: _esCampoFecha(campo.clave)
            ? _fechaVisible(valorPrevio)
            : (valorPrevio ?? ''),
      );
    }

    // Con la casilla marcada y la emisión conocidas, el vencimiento es el que
    // dicen las reglas, aunque la IA haya leído otro (el usuario puede
    // corregirlo).
    _recalcularVencimiento();
  }

  /// `true` si el tipo elegido pide forma de pago (hoy, el permiso).
  bool get _pideFormaPago =>
      _tipoSeleccionado == DocumentType.permisoCirculacion;

  /// Vencimiento según la forma de pago y la fecha de emisión que muestra el
  /// formulario, o null si falta alguna.
  DateTime? _vencimientoCalculado() {
    final forma = _formaPago;
    final emision = interpretarFecha(_controllers['fecha_emision']?.text ?? '');
    if (!_pideFormaPago || forma == null || emision == null) return null;
    return fechaVencimientoPermiso(formaPago: forma, fechaEmision: emision);
  }

  /// Completa el campo de vencimiento con el calculado, si se puede.
  void _recalcularVencimiento() {
    final vencimiento = _vencimientoCalculado();
    final campo = _controllers['fecha_vencimiento'];
    if (vencimiento != null && campo != null) {
      campo.text = formatoFechaCl(vencimiento);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  /// Fecha para mostrar: "DD/MM/YYYY". Si no se puede interpretar, se deja
  /// el texto tal cual para que el usuario lo corrija.
  String _fechaVisible(String? texto) {
    if (texto == null || texto.trim().isEmpty) return '';
    final fecha = interpretarFecha(texto);
    return fecha == null ? texto : formatoFechaCl(fecha);
  }

  /// Fecha para guardar: "YYYY-MM-DD" (el formato que recibe `onConfirm`).
  String _fechaParaGuardar(String texto) {
    final fecha = interpretarFecha(texto);
    return fecha == null ? texto : formatoIsoFecha(fecha);
  }

  /// `true` si [clave] se estimó (no figuraba en el documento) y el usuario
  /// todavía no la modificó.
  bool _fechaEstimadaVigente(String clave) {
    final resultado = widget.resultado;
    if (resultado == null || !resultado.camposEstimados.contains(clave)) {
      return false;
    }
    final actual = interpretarFecha(_controllers[clave]?.text ?? '');
    final estimada = interpretarFecha(resultado.campos[clave]?.toString() ?? '');
    return actual != null && actual == estimada;
  }

  // ------------------------------------------------------------
  // IA - CAMPO DUDOSO
  // ------------------------------------------------------------

  bool _esDudoso(String clave) {
    return widget.resultado?.camposDudosos
            .contains(clave) ??
        false;
  }

  // ------------------------------------------------------------
  // DETECTAR SI ES UNA FECHA
  // ------------------------------------------------------------

  bool _esCampoFecha(String clave) {
    return clave == 'fecha_emision' ||
        clave == 'fecha_vencimiento';
  }

  // ------------------------------------------------------------
  // SELECCIONAR FECHA
  // ------------------------------------------------------------

  Future<void> _seleccionarFecha(
    String clave,
  ) async {
    final controller = _controllers[clave];

    if (controller == null) return;

    DateTime fechaInicial = DateTime.now();

    if (controller.text.trim().isNotEmpty) {
      final fechaExistente =
          interpretarFecha(
        controller.text.trim(),
      );

      if (fechaExistente != null) {
        fechaInicial = fechaExistente;
      }
    }

    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (fecha == null) return;

    setState(() {
      controller.text = formatoFechaCl(fecha);
      if (clave == 'fecha_emision') _recalcularVencimiento();
    });
  }

  // ------------------------------------------------------------
  // CONFIRMAR
  // ------------------------------------------------------------

  /// Muestra el error en el cuadro rojo de la pantalla y también como aviso,
  /// porque el cuadro queda al final y puede no estar a la vista.
  void _mostrarError(String mensaje, {bool terminarGuardado = false}) {
    if (!mounted) return;

    setState(() {
      if (terminarGuardado) _guardando = false;
      _errorValidacion = mensaje;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.redAccent,
        ),
      );
  }

  Future<void> _confirmar() async {
    final tipo = _tipoSeleccionado;

    if (tipo == null) {
      _mostrarError('Selecciona el tipo de documento.');

      return;
    }

    final schema = extractionSchemas[tipo]!;

    if (tipo == DocumentType.permisoCirculacion && _formaPago == null) {
      _mostrarError('Selecciona la casilla marcada en el permiso (Total, Cuota 1 o Cuota 2).');

      return;
    }

    for (final campo in schema.campos) {
      if (campo.requerido &&
          (_controllers[campo.clave]
                  ?.text
                  .trim()
                  .isEmpty ??
              true)) {
        _mostrarError(
          'Falta completar "${campo.etiqueta}" antes de continuar.',
        );

        return;
      }
    }

    setState(() {
      _errorValidacion = null;
      _guardando = true;
    });

    final campos = <String, dynamic>{};

    for (final entry in _controllers.entries) {
      final valor = entry.value.text.trim();

      if (valor.isNotEmpty) {
        campos[entry.key] =
            _esCampoFecha(entry.key) ? _fechaParaGuardar(valor) : valor;
      }
    }

    if (tipo == DocumentType.permisoCirculacion) {
      campos[claveFormaPago] = _formaPago!.valorFirestore;
    }

    // Una fecha estimada sigue marcada como tal solo si el usuario no la
    // cambió; si la corrigió, pasa a ser un dato confirmado por él.
    if (_fechaEstimadaVigente('fecha_emision')) {
      campos[claveFechaEmisionEstimada] = 'true';
    }

    try {
      await widget.onConfirm(
        tipo: tipo,
        campos: campos,
        esManual: widget.resultado == null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('No se pudo guardar el documento: $e');
      _mostrarError(
        e is SmartCaptureValidationException
            ? e.mensaje
            : 'No se pudo agregar el documento. Intenta nuevamente.',
        terminarGuardado: true,
      );
    }
  }

  // ------------------------------------------------------------
  // CAMPO
  // ------------------------------------------------------------

  Widget _construirCampo(dynamic campo) {
    final controller =
        _controllers[campo.clave]!;

    final dudoso =
        _esDudoso(campo.clave);

    final esFecha =
        _esCampoFecha(campo.clave);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  campo.etiqueta,
                  style: TextStyle(
                    color: dudoso
                        ? warningColor
                        : textMuted,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              if (campo.requerido)
                const Text(
                  'Obligatorio',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 7),

          TextField(
            controller: controller,
            readOnly: esFecha,
            onTap: esFecha
                ? () => _seleccionarFecha(
                      campo.clave,
                    )
                : null,
            style: const TextStyle(
              color: textMain,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: esFecha
                  ? 'Seleccionar fecha'
                  : 'Ingresa ${campo.etiqueta.toLowerCase()}',
              hintStyle: const TextStyle(
                color: textMuted,
                fontSize: 13,
              ),
              filled: true,
              fillColor: surfaceColor,

              prefixIcon: esFecha
                  ? const Icon(
                      Icons
                          .calendar_today_outlined,
                      color: textMuted,
                      size: 19,
                    )
                  : null,

              suffixIcon: dudoso
                  ? const Tooltip(
                      message:
                          'La IA no está completamente segura de este dato',
                      child: Icon(
                        Icons
                            .warning_amber_rounded,
                        color: warningColor,
                      ),
                    )
                  : null,

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: dudoso
                      ? warningColor
                          .withOpacity(0.6)
                      : const Color(
                          0xFF334155,
                        ),
                ),
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: dudoso
                      ? warningColor
                      : primaryColor,
                  width: 1.5,
                ),
              ),

              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 16,
              ),
            ),
          ),

          if (_fechaEstimadaVigente(campo.clave)) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: textMuted,
                  size: 13,
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Estimada: el documento solo indica el año, así que se usó la fecha de hoy. Corrígela si no es correcta.',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (dudoso) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: warningColor,
                  size: 13,
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Revisa este dato antes de confirmar.',
                    style: TextStyle(
                      color: warningColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FORMA DE PAGO (PERMISO DE CIRCULACIÓN)
  // ------------------------------------------------------------

  /// Aviso morado que explica cómo se calcula la vigencia según lo pagado.
  Widget _avisoPermiso() {
    const base = TextStyle(color: textMain, fontSize: 12, height: 1.45);
    const negrita = TextStyle(fontWeight: FontWeight.w700);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: infoMorado.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: infoMorado.withOpacity(0.5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: infoMorado, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  TextSpan(
                    text: 'Vigencia de tu permiso\n',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  TextSpan(text: '• Si pagaste el '),
                  TextSpan(text: 'total', style: negrita),
                  TextSpan(
                    text: ', tu permiso está vigente hasta el 31 de marzo del próximo año.\n',
                  ),
                  TextSpan(text: '• Si pagaste solo la '),
                  TextSpan(text: 'cuota 1', style: negrita),
                  TextSpan(
                    text: ', vence el 31 de agosto de este mismo año. Cuando pagues la cuota 2, vuelve a fotografiar el permiso ya pagado en 2 cuotas.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorFormaPago() {
    final vencimiento = _vencimientoCalculado();
    final propuestaPorIa =
        widget.resultado?.campos[claveFormaPago] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Casilla marcada en el permiso',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Obligatorio',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Mismos botones que el filtro de documentos de Mi Vehículo.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final forma in FormaPagoPermiso.values)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() {
                    _formaPago = forma;
                    _recalcularVencimiento();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _formaPago == forma ? primaryColor : surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _formaPago == forma
                            ? primaryColor
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Text(
                      forma.etiqueta,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: _formaPago == forma ? Colors.white : textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formaPago == null
                ? 'Elige la casilla marcada (Total, Cuota 1 o Cuota 2) para calcular el vencimiento.'
                : vencimiento != null
                    ? '${propuestaPorIa ? "Propuesta por la IA. " : ""}${_formaPago == FormaPagoPermiso.cuota1 ? "Falta pagar la segunda cuota: " : "Permiso pagado: "}vence el ${formatoFechaCl(vencimiento)}.'
                    : 'Ingresa la fecha de emisión para calcular el vencimiento.',
            style: const TextStyle(
              color: textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PANTALLA
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final esManual =
        widget.resultado == null;

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
          esManual
              ? 'Registrar documento'
              : 'Revisar y confirmar',
          style: const TextStyle(
            color: textMain,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            35,
          ),
          children: [
            // ----------------------------------------------------
            // CABECERA
            // ----------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: esManual
                    ? surfaceColor
                    : primaryColor
                        .withOpacity(0.10),
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: esManual
                      ? const Color(
                          0xFF334155,
                        )
                      : primaryColor
                          .withOpacity(0.40),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: esManual
                          ? surfaceLight
                          : primaryColor
                              .withOpacity(0.18),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Icon(
                      esManual
                          ? Icons
                              .edit_note_outlined
                          : Icons
                              .auto_awesome_outlined,
                      color: primaryColor,
                      size: 25,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          esManual
                              ? 'Ingreso manual'
                              : 'Datos detectados con IA',
                          style:
                              const TextStyle(
                            color: textMain,
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          esManual
                              ? 'Completa los datos del documento antes de guardarlo.'
                              : 'Revisa la información detectada. Puedes corregir cualquier dato antes de guardar.',
                          style:
                              const TextStyle(
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
            ),

            // ----------------------------------------------------
            // IA NO IDENTIFICÓ EL DOCUMENTO
            // ----------------------------------------------------

            if (!esManual &&
                _tipoSeleccionado == null) ...[
              const SizedBox(height: 14),

              Container(
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: warningColor
                      .withOpacity(0.10),
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: warningColor
                        .withOpacity(0.55),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .warning_amber_rounded,
                      color: warningColor,
                      size: 20,
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'No pudimos identificar automáticamente el tipo de documento. Selecciónalo para continuar.',
                        style: TextStyle(
                          color: textMain,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 26),

            // ----------------------------------------------------
            // TIPO DOCUMENTO
            // ----------------------------------------------------

            const Text(
              'Tipo de documento',
              style: TextStyle(
                color: textMain,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Selecciona el documento que estás registrando.',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<
                DocumentType>(
              value: _tipoSeleccionado,
              dropdownColor: surfaceColor,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: textMuted,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: surfaceColor,

                prefixIcon: const Icon(
                  Icons
                      .description_outlined,
                  color: primaryColor,
                  size: 20,
                ),

                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(
                    color:
                        Color(0xFF334155),
                  ),
                ),

                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(
                    color: primaryColor,
                    width: 1.5,
                  ),
                ),
              ),

              style: const TextStyle(
                color: textMain,
                fontSize: 14,
              ),

              hint: const Text(
                'Selecciona un tipo',
                style: TextStyle(
                  color: textMuted,
                ),
              ),

              items: widget.tiposPermitidos
                  .map(
                    (tipo) =>
                        DropdownMenuItem(
                      value: tipo,
                      child: Text(
                        extractionSchemas[
                                tipo]!
                            .etiqueta,
                      ),
                    ),
                  )
                  .toList(),

              onChanged: (tipo) {
                setState(() {
                  _tipoSeleccionado =
                      tipo;

                  _inicializarControllers();

                  _errorValidacion =
                      null;
                });
              },
            ),

            // ----------------------------------------------------
            // DATOS
            // ----------------------------------------------------

            if (_tipoSeleccionado !=
                null) ...[
              const SizedBox(height: 28),

              const Text(
                'Datos del documento',
                style: TextStyle(
                  color: textMain,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Los campos marcados como obligatorios deben completarse.',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 16),

              if (_pideFormaPago) _avisoPermiso(),

              ...extractionSchemas[
                      _tipoSeleccionado]!
                  .campos
                  .map(
                    (campo) =>
                        _construirCampo(
                      campo,
                    ),
                  ),

              if (_pideFormaPago) _selectorFormaPago(),
            ],

            // ----------------------------------------------------
            // ERROR
            // ----------------------------------------------------

            if (_errorValidacion !=
                null) ...[
              const SizedBox(height: 4),

              Container(
                padding:
                    const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.redAccent
                      .withOpacity(0.10),
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent
                        .withOpacity(0.40),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color:
                          Colors.redAccent,
                      size: 18,
                    ),

                    const SizedBox(width: 9),

                    Expanded(
                      child: Text(
                        _errorValidacion!,
                        style:
                            const TextStyle(
                          color:
                              Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ----------------------------------------------------
            // BOTÓN
            // ----------------------------------------------------

            if (_tipoSeleccionado !=
                null) ...[
              const SizedBox(height: 24),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed:
                      _guardando
                          ? null
                          : _confirmar,

                  icon: _guardando
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : Icon(
                          esManual
                              ? Icons
                                  .save_outlined
                              : Icons
                                  .check_circle_outline,
                          color:
                              Colors.white,
                        ),

                  label: Text(
                    _guardando
                        ? 'Guardando...'
                        : esManual
                            ? 'Guardar documento'
                            : 'Confirmar y guardar',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        primaryColor,
                    disabledBackgroundColor:
                        primaryColor
                            .withOpacity(0.45),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}