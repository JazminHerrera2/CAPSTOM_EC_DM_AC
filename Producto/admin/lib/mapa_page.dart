import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart' show SelectorAcordeon;

const Color _tinta = Color(0xFF0F172A);
const Color _gris = Color(0xFF64748B);
const Color _borde = Color(0xFFE2E8F0);
const Color _azul = Color(0xFF1D4ED8);
const Color _ambar = Color(0xFFF59E0B);

/// Pórtico listo para dibujar en el mapa.
class PorticoMapa {
  const PorticoMapa({
    required this.id,
    required this.nombre,
    required this.autopista,
    required this.sentido,
    required this.tarifaBase,
    required this.posicion,
  });

  final String id;
  final String nombre;
  final String autopista;
  final String sentido;
  final double tarifaBase;
  final LatLng posicion;

  bool get tieneTarifa => tarifaBase > 0;
}

double? _aDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString().replaceAll(',', '.') ?? '');
}

/// Lee un documento de `porticos` tolerando los formatos que conviven en la
/// base: lat/lng sueltos, `location` {lat,lng}, `ubicacion` GeoPoint, y datos
/// anidados bajo `datos`. Devuelve null si el pórtico no tiene coordenadas.
PorticoMapa? porticoDesdeDoc(String id, Map<String, dynamic> raw) {
  final datos = raw['datos'];
  final d = datos is Map ? Map<String, dynamic>.from(datos) : raw;

  double? lat = _aDouble(d['lat'] ?? d['latitud']);
  double? lng = _aDouble(d['lng'] ?? d['longitud']);
  final loc = d['location'];
  if ((lat == null || lng == null) && loc is Map) {
    lat = _aDouble(loc['lat']);
    lng = _aDouble(loc['lng']);
  }
  final ubic = d['ubicacion'];
  if ((lat == null || lng == null) && ubic is GeoPoint) {
    lat = ubic.latitude;
    lng = ubic.longitude;
  }
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  if (lat == 0 && lng == 0) return null;

  return PorticoMapa(
    id: id,
    nombre: (d['nombre'] ?? d['autopista'] ?? 'Sin nombre').toString(),
    autopista: (d['autopista'] ?? '').toString().trim(),
    sentido: (d['sentido'] ?? '').toString(),
    tarifaBase:
        _aDouble(
          d['tarifa_base'] ?? d['costo'] ?? d['cost'] ?? d['Tarifa_Base'],
        ) ??
        0,
    posicion: LatLng(lat, lng),
  );
}

/// Mismo estilo de Mapbox que la app del conductor; si el admin no tiene el
/// token en su .env se usa OpenStreetMap para que el mapa igual se vea.
TileLayer capaBaseMapa() {
  final token =
      (dotenv.isInitialized ? dotenv.env['MAPBOX_ACCESS_TOKEN'] : null) ?? '';
  if (token.isNotEmpty) {
    return TileLayer(
      urlTemplate:
          'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=$token',
      tileSize: 512,
      zoomOffset: -1,
      userAgentPackageName: 'com.tagok.admin',
    );
  }
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.tagok.admin',
  );
}

class MapaPage extends StatefulWidget {
  const MapaPage({super.key, required this.service});

  final AdminFirestoreService service;

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final MapController _controller = MapController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      widget.service.streamPorticos();

  String _autopista = 'Todas';
  PorticoMapa? _seleccionado;

  static const LatLng _santiago = LatLng(-33.4489, -70.6693);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _encuadrar(List<PorticoMapa> lista) {
    if (lista.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(
      lista.map((p) => p.posicion).toList(),
    );
    _controller.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60), maxZoom: 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error al cargar los pórticos: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final todos = <PorticoMapa>[];
        int sinCoordenadas = 0;
        for (final doc in snap.data!.docs) {
          final p = porticoDesdeDoc(doc.id, doc.data());
          if (p == null) {
            sinCoordenadas++;
          } else {
            todos.add(p);
          }
        }
        final autopistas = {
          for (final p in todos)
            if (p.autopista.isNotEmpty) p.autopista,
        }.toList()
          ..sort();
        final visibles = _autopista == 'Todas'
            ? todos
            : todos.where((p) => p.autopista == _autopista).toList();

        return Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _santiago,
                initialZoom: 11,
                initialCameraFit: todos.isEmpty
                    ? null
                    : CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(
                          todos.map((p) => p.posicion).toList(),
                        ),
                        padding: const EdgeInsets.all(60),
                        maxZoom: 15,
                      ),
                minZoom: 4,
                maxZoom: 18,
                onTap: (_, _) => setState(() => _seleccionado = null),
              ),
              children: [
                capaBaseMapa(),
                MarkerLayer(
                  markers: [
                    for (final p in visibles)
                      Marker(
                        point: p.posicion,
                        width: 34,
                        height: 34,
                        child: GestureDetector(
                          onTap: () => setState(() => _seleccionado = p),
                          child: _MarcadorPortico(
                            p: p,
                            activo: _seleccionado?.id == p.id,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pastilla(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.toll_outlined, size: 18, color: _azul),
                        const SizedBox(width: 8),
                        Text(
                          '${visibles.length} pórticos',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _tinta,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SelectorAcordeon(
                    ancho: 230,
                    compacto: true,
                    valor: autopistas.contains(_autopista) ? _autopista : 'Todas',
                    opciones: ['Todas', ...autopistas],
                    etiquetas: const {'Todas': 'Todas las autopistas'},
                    onChanged: (v) {
                      setState(() {
                        _autopista = v;
                        _seleccionado = null;
                      });
                      _encuadrar(
                        v == 'Todas'
                            ? todos
                            : todos.where((p) => p.autopista == v).toList(),
                      );
                    },
                  ),
                  if (sinCoordenadas > 0)
                    _Pastilla(
                      child: Text(
                        '$sinCoordenadas sin coordenadas',
                        style: const TextStyle(color: _gris, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              bottom: _seleccionado == null ? 16 : 150,
              child: const _Pastilla(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Punto(color: _azul),
                    SizedBox(width: 6),
                    Text('Con tarifa', style: TextStyle(fontSize: 12.5)),
                    SizedBox(width: 14),
                    _Punto(color: _ambar),
                    SizedBox(width: 6),
                    Text('Sin tarifa', style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
            ),
            if (_seleccionado != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _FichaPortico(
                      p: _seleccionado!,
                      onCerrar: () => setState(() => _seleccionado = null),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MarcadorPortico extends StatelessWidget {
  const _MarcadorPortico({required this.p, required this.activo});

  final PorticoMapa p;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final color = p.tieneTarifa ? _azul : _ambar;
    return Container(
      decoration: BoxDecoration(
        color: activo ? color : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.toll,
        size: 18,
        color: activo ? Colors.white : color,
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _FichaPortico extends StatelessWidget {
  const _FichaPortico({required this.p, required this.onCerrar});

  final PorticoMapa p;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    String fila(String etiqueta, String valor) => valor.isEmpty ? '' : '$etiqueta: $valor';
    final lineas = [
      fila('Autopista', p.autopista),
      fila('Sentido', p.sentido),
      p.tieneTarifa ? 'Tarifa base: \$${p.tarifaBase.round()}' : 'Sin tarifa configurada',
      'Ubicación: ${p.posicion.latitude.toStringAsFixed(5)}, ${p.posicion.longitude.toStringAsFixed(5)}',
    ].where((l) => l.isNotEmpty);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _tinta,
                  ),
                ),
                const SizedBox(height: 6),
                for (final l in lineas)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l,
                      style: const TextStyle(color: _gris, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onCerrar,
            icon: const Icon(Icons.close, size: 20, color: _gris),
          ),
        ],
      ),
    );
  }
}
