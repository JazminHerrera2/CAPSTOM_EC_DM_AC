import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart' show BotonContorno, EncabezadoPagina, PaginaConEncabezado;

const Color _tinta = Color(0xFF0F172A);
const Color _gris = Color(0xFF64748B);
const Color _borde = Color(0xFFE2E8F0);
const Color _azul = Color(0xFF1D4ED8);
const Color _azulClaro = Color(0xFF7CA3FB);
const Color _iconoFondo = Color(0xFFF1F5F9);

/// Resumen numérico del sistema, calculado a partir de las colecciones de
/// Firestore. Es una función pura para poder probarla sin Firebase.
class ResumenDashboard {
  const ResumenDashboard({
    required this.concesionarias,
    required this.porticos,
    required this.porticosSinTarifa,
    required this.usuarios,
    required this.usuariosConViajes,
    required this.porcentajeConVehiculo,
    required this.gastoPeajes,
    required this.cruces,
    required this.viajes,
    required this.viajesUltimos30Dias,
    required this.promedioPorViaje,
    required this.usuariosConCruces,
    required this.vehiculos,
    required this.usuariosConVehiculo,
    required this.viajesPorMes,
    required this.crucesPorMes,
  });

  final int concesionarias;
  final int porticos;
  final int porticosSinTarifa;
  final int usuarios;
  final int usuariosConViajes;
  final int porcentajeConVehiculo;
  final double gastoPeajes;
  final int cruces;
  final int viajes;
  final int viajesUltimos30Dias;
  final double promedioPorViaje;
  final int usuariosConCruces;
  final int vehiculos;
  final int usuariosConVehiculo;

  /// Últimos 6 meses (el último es el mes de [ahora]).
  final List<int> viajesPorMes;
  final List<int> crucesPorMes;
}

DateTime? _fecha(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String? _idUsuarioDeVehiculo(Map<String, dynamic> data) {
  final v = data['id_usuario'];
  if (v is DocumentReference) return v.id;
  if (v == null) return null;
  final s = v.toString();
  return s.contains('/') ? s.split('/').last : s;
}

Map<String, dynamic> _datosPortico(Map<String, dynamic> raw) {
  final datos = raw['datos'];
  return datos is Map ? Map<String, dynamic>.from(datos) : raw;
}

double _numero(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

ResumenDashboard calcularResumen({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> viajes,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> usuarios,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> porticos,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> vehiculos,
  required DateTime ahora,
}) {
  // Concesionarias = autopistas distintas entre los pórticos.
  final autopistas = <String>{};
  int sinTarifa = 0;
  for (final doc in porticos) {
    final d = _datosPortico(doc.data());
    final autopista = (d['autopista'] ?? '').toString().trim();
    if (autopista.isNotEmpty) autopistas.add(autopista);
    final base = _numero(
      d['tarifa_base'] ?? d['costo'] ?? d['cost'] ?? d['Tarifa_Base'],
    );
    if (base <= 0) sinTarifa++;
  }

  final usuariosConVehiculo = <String>{};
  for (final doc in vehiculos) {
    final id = _idUsuarioDeVehiculo(doc.data());
    if (id != null) usuariosConVehiculo.add(id);
  }
  final idsUsuarios = usuarios.map((u) => u.id).toSet();
  final conVehiculo = usuariosConVehiculo.intersection(idsUsuarios).length;

  // Los últimos 6 meses, del más antiguo al actual.
  final meses = List.generate(
    6,
    (i) => DateTime(ahora.year, ahora.month - (5 - i)),
  );
  final viajesPorMes = List<int>.filled(6, 0);
  final crucesPorMes = List<int>.filled(6, 0);

  double gasto = 0;
  int cruces = 0;
  int ultimos30 = 0;
  final usuariosConViajes = <String>{};
  final usuariosConCruces = <String>{};
  final limite30 = ahora.subtract(const Duration(days: 30));

  for (final doc in viajes) {
    final d = doc.data();
    gasto += _numero(d['totalCost']);
    final tolls = d['tolls'] is List ? (d['tolls'] as List).length : 0;
    cruces += tolls;
    final uid = doc.reference.parent.parent?.id;
    if (uid != null) {
      usuariosConViajes.add(uid);
      if (tolls > 0) usuariosConCruces.add(uid);
    }
    final f = _fecha(d['date']);
    if (f != null) {
      if (f.isAfter(limite30)) ultimos30++;
      final idx = meses.indexWhere(
        (m) => m.year == f.year && m.month == f.month,
      );
      if (idx >= 0) {
        viajesPorMes[idx]++;
        crucesPorMes[idx] += tolls;
      }
    }
  }

  return ResumenDashboard(
    concesionarias: autopistas.length,
    porticos: porticos.length,
    porticosSinTarifa: sinTarifa,
    usuarios: usuarios.length,
    usuariosConViajes: usuariosConViajes.length,
    porcentajeConVehiculo: usuarios.isEmpty
        ? 0
        : (conVehiculo * 100 / usuarios.length).round(),
    gastoPeajes: gasto,
    cruces: cruces,
    viajes: viajes.length,
    viajesUltimos30Dias: ultimos30,
    promedioPorViaje: viajes.isEmpty ? 0 : gasto / viajes.length,
    usuariosConCruces: usuariosConCruces.length,
    vehiculos: vehiculos.length,
    usuariosConVehiculo: conVehiculo,
    viajesPorMes: viajesPorMes,
    crucesPorMes: crucesPorMes,
  );
}

/// "1234567" -> "1.234.567" (formato chileno).
String formatoMiles(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// "tag.ok.mvp@gmail.com" -> "Tag.Ok.Mvp".
String nombreDesdeCorreo(String? correo) {
  final local = (correo ?? '').split('@').first.trim();
  if (local.isEmpty) return 'Administrador';
  return local
      .split('.')
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join('.');
}

String saludoPorHora(DateTime ahora) {
  if (ahora.hour < 12) return 'Buenos días';
  if (ahora.hour < 20) return 'Buenas tardes';
  return 'Buenas noches';
}

String haceCuanto(DateTime? f, DateTime ahora) {
  if (f == null) return '';
  final d = ahora.difference(f);
  if (d.inMinutes < 1) return 'Ahora';
  if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'Hace ${d.inHours} h';
  if (d.inDays < 30) return 'Hace ${d.inDays} d';
  if (d.inDays < 365) {
    final m = d.inDays ~/ 30;
    return m == 1 ? 'Hace 1 mes' : 'Hace $m meses';
  }
  final a = d.inDays ~/ 365;
  return a == 1 ? 'Hace 1 año' : 'Hace $a años';
}

String verboDeAccion(String action) {
  switch (action) {
    case 'EDIT_USER':
      return 'editó usuario';
    case 'DELETE_USER':
      return 'eliminó usuario';
    case 'RESET_PASSWORD':
      return 'restableció contraseña';
    case 'REAJUSTE_MASIVO_IPC':
      return 'aplicó reajuste masivo';
    case 'EDIT_TARIFF':
      return 'configuró tarifa de pórtico';
    case 'DELETE_PORTICO':
      return 'eliminó pórtico';
    case 'CREATE_ADMIN':
      return 'creó administrador';
    case 'EDIT_ADMIN_ROLE':
      return 'cambió rol de administrador';
    case 'DELETE_ADMIN':
      return 'revocó acceso de administrador';
    case 'RESET_ADMIN_PASSWORD':
      return 'restableció contraseña de admin';
    default:
      return action.toLowerCase().replaceAll('_', ' ');
  }
}

typedef _Docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.service,
    this.onVerActividad,
  });

  final AdminFirestoreService service;

  /// Si viene, "Ver todo" lleva a la pantalla de auditoría.
  final VoidCallback? onVerActividad;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<StreamSubscription<dynamic>> _subs = [];
  _Docs? _viajes;
  _Docs? _usuarios;
  _Docs? _porticos;
  _Docs? _vehiculos;
  _Docs? _auditoria;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _suscribir();
  }

  @override
  void dispose() {
    _cancelar();
    super.dispose();
  }

  void _cancelar() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void _suscribir() {
    void alError(Object e) {
      if (mounted) setState(() => _error = e);
    }

    void escuchar<T>(Stream<T> stream, void Function(T) alDato) {
      _subs.add(
        stream.listen((dato) {
          if (!mounted) return;
          setState(() {
            _error = null;
            alDato(dato);
          });
        }, onError: alError),
      );
    }

    escuchar(widget.service.streamUserTrips(), (d) => _viajes = d);
    escuchar(widget.service.streamUsers(), (d) => _usuarios = d.docs);
    escuchar(widget.service.streamPorticos(), (d) => _porticos = d.docs);
    escuchar(widget.service.streamVehicles(), (d) => _vehiculos = d.docs);
    escuchar(widget.service.streamAuditLogs(), (d) => _auditoria = d.docs);
  }

  void _actualizar() {
    _cancelar();
    setState(() {
      _viajes = _usuarios = _porticos = _vehiculos = _auditoria = null;
      _error = null;
    });
    _suscribir();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error al cargar el dashboard: $_error'));
    }
    if (_viajes == null ||
        _usuarios == null ||
        _porticos == null ||
        _vehiculos == null ||
        _auditoria == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final ahora = DateTime.now();
    final r = calcularResumen(
      viajes: _viajes!,
      usuarios: _usuarios!,
      porticos: _porticos!,
      vehiculos: _vehiculos!,
      ahora: ahora,
    );
    final compact = MediaQuery.sizeOf(context).width < 820;
    final correo = FirebaseAuth.instance.currentUser?.email;

    return SafeArea(
      child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
              titulo: '${saludoPorHora(ahora)}, ${nombreDesdeCorreo(correo)}',
              subtitulo: 'Resumen general del sistema de peajes TAG.',
              icono: Icons.wb_twilight,
              colorIcono: const Color(0xFFF59E0B),
              acciones: [
                BotonContorno(
                  texto: 'Actualizar',
                  icono: Icons.refresh,
                  onPressed: _actualizar,
                ),
              ],
            ),
            children: [

            GrillaTarjetas(
              tarjetas: [
                TarjetaDato(
                  etiqueta: 'Concesionarias',
                  valor: '${r.concesionarias}',
                  detalle: 'autopistas registradas',
                  icono: Icons.apartment_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Pórticos',
                  valor: '${r.porticos}',
                  detalle:
                      '${r.porticos - r.porticosSinTarifa} con tarifa · ${r.porticosSinTarifa} sin tarifa',
                  icono: Icons.location_on_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Usuarios',
                  valor: '${r.usuarios}',
                  detalle:
                      '${r.usuariosConViajes} con viajes · ${r.porcentajeConVehiculo}% con vehículo',
                  icono: Icons.people_outline,
                ),
                TarjetaDato(
                  etiqueta: 'Gasto en peajes',
                  valor: '\$${formatoMiles(r.gastoPeajes)}',
                  detalle: '${r.cruces} cruces registrados',
                  icono: Icons.trending_up,
                  valorAzul: true,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'USO DEL PRODUCTO',
              style: TextStyle(
                color: _gris,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            GrillaTarjetas(
              tarjetas: [
                TarjetaDato(
                  etiqueta: 'Viajes registrados',
                  valor: '${r.viajes}',
                  detalle: '${r.viajesUltimos30Dias} en 30 días',
                  icono: Icons.route_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Gasto promedio por viaje',
                  valor: '\$${formatoMiles(r.promedioPorViaje)}',
                  detalle: 'sobre ${r.viajes} viajes',
                  icono: Icons.sell_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Cruces registrados',
                  valor: '${r.cruces}',
                  detalle: '${r.usuariosConCruces} usuarios con cruces',
                  icono: Icons.monitor_heart_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Vehículos registrados',
                  valor: '${r.vehiculos}',
                  detalle: '${r.usuariosConVehiculo} usuarios con vehículo',
                  icono: Icons.directions_car_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, c) {
                final grafico = _TarjetaGrafico(resumen: r, ahora: ahora);
                final actividad = _TarjetaActividad(
                  docs: _auditoria!,
                  ahora: ahora,
                  onVerTodo: widget.onVerActividad,
                );
                if (c.maxWidth < 900) {
                  return Column(
                    children: [grafico, const SizedBox(height: 16), actividad],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: grafico),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: actividad),
                  ],
                );
              },
            ),
          
            ],
          ),
    );
  }
}

class GrillaTarjetas extends StatelessWidget {
  const GrillaTarjetas({super.key, required this.tarjetas});

  final List<Widget> tarjetas;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        final columnas = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 420 ? 2 : 1);
        final ancho = (c.maxWidth - gap * (columnas - 1)) / columnas;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tarjetas) SizedBox(width: ancho, child: t),
          ],
        );
      },
    );
  }
}

class TarjetaDato extends StatelessWidget {
  const TarjetaDato({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.detalle,
    this.icono,
    this.valorColor,
    this.valorAzul = false,
  });

  final String etiqueta;
  final String valor;
  final String? detalle;
  final IconData? icono;
  final Color? valorColor;
  final bool valorAzul;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Alto fijo para que todas las tarjetas de una grilla midan lo mismo.
      height: detalle != null ? 132 : null,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _gris,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valorColor ?? (valorAzul ? _azul : _tinta),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detalle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detalle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _gris, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (icono != null)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _iconoFondo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: _gris, size: 20),
            ),
        ],
      ),
    );
  }
}

const List<String> _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

class _TarjetaGrafico extends StatelessWidget {
  const _TarjetaGrafico({required this.resumen, required this.ahora});

  final ResumenDashboard resumen;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final meses = List.generate(
      6,
      (i) => DateTime(ahora.year, ahora.month - (5 - i)),
    );
    final maximo = [
      ...resumen.viajesPorMes,
      ...resumen.crucesPorMes,
      1,
    ].reduce((a, b) => a > b ? a : b);
    // Eje con 4 marcas: 0, 1/3, 2/3 y el tope (entero hacia arriba).
    final tope = ((maximo + 2) ~/ 3) * 3;
    final marcas = [tope, tope * 2 ~/ 3, tope ~/ 3, 0];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uso del producto por mes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _tinta,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Viajes y cruces de pórtico registrados.',
            style: TextStyle(color: _gris, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final m in marcas)
                        Text(
                          '$m',
                          style: const TextStyle(color: _gris, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (int i = 0; i < 4; i++)
                                  const Divider(height: 1, color: _borde),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (int i = 0; i < 6; i++)
                                  Expanded(
                                    child: _ParBarras(
                                      viajes: resumen.viajesPorMes[i],
                                      cruces: resumen.crucesPorMes[i],
                                      tope: tope,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final m in meses)
                            Expanded(
                              child: Center(
                                child: Text(
                                  _mesesCortos[m.month - 1],
                                  style: const TextStyle(
                                    color: _gris,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Leyenda(color: _azul, texto: 'Viajes'),
              SizedBox(width: 20),
              _Leyenda(color: _azulClaro, texto: 'Cruces de pórtico'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParBarras extends StatelessWidget {
  const _ParBarras({
    required this.viajes,
    required this.cruces,
    required this.tope,
  });

  final int viajes;
  final int cruces;
  final int tope;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        double alto(int v) => tope == 0 ? 0 : c.maxHeight * v / tope;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  height: alto(viajes),
                  decoration: const BoxDecoration(
                    color: _azul,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: alto(cruces),
                  decoration: const BoxDecoration(
                    color: _azulClaro,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(color: _gris, fontSize: 12.5)),
      ],
    );
  }
}

class _TarjetaActividad extends StatelessWidget {
  const _TarjetaActividad({
    required this.docs,
    required this.ahora,
    this.onVerTodo,
  });

  final _Docs docs;
  final DateTime ahora;
  final VoidCallback? onVerTodo;

  @override
  Widget build(BuildContext context) {
    final recientes = docs.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actividad reciente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _tinta,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Últimos cambios administrativos.',
                      style: TextStyle(color: _gris, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (onVerTodo != null)
                TextButton.icon(
                  onPressed: onVerTodo,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Ver todo'),
                  style: TextButton.styleFrom(
                    foregroundColor: _tinta,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recientes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aún no hay actividad registrada.',
                  style: TextStyle(color: _gris),
                ),
              ),
            )
          else
            for (final doc in recientes)
              _FilaActividad(data: doc.data(), ahora: ahora),
        ],
      ),
    );
  }
}

class _FilaActividad extends StatelessWidget {
  const _FilaActividad({required this.data, required this.ahora});

  final Map<String, dynamic> data;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final correo = (data['adminEmail'] ?? '').toString();
    final nombre = nombreDesdeCorreo(correo);
    final iniciales = nombre.replaceAll('.', ' ').trim().split(' ');
    final sigla = iniciales.length >= 2
        ? '${iniciales.first[0]}${iniciales[1][0]}'.toUpperCase()
        : nombre.substring(0, nombre.length >= 2 ? 2 : 1).toUpperCase();
    final detalle = (data['details'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE0ECFF),
            child: Text(
              sigla,
              style: const TextStyle(
                color: _azul,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            ' ${verboDeAccion((data['action'] ?? '').toString())}',
                      ),
                    ],
                  ),
                  style: const TextStyle(color: _tinta, fontSize: 14),
                ),
                if (detalle.isNotEmpty)
                  Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _gris, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            haceCuanto(_fecha(data['fecha']), ahora),
            style: const TextStyle(color: _gris, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
