import 'package:flutter/material.dart';

import 'document_type.dart';
import 'extraction_schema_registry.dart';
import 'smart_capture_result.dart';

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

  DocumentType? _tipoSeleccionado;

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

    if (tipo == null) return;

    for (final campo
        in extractionSchemas[tipo]!.campos) {
      final valorPrevio = widget
          .resultado
          ?.campos[campo.clave]
          ?.toString();

      _controllers[campo.clave] =
          TextEditingController(
        text: valorPrevio ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
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
          DateTime.tryParse(
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

    final anio =
        fecha.year.toString().padLeft(4, '0');

    final mes =
        fecha.month.toString().padLeft(2, '0');

    final dia =
        fecha.day.toString().padLeft(2, '0');

    setState(() {
      controller.text = '$anio-$mes-$dia';
    });
  }

  // ------------------------------------------------------------
  // CONFIRMAR
  // ------------------------------------------------------------

  Future<void> _confirmar() async {
    final tipo = _tipoSeleccionado;

    if (tipo == null) {
      setState(() {
        _errorValidacion =
            'Selecciona el tipo de documento.';
      });

      return;
    }

    final schema = extractionSchemas[tipo]!;

    for (final campo in schema.campos) {
      if (campo.requerido &&
          (_controllers[campo.clave]
                  ?.text
                  .trim()
                  .isEmpty ??
              true)) {
        setState(() {
          _errorValidacion =
              'Falta completar "${campo.etiqueta}" antes de continuar.';
        });

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
        campos[entry.key] = valor;
      }
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
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorValidacion =
              'No se pudo guardar el documento. Intenta nuevamente.';
        });
      }
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

              ...extractionSchemas[
                      _tipoSeleccionado]!
                  .campos
                  .map(
                    (campo) =>
                        _construirCampo(
                      campo,
                    ),
                  ),
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