import 'package:flutter/material.dart';
import '../../entorno.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/services/geocoding_service.dart';

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
  final TextEditingController _busquedaController = TextEditingController();

  LatLng? _ubicacionSeleccionada;
  String? _direccion;
  bool _cargando = false;
  List<PlaceSuggestion> _sugerencias = [];

  static const Color azul = Color(0xFF1E3A8A);

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

  Future<void> _usarMiUbicacion() async {
    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();

      if (!servicioActivo) {
        _mostrarMensaje('Activa la ubicación de tu dispositivo.');
        return;
      }

      var permiso = await Geolocator.checkPermission();

      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        _mostrarMensaje('No se concedió permiso de ubicación.');
        return;
      }

      setState(() => _cargando = true);

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final punto = LatLng(posicion.latitude, posicion.longitude);

      _mapController.move(punto, 17);
      await _seleccionarPunto(punto);
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
    _busquedaController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
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
                      borderRadius: BorderRadius.circular(14),
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
