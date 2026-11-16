import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';
import 'package:flutter/material.dart';
import '../../entorno.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/services/geocoding_service.dart';
import '../../data/services/ubicacion_service.dart';

class UbicacionEstacionamiento {
  final LatLng coordenadas;
  final String direccion;

  const UbicacionEstacionamiento({
    required this.coordenadas,
    required this.direccion,
  });
}

class SeleccionarUbicacionScreen extends StatefulWidget {
  const SeleccionarUbicacionScreen({super.key});

  @override
  State<SeleccionarUbicacionScreen> createState() =>
      _SeleccionarUbicacionScreenState();
}

class _SeleccionarUbicacionScreenState
    extends State<SeleccionarUbicacionScreen> {
  final MapController _mapController = MapController();
  final GeocodingService _geocodingService = GeocodingService();
  final UbicacionService _ubicacionService = UbicacionService();
  final TextEditingController _busquedaController = TextEditingController();

  LatLng? _ubicacionSeleccionada;

  /// Tu posición actual, que se actualiza en vivo (punto azul). Es distinta de
  /// [_ubicacionSeleccionada], que es el lugar donde dejaste el auto.
  LatLng? _miUbicacion;
  StreamSubscription<GeoPoint>? _seguimiento;

  /// Si el usuario ya movió el mapa con el dedo: desde ahí no se lo vuelve a
  /// centrar solo.
  bool _usuarioMovioMapa = false;

  /// Si el mapa ya se centró en el usuario (con la última ubicación conocida,
  /// la posición actual o el primer punto del seguimiento).
  bool _centradoInicial = false;
  String? _direccion;
  bool _cargando = false;
  List<PlaceSuggestion> _sugerencias = [];

  static const Color azul = AppColors.primario;

  String get _mapboxToken => Entorno.mapboxAccessToken;

  Future<void> _seleccionarPunto(LatLng punto) async {
    setState(() {
      _ubicacionSeleccionada = punto;
      _direccion = null;
      _sugerencias = [];
      _cargando = true;
    });

    final direccion = await _geocodingService.obtenerDireccion(
      latitud: punto.latitude,
      longitud: punto.longitude,
    );

    if (!mounted || _ubicacionSeleccionada != punto) return;

    setState(() {
      _direccion = direccion;
      _cargando = false;
    });
  }

  /// Igual que el mapa de rutas: apenas abre el mapa se centra en ti, primero
  /// con la última ubicación conocida (al instante) y luego con la posición
  /// real, y queda el punto azul en vivo. No pone el pin: eso lo decide el
  /// usuario tocando el mapa o con el botón de mi ubicación.
  Future<void> _iniciarUbicacion() async {
    final ultima = await _ubicacionService.ultimaUbicacionConocida();
    if (ultima != null && mounted) _mostrarMiPosicion(ultima);

    try {
      final posicion = await _ubicacionService.obtenerUbicacionActual();
      if (!mounted) return;
      _mostrarMiPosicion(posicion);
      _seguirEnVivo();
    } on ErrorUbicacion catch (e) {
      if (!mounted) return;
      // Igual que el mapa de rutas: si solo faltó señal a tiempo no se avisa,
      // se sigue con el seguimiento en vivo. Los demás casos sí se avisan.
      if (e.motivo == MotivoErrorUbicacion.sinSenal) {
        _seguirEnVivo();
      } else {
        _mostrarMensaje(e.mensaje);
      }
    } catch (_) {
      // Sin ubicación el mapa igual sirve: se elige tocando o buscando.
    }
  }

  void _mostrarMiPosicion(GeoPoint posicion) {
    final punto = LatLng(posicion.latitude, posicion.longitude);
    final centrar = !_usuarioMovioMapa && _ubicacionSeleccionada == null;
    setState(() => _miUbicacion = punto);
    if (centrar) {
      _mapController.move(punto, 17);
      _centradoInicial = true;
    }
  }

  void _seguirEnVivo() {
    _seguimiento?.cancel();
    _seguimiento = _ubicacionService.seguirUbicacion().listen(
      (posicion) {
        if (!mounted) return;
        // Si es el primer punto que llega, se centra el mapa ahí.
        if (!_centradoInicial) {
          _mostrarMiPosicion(posicion);
          return;
        }
        setState(
          () => _miUbicacion = LatLng(posicion.latitude, posicion.longitude),
        );
      },
      onError: (Object _) {},
    );
  }

  Future<void> _usarMiUbicacion() async {
    // Si ya se sabe dónde está el usuario, se usa de inmediato.
    final mia = _miUbicacion;
    if (mia != null) {
      _mapController.move(mia, 17);
      await _seleccionarPunto(mia);
      return;
    }
    setState(() => _cargando = true);
    try {
      // Primero se mueve el mapa a la última ubicación conocida (si hay), para
      // no mostrar el mapa vacío mientras llega la posición real.
      final ultima = await _ubicacionService.ultimaUbicacionConocida();
      if (ultima != null && mounted) {
        _mapController.move(LatLng(ultima.latitude, ultima.longitude), 17);
      }

      final posicion = await _ubicacionService.obtenerUbicacionActual();
      if (!mounted) return;

      final punto = LatLng(posicion.latitude, posicion.longitude);
      _mapController.move(punto, 17);
      await _seleccionarPunto(punto);
    } on ErrorUbicacion catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _mostrarMensaje(e.mensaje);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _mostrarMensaje('No fue posible obtener tu ubicación.');
    }
  }

  Future<void> _buscarLugar(String texto) async {
    if (texto.trim().length < 3) {
      setState(() => _sugerencias = []);
      return;
    }

    final consulta = texto.trim();
    final resultados = await _geocodingService.searchPlaces(consulta);

    if (!mounted || _busquedaController.text.trim() != consulta) {
      return;
    }

    setState(() => _sugerencias = resultados);
  }

  void _elegirSugerencia(PlaceSuggestion lugar) {
    _busquedaController.text = lugar.address;
    _mapController.move(lugar.location, 17);

    setState(() {
      _ubicacionSeleccionada = lugar.location;
      _direccion = lugar.address;
      _sugerencias = [];
      _cargando = false;
    });

    FocusScope.of(context).unfocus();
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _confirmarUbicacion() {
    final punto = _ubicacionSeleccionada;

    if (punto == null) {
      _mostrarMensaje('Selecciona un punto en el mapa.');
      return;
    }

    Navigator.pop(
      context,
      UbicacionEstacionamiento(coordenadas: punto, direccion: _direccion ?? ''),
    );
  }

  @override
  void dispose() {
    _seguimiento?.cancel();
    _busquedaController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.texto,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _busquedaController,
                  onChanged: _buscarLugar,
                  decoration: InputDecoration(
                    hintText: 'Buscar dirección o lugar',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadios.control),
                    ),
                  ),
                ),
                if (_sugerencias.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    color: Colors.white,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _sugerencias.length,
                      itemBuilder: (context, index) {
                        final lugar = _sugerencias[index];

                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            lugar.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _elegirSugerencia(lugar),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(-33.4489, -70.6693),
                    initialZoom: 12,
                    onMapReady: _iniciarUbicacion,
                    onPositionChanged: (camara, hayGesto) {
                      if (hayGesto) _usuarioMovioMapa = true;
                    },
                    onTap: (tapPosition, punto) {
                      _seleccionarPunto(punto);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
                      tileSize: 512,
                      zoomOffset: -1,
                      userAgentPackageName: 'com.tagok.app',
                    ),
                    if (_miUbicacion != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _miUbicacion!,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: azul,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: AppSombras.tarjeta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_ubicacionSeleccionada != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _ubicacionSeleccionada!,
                            width: 55,
                            height: 55,
                            child: const Icon(
                              Icons.location_on,
                              color: azul,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'ubicacion_estacionamiento',
                    backgroundColor: Colors.white,
                    foregroundColor: azul,
                    onPressed: _usarMiUbicacion,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubicación seleccionada',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_cargando)
                  const LinearProgressIndicator()
                else
                  Text(
                    _direccion ??
                        (_ubicacionSeleccionada == null
                            ? 'Toca el mapa o usa tu ubicación.'
                            : 'Dirección no encontrada. '
                                  'Podrás ingresarla manualmente.'),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _ubicacionSeleccionada == null || _cargando
                        ? null
                        : _confirmarUbicacion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azul,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(15),
                    ),
                    child: const Text('Confirmar ubicación'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
