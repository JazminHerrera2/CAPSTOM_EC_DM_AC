// PANTALLA DE PRUEBA del módulo Estacionamientos (no es la pantalla final).
// Sirve para probar EstacionamientoService, el registro con IA, el mapa
// "¿Dónde está mi auto?" y la dirección escrita mientras no llegue el front
// del módulo (Almendra). La abre, TEMPORALMENTE, la acción rápida
// "Estacionamiento" del Inicio (inicio_dashboard_screen.dart). Esa conexión SE
// DEBE QUITAR antes de unir la rama a develop/main o de publicar la web o el
// APK. Ver CAMBIOS_ESTACIONAMIENTOS.md, cambios 8 y 9.
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/estacionamiento_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/estacionamiento_service.dart';
import '../../data/services/ubicacion_service.dart';
import '../../data/services/vehiculo_service.dart';
import '../../features/registro_inteligente/estacionamiento_extraction.dart';
import '../../features/registro_inteligente/validacion_campos.dart';
import 'direccion_de_ubicacion.dart';
import 'mapa_auto_screen.dart';

/// Pantalla de prueba del módulo Estacionamientos (no es la pantalla final:
/// ver el comentario al inicio del archivo).
class PruebaEstacionamientoScreen extends StatefulWidget {
  const PruebaEstacionamientoScreen({super.key});

  @override
  State<PruebaEstacionamientoScreen> createState() =>
      _PruebaEstacionamientoScreenState();
}

/// Estado de la pantalla de prueba: vehículo elegido, estacionamiento
/// activo, historial y un reloj que actualiza el cronómetro cada segundo.
class _PruebaEstacionamientoScreenState
    extends State<PruebaEstacionamientoScreen> {
  final _servicio = EstacionamientoService();
  final _lugar = TextEditingController();
  late final Stream<List<VehiculoModel>> _vehiculos = VehiculoService()
      .streamVehiculosUsuario(FirebaseAuth.instance.currentUser?.uid ?? '');

  String? _vehiculoId;
  Stream<EstacionamientoModel?>? _activo;
  Stream<List<EstacionamientoModel>>? _historial;
  bool _ocupado = false;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Refresca el cronómetro cada segundo.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _lugar.dispose();
    super.dispose();
  }

  /// Al elegir un vehículo, empieza a escuchar su estacionamiento activo y
  /// su historial.
  void _elegirVehiculo(String? id) {
    setState(() {
      _vehiculoId = id;
      _activo = id == null ? null : _servicio.streamActivo(id);
      _historial = id == null ? null : _servicio.streamPorVehiculo(id);
    });
  }

  /// Muestra un aviso abajo: verde si salió bien, rojo si hubo un error.
  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  /// Ejecuta una acción del servicio bloqueando los botones mientras tanto,
  /// y muestra el resultado (o el error, con el mensaje del GPS si aplica).
  Future<void> _hacer(Future<void> Function() accion, String ok) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (mounted) _mensaje(ok);
    } on ErrorUbicacion catch (e) {
      if (mounted) _mensaje(e.mensaje, error: true);
    } catch (e) {
      if (mounted) _mensaje('$e', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// "Iniciar estacionamiento" (HU-16).
  Future<void> _iniciar() => _hacer(
        () => _servicio.iniciar(vehiculoId: _vehiculoId!, lugar: _lugar.text),
        'Estacionamiento iniciado.',
      );

  /// "Guardar ubicación" (HU-18): lee el GPS y lo guarda en el estacionamiento.
  Future<void> _guardarUbicacion(EstacionamientoModel e) => _hacer(() async {
        final posicion = await UbicacionService().obtenerUbicacionActual();
        await _servicio.guardarUbicacion(e.id, posicion);
      }, 'Ubicación guardada.');

  /// "Finalizar estacionamiento" (HU-17): pide el costo (opcional) y finaliza.
  Future<void> _finalizar(EstacionamientoModel e) async {
    final costoTexto = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar estacionamiento'),
        content: TextField(
          controller: costoTexto,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Costo (opcional, en pesos)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmado != true) return;
    final costo = int.tryParse(costoTexto.text.replaceAll(RegExp(r'[^0-9]'), ''));
    await _hacer(() => _servicio.finalizar(e.id, costo: costo), 'Estacionamiento finalizado.');
  }

  /// HU-19: sube la foto o PDF del ticket, la IA lo lee y se abre la revisión
  /// (HU-20 y HU-21). Si la IA falla, se avisa (CU19 E2: registrar a mano).
  Future<void> _registrarConIa() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final archivo = resultado?.files.firstOrNull;
    final bytes = archivo?.bytes;
    if (archivo == null || bytes == null || !mounted) return;
    final nombre = archivo.name.toLowerCase();
    final mime = nombre.endsWith('.pdf')
        ? 'application/pdf'
        : nombre.endsWith('.png') ? 'image/png' : 'image/jpeg';

    setState(() => _ocupado = true);
    EstacionamientoExtraido? datos;
    try {
      datos = await extraerEstacionamiento(bytes: bytes, mimeType: mime);
    } catch (e) {
      if (mounted) _mensaje('La IA no pudo leer el ticket. Regístralo a mano. ($e)', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    final leidos = datos;
    if (leidos == null || !mounted) return;
    if (leidos.vacia) {
      _mensaje('La IA no encontró datos en el ticket. Regístralo a mano.', error: true);
      return;
    }
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _RevisionIaScreen(vehiculoId: _vehiculoId!, datos: leidos),
      ),
    );
    if (guardado == true && mounted) _mensaje('Estacionamiento registrado con IA.');
  }

  /// Abre "¿Dónde está mi auto?" con la ubicación guardada.
  void _verMapa(EstacionamientoModel e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaAutoScreen(ubicacionAuto: e.ubicacion!, lugar: e.lugar),
      ),
    );
  }

  /// Minutos como "1 h 35 min" o "45 min".
  String _duracion(int? minutos) {
    if (minutos == null) return '—';
    final h = minutos ~/ 60, m = minutos % 60;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  /// Fecha y hora cortas, por ejemplo "12/11 09:15".
  String _hora(DateTime? f) => f == null
      ? '—'
      : '${f.day}/${f.month} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estacionamiento (PRUEBA)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade100,
            child: const Text(
              'Pantalla de prueba local para el servicio y el mapa. '
              'La pantalla real del módulo la hace Almendra.',
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<VehiculoModel>>(
            stream: _vehiculos,
            builder: (context, snap) {
              final lista = snap.data ?? const <VehiculoModel>[];
              return DropdownButtonFormField<String>(
                initialValue: _vehiculoId,
                decoration: const InputDecoration(labelText: 'Vehículo'),
                items: [
                  for (final v in lista)
                    DropdownMenuItem(
                      value: v.id,
                      child: Text('${v.patente}${v.alias != null ? ' · ${v.alias}' : ''}'),
                    ),
                ],
                onChanged: _elegirVehiculo,
              );
            },
          ),
          const SizedBox(height: 16),
          if (_vehiculoId != null)
            StreamBuilder<EstacionamientoModel?>(
              stream: _activo,
              builder: (context, snap) {
                if (snap.hasError) return Text('Error: ${snap.error}');
                final e = snap.data;
                if (e == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _lugar,
                        decoration: const InputDecoration(labelText: 'Lugar (opcional)'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _ocupado ? null : _iniciar,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar estacionamiento'),
                      ),
                    ],
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('En curso · ${e.titulo}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Desde ${_hora(e.horaEntrada)} · lleva ${_duracion(e.minutosTranscurridos())}'),
                        Text(e.tieneUbicacion
                            ? 'Ubicación guardada: ${e.ubicacion!.latitude.toStringAsFixed(5)}, ${e.ubicacion!.longitude.toStringAsFixed(5)}'
                            : 'Sin ubicación guardada'),
                        if (e.tieneUbicacion)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: DireccionDeUbicacion(ubicacion: e.ubicacion!),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _ocupado ? null : () => _guardarUbicacion(e),
                          icon: const Icon(Icons.my_location),
                          label: const Text('Guardar ubicación'),
                        ),
                        OutlinedButton.icon(
                          onPressed: e.tieneUbicacion ? () => _verMapa(e) : null,
                          icon: const Icon(Icons.map),
                          label: const Text('Ver dónde está mi auto'),
                        ),
                        FilledButton.icon(
                          onPressed: _ocupado ? null : () => _finalizar(e),
                          icon: const Icon(Icons.stop),
                          label: const Text('Finalizar estacionamiento'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_vehiculoId != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _registrarConIa,
              icon: _ocupado
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_ocupado ? 'Analizando…' : 'Registrar con IA (foto o PDF del ticket)'),
            ),
          ],
          const SizedBox(height: 24),
          if (_vehiculoId != null) ...[
            const Text('Historial', style: TextStyle(fontWeight: FontWeight.bold)),
            StreamBuilder<List<EstacionamientoModel>>(
              stream: _historial,
              builder: (context, snap) {
                if (snap.hasError) return Text('Error: ${snap.error}');
                final lista = snap.data ?? const <EstacionamientoModel>[];
                if (lista.isEmpty) return const Text('Sin registros.');
                return Column(
                  children: [
                    for (final e in lista)
                      ListTile(
                        leading: Icon(e.estaActivo ? Icons.timer : Icons.local_parking),
                        title: Text('${e.titulo} · ${e.estado.etiqueta}'
                            '${e.tieneUbicacion ? '' : ' · sin ubicación'}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_hora(e.horaEntrada)} → ${_hora(e.horaSalida)} · '
                              '${_duracion(e.minutosTranscurridos())}'
                              '${e.costo != null ? ' · \$${e.costo}' : ''}',
                            ),
                            if (e.tieneUbicacion)
                              DireccionDeUbicacion(ubicacion: e.ubicacion!),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _hacer(() => _servicio.eliminar(e.id), 'Eliminado.'),
                        ),
                        onTap: () => e.tieneUbicacion
                            ? _verMapa(e)
                            : _mensaje(
                                'Este estacionamiento no tiene ubicación guardada. '
                                'Se guarda con "Guardar ubicación" antes de finalizar.',
                                error: true),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Revisión de lo que leyó la IA (HU-20 completar o corregir, HU-21 confirmar).
/// Solo para la prueba local: el formulario real es el registro manual del
/// front, precargado con estos datos.
class _RevisionIaScreen extends StatefulWidget {
  const _RevisionIaScreen({required this.vehiculoId, required this.datos});

  final String vehiculoId;
  final EstacionamientoExtraido datos;

  @override
  State<_RevisionIaScreen> createState() => _RevisionIaScreenState();
}

/// Estado del formulario: un campo por dato, precargado con lo que leyó la IA.
class _RevisionIaScreenState extends State<_RevisionIaScreen> {
  late final _lugar = TextEditingController(text: widget.datos.lugar ?? '');
  late final _fecha = TextEditingController(
      text: widget.datos.fecha == null ? '' : formatoFechaCl(widget.datos.fecha!));
  late final _entrada = TextEditingController(text: _hora(widget.datos.horaEntrada));
  late final _fechaSalida = TextEditingController(
      text: widget.datos.fechaSalida == null ? '' : formatoFechaCl(widget.datos.fechaSalida!));
  late final _salida = TextEditingController(text: _hora(widget.datos.horaSalida));
  late final _duracion = TextEditingController(text: widget.datos.duracionMin?.toString() ?? '');
  late final _costo = TextEditingController(text: widget.datos.costo?.toString() ?? '');
  bool _guardando = false;

  /// Hora leída como "09:05"; vacía si la IA no la leyó.
  static String _hora(HoraDelDia? h) => h == null
      ? ''
      : '${h.hora.toString().padLeft(2, '0')}:${h.minuto.toString().padLeft(2, '0')}';

  /// Un campo del formulario. Si la IA dudó de ese dato, se pinta en naranja
  /// con "Revisa este dato".
  Widget _campo(String etiqueta, TextEditingController c, String clave, {String? ayuda}) {
    final dudoso = widget.datos.camposDudosos.contains(clave);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: etiqueta,
          helperText: dudoso ? 'Revisa este dato: la IA no está segura' : ayuda,
          helperStyle: dudoso ? TextStyle(color: Colors.orange.shade800) : null,
          enabledBorder: dudoso
              ? OutlineInputBorder(borderSide: BorderSide(color: Colors.orange.shade700, width: 2))
              : const OutlineInputBorder(),
          border: const OutlineInputBorder(),
          filled: dudoso,
          fillColor: Colors.orange.shade50,
        ),
      ),
    );
  }

  /// "Confirmar y guardar" (HU-21): arma fecha y hora completas (con el
  /// cruce de medianoche) y lo guarda como registro de la IA.
  Future<void> _confirmar() async {
    final fecha = interpretarFecha(_fecha.text);
    if (fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La fecha es obligatoria (DD/MM/AAAA).')));
      return;
    }
    // Se reutiliza la misma lógica de la IA para armar fecha y hora completas
    // (incluido el cruce de medianoche).
    final editado = EstacionamientoExtraido(
      fecha: fecha,
      horaEntrada: interpretarHora(_entrada.text),
      horaSalida: interpretarHora(_salida.text),
      fechaSalida: _fechaSalida.text.trim().isEmpty ? null : interpretarFecha(_fechaSalida.text),
    );
    setState(() => _guardando = true);
    try {
      await EstacionamientoService().registrarManual(
        vehiculoId: widget.vehiculoId,
        fecha: editado.entrada ?? fecha,
        lugar: _lugar.text,
        horaEntrada: editado.entrada,
        horaSalida: editado.salida,
        duracionMin: minutosDeTexto(_duracion.text),
        costo: int.tryParse(_costo.text.replaceAll(RegExp(r'[^0-9]'), '')),
        origenRegistro: 'ia',
        fechaCaptura: DateTime.now(),
        confianzaIa: widget.datos.confianza,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final confianza = widget.datos.confianza;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar ticket (PRUEBA)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Revisa los datos que leyó la IA, completa los que falten y confirma. '
            '${confianza == null ? '' : 'Confianza: ${(confianza * 100).round()}%.'}',
          ),
          const SizedBox(height: 16),
          _campo('Lugar', _lugar, dudosoEstLugar),
          _campo('Fecha de entrada', _fecha, dudosoEstFecha, ayuda: 'DD/MM/AAAA (obligatoria)'),
          _campo('Hora de entrada', _entrada, dudosoEstEntrada, ayuda: 'HH:MM'),
          _campo('Fecha de salida', _fechaSalida, dudosoEstSalida,
              ayuda: 'Solo si es otro día (DD/MM/AAAA)'),
          _campo('Hora de salida', _salida, dudosoEstSalida, ayuda: 'HH:MM, vacío si no aparece'),
          _campo('Duración (minutos)', _duracion, dudosoEstDuracion,
              ayuda: 'Si hay entrada y salida, se calcula con ellas'),
          _campo('Costo (pesos)', _costo, dudosoEstCosto),
          FilledButton.icon(
            onPressed: _guardando ? null : _confirmar,
            icon: const Icon(Icons.check),
            label: const Text('Confirmar y guardar'),
          ),
          TextButton(
            onPressed: _guardando ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar (no se guarda)'),
          ),
        ],
      ),
    );
  }
}
