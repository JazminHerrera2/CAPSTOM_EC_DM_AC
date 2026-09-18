import 'package:flutter/material.dart';
import 'document_type.dart';
import 'extraction_schema_registry.dart';
import 'smart_capture_result.dart';

/// Pantalla genérica de revisión y confirmación (CU36-CU38, RNF-004/RNF-005).
///
/// No sabe nada de Firestore ni de ningún módulo: recibe un
/// [SmartCaptureResult] (o null para ingreso manual desde cero, CU40) y al
/// confirmar delega el guardado al módulo llamante vía [onConfirm]. Esto es
/// lo que la hace reusable por Mantenciones/Estacionamientos/Combustible
/// sin cambiar este archivo — cada módulo solo pasa sus propios
/// [tiposPermitidos] y su propia lógica de persistencia en [onConfirm].
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

class _SmartCaptureReviewScreenState extends State<SmartCaptureReviewScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color surfaceColor = const Color(0xFF1E293B);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color warningColor = const Color(0xFFF59E0B);

  DocumentType? _tipoSeleccionado;
  final Map<String, TextEditingController> _controllers = {};
  bool _guardando = false;
  String? _errorValidacion;

  @override
  void initState() {
    super.initState();
    _tipoSeleccionado = widget.resultado?.tipoDetectado;
    _inicializarControllers();
  }

  void _inicializarControllers() {
    _controllers.forEach((_, c) => c.dispose());
    _controllers.clear();

    final tipo = _tipoSeleccionado;
    if (tipo == null) return;

    for (final campo in extractionSchemas[tipo]!.campos) {
      final valorPrevio = widget.resultado?.campos[campo.clave]?.toString();
      _controllers[campo.clave] = TextEditingController(text: valorPrevio ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _esDudoso(String clave) =>
      widget.resultado?.camposDudosos.contains(clave) ?? false;

  Future<void> _confirmar() async {
    final tipo = _tipoSeleccionado;
    if (tipo == null) {
      setState(() => _errorValidacion = 'Selecciona el tipo de documento.');
      return;
    }

    final schema = extractionSchemas[tipo]!;
    for (final campo in schema.campos) {
      if (campo.requerido &&
          (_controllers[campo.clave]?.text.trim().isEmpty ?? true)) {
        setState(
          () => _errorValidacion =
              'Falta completar "${campo.etiqueta}" antes de confirmar.',
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
      if (valor.isNotEmpty) campos[entry.key] = valor;
    }

    try {
      await widget.onConfirm(
        tipo: tipo,
        campos: campos,
        esManual: widget.resultado == null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorValidacion = 'No se pudo guardar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esManual = widget.resultado == null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          esManual ? 'Registrar documento' : 'Revisar datos detectados',
          style: TextStyle(color: textMain),
        ),
        iconTheme: IconThemeData(color: textMain),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!esManual && _tipoSeleccionado == null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: warningColor),
                ),
                child: Text(
                  'No se pudo identificar automáticamente el tipo de documento. '
                  'Selecciónalo manualmente para continuar.',
                  style: TextStyle(color: textMain),
                ),
              ),
            Text(
              'Tipo de documento',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<DocumentType>(
              value: _tipoSeleccionado,
              dropdownColor: surfaceColor,
              decoration: InputDecoration(
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: textMain),
              hint: Text('Selecciona un tipo', style: TextStyle(color: textMuted)),
              items: widget.tiposPermitidos
                  .map(
                    (tipo) => DropdownMenuItem(
                      value: tipo,
                      child: Text(extractionSchemas[tipo]!.etiqueta),
                    ),
                  )
                  .toList(),
              onChanged: (tipo) {
                setState(() {
                  _tipoSeleccionado = tipo;
                  _inicializarControllers();
                });
              },
            ),
            const SizedBox(height: 20),
            if (_tipoSeleccionado != null)
              ...extractionSchemas[_tipoSeleccionado]!.campos.map((campo) {
                final dudoso = _esDudoso(campo.clave);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: _controllers[campo.clave],
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(
                      labelText: campo.requerido
                          ? '${campo.etiqueta} *'
                          : campo.etiqueta,
                      labelStyle: TextStyle(
                        color: dudoso ? warningColor : textMuted,
                      ),
                      suffixIcon: dudoso
                          ? Icon(Icons.warning_amber_rounded, color: warningColor)
                          : null,
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                );
              }),
            if (_errorValidacion != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorValidacion!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _guardando ? null : _confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
