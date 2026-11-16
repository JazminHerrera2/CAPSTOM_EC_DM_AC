import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

import '../../data/models/estacionamiento_model.dart';
import '../../data/services/geocoding_service.dart';
import '../estacionamientos/mapa_auto_screen.dart';
import '../mantenimiento/widgets_gasto.dart' show clp;

/// Lo que se muestra como lugar del auto en el mapa: el nombre (si lo hay),
/// el nivel y el sector, por ejemplo "Mall Plaza · Nivel -2 · Sector B14".
String? _lugarParaMapa(EstacionamientoModel e) {
  final partes = [
    e.lugar.trim(),
    if ((e.nivel ?? '').trim().isNotEmpty) 'Nivel ${e.nivel!.trim()}',
    if ((e.sector ?? '').trim().isNotEmpty) 'Sector ${e.sector!.trim()}',
  ].where((p) => p.isNotEmpty).toList();
  return partes.isEmpty ? null : partes.join(' · ');
}

/// `true` si hay algo con qué ubicar el auto en el mapa: el punto guardado o,
/// al menos, la dirección escrita.
bool puedeVerUbicacion(EstacionamientoModel e) =>
    e.tieneUbicacion || (e.direccion ?? '').trim().isNotEmpty;

/// Abre el mapa "¿Dónde está mi auto?" con la ubicación del estacionamiento.
/// Si solo se escribió la dirección (sin elegir el punto en el mapa), se busca
/// primero en Mapbox. Si no se encuentra, lo avisa.
Future<void> verUbicacionEnMapa(
  BuildContext context,
  EstacionamientoModel e,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  GeoPoint? punto = e.ubicacion;
  if (punto == null) {
    final direccion = (e.direccion ?? '').trim();
    if (direccion.isNotEmpty) {
      final resultados = await GeocodingService().searchPlaces(direccion);
      if (resultados.isNotEmpty) {
        final lugar = resultados.first.location;
        punto = GeoPoint(lugar.latitude, lugar.longitude);
      }
    }
  }

  if (punto == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No se pudo ubicar este estacionamiento en el mapa.'),
      ),
    );
    return;
  }

  final ubicacion = punto;
  await navigator.push(
    MaterialPageRoute(
      builder: (_) => MapaAutoScreen(
        ubicacionAuto: ubicacion,
        lugar: _lugarParaMapa(e),
      ),
    ),
  );
}

/// Detalle de un estacionamiento: todos los datos que se guardaron. Se abre al
/// tocar una tarjeta del historial, igual que el detalle de una carga de
/// combustible o de una mantención.
class DetalleEstacionamientoScreen extends StatefulWidget {
  final EstacionamientoModel estacionamiento;

  const DetalleEstacionamientoScreen({super.key, required this.estacionamiento});

  @override
  State<DetalleEstacionamientoScreen> createState() =>
      _DetalleEstacionamientoScreenState();
}

class _DetalleEstacionamientoScreenState
    extends State<DetalleEstacionamientoScreen> {
  Timer? _reloj;

  EstacionamientoModel get _e => widget.estacionamiento;

  @override
  void initState() {
    super.initState();
    // Si el cronómetro sigue corriendo, el tiempo se va actualizando.
    if (_e.estaActivo) {
      _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  String _dos(int n) => n.toString().padLeft(2, '0');

  String _fecha(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

  String _fechaHora(DateTime f) => '${_fecha(f)}  ${_dos(f.hour)}:${_dos(f.minute)}';

  String _duracion(Duration d) {
    final horas = d.inHours;
    final minutos = d.inMinutes.remainder(60);
    if (_e.estaActivo) {
      final segundos = d.inSeconds.remainder(60);
      return '${_dos(horas)}:${_dos(minutos)}:${_dos(segundos)}';
    }
    if (horas == 0) return '$minutos min';
    return minutos == 0 ? '$horas h' : '$horas h $minutos min';
  }

  String get _titulo {
    if (_e.lugar.trim().isNotEmpty) return _e.lugar.trim();
    final direccion = (_e.direccion ?? '').trim();
    return direccion.isNotEmpty ? direccion : 'Estacionamiento';
  }

  Color get _colorEstado => _e.estaActivo
      ? AppColors.exito
      : _e.pendienteDeComprobante
      ? AppColors.alerta
      : AppColors.primario;

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final filas = <(IconData, String, String)>[
      (Icons.event_outlined, 'Fecha', _fecha(e.fechaEntrada)),
      (Icons.login_outlined, 'Hora de entrada', _fechaHora(e.fechaEntrada)),
      if (e.fechaSalida != null)
        (Icons.logout_outlined, 'Hora de salida', _fechaHora(e.fechaSalida!)),
      (
        Icons.timer_outlined,
        e.estaActivo ? 'Tiempo transcurrido' : 'Duración',
        _duracion(e.duracion),
      ),
      if (e.costo != null)
        (Icons.payments_outlined, 'Total pagado', clp(e.costo!)),
    ];
    final ubicacion = <(IconData, String, String)>[
      if ((e.nivel ?? '').trim().isNotEmpty)
        (Icons.layers_outlined, 'Nivel o piso', e.nivel!.trim()),
      if ((e.sector ?? '').trim().isNotEmpty)
        (Icons.grid_view_outlined, 'Sector', e.sector!.trim()),
      if ((e.direccion ?? '').trim().isNotEmpty)
        (Icons.place_outlined, 'Dirección', e.direccion!.trim()),
    ];
    final observacion = (e.observaciones ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.texto),
        title: const Text(
          'Detalle del estacionamiento',
          style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _cabecera(),
                const SizedBox(height: 22),
                _tituloSeccion('Información general'),
                const SizedBox(height: 10),
                _tarjeta(_filas(filas)),
                if (ubicacion.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _tituloSeccion('Ubicación del auto'),
                  const SizedBox(height: 10),
                  _tarjeta(_filas(ubicacion)),
                ],
                if (observacion.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _tituloSeccion('Observaciones'),
                  const SizedBox(height: 10),
                  _tarjeta(
                    Text(
                      observacion,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                if (puedeVerUbicacion(e)) ...[
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => verUbicacionEnMapa(context, e),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text(
                        'Ver ubicación en el mapa',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primario,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadios.control),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filas(List<(IconData, String, String)> filas) {
    return Column(
      children: [
        for (var i = 0; i < filas.length; i++) ...[
          if (i > 0) const Divider(height: 18, color: AppColors.fondo),
          _fila(filas[i].$1, filas[i].$2, filas[i].$3),
        ],
      ],
    );
  }

  Widget _cabecera() {
    return _tarjeta(
      Row(
        children: [
          const SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              Icons.local_parking_outlined,
              color: AppColors.primario,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _etiqueta(_e.estado.etiqueta, _colorEstado),
                    if (_e.origenRegistro == 'ia')
                      _etiqueta('Registrado con IA', AppColors.textoSecundario),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadios.chip),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _tarjeta(Widget hijo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        boxShadow: AppSombras.tarjeta,
      ),
      child: hijo,
    );
  }

  Widget _fila(IconData icono, String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: AppColors.primario, size: 19),
        const SizedBox(width: 10),
        Text(
          etiqueta,
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
