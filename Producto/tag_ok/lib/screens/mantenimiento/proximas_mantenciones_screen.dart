import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/models/tipo_mantencion.dart';
import '../../data/services/mantencion_service.dart';
import 'selector_tipo_mantencion.dart';
import 'tarjeta_mantencion.dart';

class ProximasMantenimientosScreen extends StatelessWidget {
  /// Patente del vehículo elegido en Mantenciones.
  final String? patente;

  /// Vehículo elegido en Mantenciones; sus mantenciones son las que se listan.
  final String? vehiculoId;

  const ProximasMantenimientosScreen({
    super.key,
    this.patente,
    this.vehiculoId,
  });

  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textMain),
        title: const Text(
          'Próximas mantenciones',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'programarMantencion',
        backgroundColor: primaryColor,
        tooltip: 'Programar mantención',
        onPressed: () => _mostrarProgramarMantencion(context),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          children: [
            _cabecera(),

            const SizedBox(height: 24),

            const Text(
              'Mantenciones programadas',
              style: TextStyle(
                color: textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            _ListaProgramadas(
              vehiculoId: vehiculoId,
              vacio: _estadoVacio(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecera() {
    return const Text(
      'Indica la fecha de tu última mantención: la próxima se programa a un año y te avisamos 7 días antes y el mismo día.',
      style: TextStyle(
        color: textMuted,
        fontSize: 13,
        height: 1.45,
      ),
    );
  }

  Widget _estadoVacio(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: Color(0xFFF59E0B),
              size: 32,
            ),
          ),

          const SizedBox(height: 17),

          const Text(
            'No tienes mantenciones programadas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Programa tu próxima mantención para llevar un mejor control del cuidado de tu vehículo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 22),

          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                _mostrarProgramarMantencion(context);
              },
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Programar mantención',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarProgramarMantencion(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = vehiculoId;
    if (id == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Primero registra un vehículo.')),
      );
      return;
    }

    final guardada = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ProgramarMantencionSheet(vehiculoId: id),
    );

    if (guardada == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Mantención programada.')),
      );
    }
  }
}

// ==================================================================
// LISTA DE MANTENCIONES PROGRAMADAS
// ==================================================================

class _ListaProgramadas extends StatefulWidget {
  final String? vehiculoId;

  /// Se muestra cuando el vehículo no tiene mantenciones programadas.
  final Widget vacio;

  const _ListaProgramadas({required this.vehiculoId, required this.vacio});

  @override
  State<_ListaProgramadas> createState() => _ListaProgramadasState();
}

class _ListaProgramadasState extends State<_ListaProgramadas> {
  Stream<List<MantencionModel>>? _stream;

  @override
  void initState() {
    super.initState();
    final id = widget.vehiculoId;
    if (id != null) {
      _stream = MantencionService()
          .streamPorVehiculo(id, estado: EstadoMantencion.programada);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return widget.vacio;

    return StreamBuilder<List<MantencionModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                'No fue posible cargar las mantenciones.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          );
        }

        final lista = snapshot.data!;
        if (lista.isEmpty) return widget.vacio;

        return Column(
          children: [
            for (final m in lista)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TarjetaMantencion(mantencion: m),
              ),
          ],
        );
      },
    );
  }
}

// ==================================================================
// VENTANA PARA PROGRAMAR MANTENCIÓN
// ==================================================================

class _ProgramarMantencionSheet extends StatefulWidget {
  final String vehiculoId;

  const _ProgramarMantencionSheet({required this.vehiculoId});

  @override
  State<_ProgramarMantencionSheet> createState() =>
      _ProgramarMantencionSheetState();
}

class _ProgramarMantencionSheetState
    extends State<_ProgramarMantencionSheet> {
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF334155);

  String? _tipo;
  final TextEditingController _otroTipoController = TextEditingController();

  static final List<String> _tipos = TipoMantencion.etiquetas;

  final MantencionService _service = MantencionService();
  final TextEditingController _kmController = TextEditingController();
  DateTime? _ultimaFecha;
  bool _guardando = false;
  String? _error;

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _ultimaFecha ?? hoy,
      firstDate: DateTime(2000),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
    );
    if (fecha != null) setState(() => _ultimaFecha = fecha);
  }

  Future<void> _programar() async {
    final etiqueta = _tipo;
    if (etiqueta == null) {
      setState(() => _error = 'Selecciona el tipo de mantención.');
      return;
    }
    final tipo = TipoMantencion.fromEtiqueta(etiqueta);
    if (tipo == TipoMantencion.otra &&
        _otroTipoController.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el tipo de mantención.');
      return;
    }

    final ultima = _ultimaFecha;
    if (ultima == null) {
      setState(() => _error = 'Selecciona la fecha de la última mantención.');
      return;
    }

    int? km;
    final textoKm = _kmController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (textoKm.isNotEmpty) {
      km = int.tryParse(textoKm);
      if (km == null || km > 5000000) {
        setState(() => _error = 'Ingresa un kilometraje válido.');
        return;
      }
    }

    setState(() {
      _error = null;
      _guardando = true;
    });

    try {
      await _service.crear(
        vehiculoId: widget.vehiculoId,
        estado: EstadoMantencion.programada,
        tipo: tipo,
        tipoOtro: _otroTipoController.text,
        proximaFecha: proximaMantencionAnual(ultima),
        proximoKilometraje: km,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('No se pudo programar la mantención: $e');
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No fue posible programar la mantención. Intenta nuevamente.';
      });
    }
  }

  @override
  void dispose() {
    _otroTipoController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Programar mantención',
              style: TextStyle(
                color: textMain,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'La próxima mantención se programa a un año de la última.',
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 22),

            SelectorTipoMantencion(
              opciones: _tipos,
              valor: _tipo,
              onChanged: (v) => setState(() => _tipo = v),
              otroController: _otroTipoController,
              flotante: true,
            ),

            const SizedBox(height: 22),

            _campoFecha(),

            if (_ultimaFecha != null) ...[
              const SizedBox(height: 10),
              Text(
                'Próxima mantención: ${formatoFecha(proximaMantencionAnual(_ultimaFecha!))}',
                style: const TextStyle(
                  color: Color(0xFFA5B4FC),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 12),

            _campoKilometraje(),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFF87171),
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _programar,
                icon: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
                label: const Text(
                  'Programar mantención',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoFecha() {
    return InkWell(
      onTap: _elegirFecha,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: textMuted,
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fecha de la última mantención',
                    style: TextStyle(color: textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _ultimaFecha == null
                        ? 'Seleccionar fecha'
                        : formatoFecha(_ultimaFecha!),
                    style: TextStyle(
                      color: _ultimaFecha == null ? textMuted : textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoKilometraje() {
    return TextField(
      controller: _kmController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: textMain, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Próximo kilometraje (opcional)',
        hintText: 'Ej: 80000',
        suffixText: 'km',
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        prefixIcon: const Icon(Icons.speed_outlined, color: textMuted, size: 21),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }
}
