import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/services/mantencion_service.dart';
import '../../utils/titulo_mantencion.dart';
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

  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
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
      'Programa tus próximas mantenciones por fecha, por kilometraje o por ambos. Si eliges fecha, te avisamos 7 días antes y el mismo día.',
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
          color: Colors.transparent,
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

  Future<void> _mostrarProgramarMantencion(BuildContext context) =>
      mostrarProgramarMantencion(context, vehiculoId: vehiculoId);
}

/// Abre la ventana para programar una mantención del vehículo. La usan esta
/// pantalla y la página principal de Mantenciones.
Future<void> mostrarProgramarMantencion(
  BuildContext context, {
  required String? vehiculoId,
}) async {
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

  /// Elimina una programación (y sus recordatorios) tras confirmar.
  Future<void> _eliminar(MantencionModel m) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar programación'),
        content: Text(
          '¿Eliminar la mantención programada "${m.nombreTipo}"? También se '
          'borrarán sus recordatorios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE11D48)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await MantencionService().eliminar(m.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Programación eliminada.')),
      );
    } catch (e) {
      debugPrint('No se pudo eliminar la programación ${m.id}: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar. Intenta nuevamente.'),
        ),
      );
    }
  }

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
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
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
                child: TarjetaMantencion(
                  mantencion: m,
                  onEliminar: () => _eliminar(m),
                ),
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

/// Cómo se programa la próxima mantención: por fecha, por kilometraje o por
/// ambos.
enum _ModoProgramacion {
  fecha('Por fecha'),
  kilometraje('Por kilometraje'),
  ambos('Ambos');

  const _ModoProgramacion(this.etiqueta);
  final String etiqueta;
}

class _ProgramarMantencionSheetState
    extends State<_ProgramarMantencionSheet> {
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFCBD5E1);
  static const Color fondoCampo = Color(0xFFF1F5F9);

  final TextEditingController _tipoController = TextEditingController();

  final MantencionService _service = MantencionService();
  final TextEditingController _kmController = TextEditingController();
  _ModoProgramacion _modo = _ModoProgramacion.fecha;
  DateTime? _proximaFecha;
  bool _guardando = false;
  String? _error;

  bool get _usaFecha => _modo != _ModoProgramacion.kilometraje;
  bool get _usaKm => _modo != _ModoProgramacion.fecha;

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _proximaFecha ?? hoy,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 10, 12, 31),
    );
    if (fecha != null) {
      setState(() {
        _proximaFecha = fecha;
        _error = null;
      });
    }
  }

  Future<void> _programar() async {
    final tipo = normalizarTituloMantencion(_tipoController.text);
    if (tipo == null) {
      setState(() => _error = 'Escribe el tipo de mantención.');
      return;
    }

    // Solo se exige lo que el modo elegido usa.
    DateTime? fecha;
    if (_usaFecha) {
      fecha = _proximaFecha;
      if (fecha == null) {
        setState(() => _error = 'Selecciona la fecha de la próxima mantención.');
        return;
      }
    }

    int? km;
    if (_usaKm) {
      final textoKm = _kmController.text.replaceAll(RegExp(r'[^0-9]'), '');
      km = int.tryParse(textoKm);
      if (km == null || km <= 0 || km > 5000000) {
        setState(
            () => _error = 'Ingresa el kilometraje de la próxima mantención.');
        return;
      }
    }

    setState(() {
      _error = null;
      _guardando = true;
    });

    try {
      // Con fecha, el servicio también deja programados los recordatorios.
      await _service.crear(
        vehiculoId: widget.vehiculoId,
        estado: EstadoMantencion.programada,
        tipo: tipo,
        proximaFecha: fecha,
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
    _tipoController.dispose();
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
              'Programa la próxima mantención por fecha, por kilometraje o por '
              'ambos.',
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 22),

            _campoTipo(),

            const SizedBox(height: 18),

            _selectorModo(),

            if (_usaFecha) ...[
              const SizedBox(height: 14),
              _campoFecha(),
            ],

            if (_usaKm) ...[
              const SizedBox(height: 14),
              _campoKilometraje(),
            ],

            const SizedBox(height: 14),

            _avisoRecordatorios(),

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

  /// Tres botones del mismo tamaño: por fecha, por kilometraje o ambos.
  Widget _selectorModo() {
    return Row(
      children: [
        for (final modo in _ModoProgramacion.values) ...[
          if (modo != _ModoProgramacion.values.first) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _modo = modo;
                _error = null;
              }),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: _modo == modo ? primaryColor : fondoCampo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    modo.etiqueta,
                    style: TextStyle(
                      color: _modo == modo ? Colors.white : textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Aviso de los recordatorios: se generan solo si hay fecha.
  Widget _avisoRecordatorios() {
    final conFecha = _usaFecha;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fondoCampo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            conFecha
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: conFecha ? primaryColor : textMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              conFecha
                  ? 'Se generarán recordatorios 7 días antes y el mismo día de '
                      'la fecha programada.'
                  : 'Sin una fecha no se generan recordatorios. Elige "Por '
                      'fecha" o "Ambos" para recibirlos.',
              style: const TextStyle(
                color: textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
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
          color: fondoCampo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent),
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
                    'Fecha de la próxima mantención',
                    style: TextStyle(color: textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _proximaFecha == null
                        ? 'Seleccionar fecha'
                        : formatoFecha(_proximaFecha!),
                    style: TextStyle(
                      color: _proximaFecha == null ? textMuted : textMain,
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

  Widget _campoTipo() {
    return TextField(
      controller: _tipoController,
      maxLength: largoMaximoTituloMantencion,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: textMain, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Tipo de mantención',
        hintText: 'Ej: Cambio de aceite',
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        counterStyle: const TextStyle(color: textMuted),
        prefixIcon: const Icon(Icons.build_outlined, color: textMuted, size: 21),
        filled: true,
        fillColor: fondoCampo,
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

  Widget _campoKilometraje() {
    return TextField(
      controller: _kmController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: textMain, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Kilometraje de la próxima mantención',
        hintText: 'Ej: 80000',
        suffixText: 'km',
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        prefixIcon: const Icon(Icons.speed_outlined, color: textMuted, size: 21),
        filled: true,
        fillColor: fondoCampo,
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
