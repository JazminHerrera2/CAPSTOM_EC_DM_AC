import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/services/ubicacion_service.dart';
import '../../entorno.dart';

/// "¿Dónde está mi auto?" (HU-18, RF-019): muestra dentro de TAG OK el punto
/// donde quedó estacionado el vehículo, la posición actual del usuario y la
/// distancia en línea recta entre ambos.
///
/// Usa el mismo mapa que la pantalla de TAG (flutter_map con mapas de Mapbox y
/// el token `MAPBOX_ACCESS_TOKEN` del .env), así que no agrega dependencias.
///
/// Se abre desde el módulo Estacionamientos con la ubicación guardada:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => MapaAutoScreen(ubicacionAuto: e.ubicacion!, lugar: e.lugar),
/// ));
/// ```
class MapaAutoScreen extends StatefulWidget {
  const MapaAutoScreen({
    super.key,
    required this.ubicacionAuto,
    this.lugar,
    this.ubicacionService,
  });

  /// Dónde quedó el vehículo (campo `ubicacion` del estacionamiento).
  final GeoPoint ubicacionAuto;

  /// Lugar escrito por el usuario, si lo hay (por ejemplo "Mall Plaza, -2").
  final String? lugar;

  /// Para pruebas; por defecto usa el GPS real.
  final UbicacionService? ubicacionService;

  @override
  State<MapaAutoScreen> createState() => _MapaAutoScreenState();
}

class _MapaAutoScreenState extends State<MapaAutoScreen> {
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const double _zoomCercano = 17;

  final MapController _mapController = MapController();
  GeoPoint? _miUbicacion;
  String? _avisoUbicacion;
  bool _buscandoMiUbicacion = false;

  LatLng get _puntoAuto =>
      LatLng(widget.ubicacionAuto.latitude, widget.ubicacionAuto.longitude);

  @override
  void initState() {
    super.initState();
    _buscarMiUbicacion();
  }

  /// La posición del usuario es opcional: si no hay permiso o señal, el mapa
  /// igual muestra el auto y se avisa el motivo.
  Future<void> _buscarMiUbicacion() async {
    setState(() {
      _buscandoMiUbicacion = true;
      _avisoUbicacion = null;
    });
    try {
      final posicion = await (widget.ubicacionService ?? UbicacionService())
          .obtenerUbicacionActual();
      if (!mounted) return;
      setState(() => _miUbicacion = posicion);
    } on ErrorUbicacion catch (e) {
      if (!mounted) return;
      setState(() => _avisoUbicacion = e.mensaje);
    } catch (_) {
      if (!mounted) return;
      setState(() => _avisoUbicacion =
          mensajeErrorUbicacion(MotivoErrorUbicacion.sinSenal));
    } finally {
      if (mounted) setState(() => _buscandoMiUbicacion = false);
    }
  }

  void _centrarEnAuto() => _mapController.move(_puntoAuto, _zoomCercano);

  void _centrarEnMi() {
    final mia = _miUbicacion;
    if (mia == null) {
      _buscarMiUbicacion();
      return;
    }
    _mapController.move(LatLng(mia.latitude, mia.longitude), _zoomCercano);
  }

  @override
  Widget build(BuildContext context) {
    final mia = _miUbicacion;
    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Dónde está mi auto?'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _puntoAuto,
              initialZoom: _zoomCercano,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=${Entorno.mapboxAccessToken}',
                tileSize: 512,
                zoomOffset: -1,
                userAgentPackageName: 'com.tagok.app',
              ),
              MarkerLayer(
                markers: [
                  if (mia != null)
                    Marker(
                      point: LatLng(mia.latitude, mia.longitude),
                      width: 40,
                      height: 40,
                      child: const _PuntoUsuario(color: primaryColor),
                    ),
                  Marker(
                    point: _puntoAuto,
                    width: 52,
                    height: 52,
                    alignment: Alignment.topCenter,
                    child: const _PinAuto(color: primaryColor),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 170,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'centrar_auto',
                  tooltip: 'Centrar en mi auto',
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  onPressed: _centrarEnAuto,
                  child: const Icon(Icons.directions_car),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'centrar_yo',
                  tooltip: 'Centrar en mi ubicación',
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                  onPressed: _centrarEnMi,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _TarjetaResumen(
              lugar: widget.lugar,
              distancia: mia == null
                  ? null
                  : textoDistancia(distanciaEnMetros(mia, widget.ubicacionAuto)),
              buscando: _buscandoMiUbicacion,
              aviso: _avisoUbicacion,
              onReintentar: _buscarMiUbicacion,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pin del vehículo: un auto dentro de un círculo con una punta hacia el
/// punto exacto.
class _PinAuto extends StatelessWidget {
  const _PinAuto({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.directions_car, color: Colors.white, size: 22),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 12),
      ],
    );
  }
}

/// Posición del usuario: el mismo punto azul del mapa de TAG.
class _PuntoUsuario extends StatelessWidget {
  const _PuntoUsuario({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.25),
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.lightBlueAccent.shade700,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({
    required this.lugar,
    required this.distancia,
    required this.buscando,
    required this.aviso,
    required this.onReintentar,
  });

  final String? lugar;
  final String? distancia;
  final bool buscando;
  final String? aviso;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final titulo = (lugar ?? '').trim().isNotEmpty ? lugar!.trim() : 'Tu auto';
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_parking, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (buscando)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Buscando tu ubicación…'),
                ],
              )
            else if (distancia != null)
              Text('Tu auto está $distancia en línea recta.')
            else if (aviso != null) ...[
              Text(aviso!, style: TextStyle(color: Colors.orange.shade800)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onReintentar,
                  child: const Text('Reintentar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
