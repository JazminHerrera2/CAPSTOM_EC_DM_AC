import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';
import 'concesionarios_page.dart' show armarConcesionarias;
import 'dashboard_page.dart'
    show GrillaTarjetas, TarjetaDato, formatoMiles, haceCuanto;
import 'file_downloader.dart';

typedef _Docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

const List<String> _periodos = [
  'Todo el período',
  'Últimos 30 días',
  'Últimos 90 días',
  'Este año',
];

const List<String> _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const Color _azulClaro = Color(0xFF7CA3FB);
const Color _azulMedio = Color(0xFF4A80F0);

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key, required this.service});

  final AdminFirestoreService service;

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final SuscripcionesMultiples _subs = SuscripcionesMultiples();
  _Docs? _usuarios;
  _Docs? _vehiculos;
  _Docs? _viajes;
  _Docs? _porticos;
  _Docs? _concesionarias;
  _Docs? _auditoria;
  Object? _error;
  String _periodo = _periodos.first;

  @override
  void initState() {
    super.initState();
    _suscribir();
  }

  @override
  void dispose() {
    _subs.cancelar();
    super.dispose();
  }

  void _suscribir() {
    void alError(Object e) {
      if (mounted) setState(() => _error = e);
    }

    void on<T>(Stream<T> s, void Function(T) f) => _subs.escuchar<T>(
      s,
      (d) {
        if (mounted) setState(() => f(d));
      },
      alError: alError,
    );
    on(widget.service.streamUsers(), (d) => _usuarios = d.docs);
    on(widget.service.streamVehicles(), (d) => _vehiculos = d.docs);
    on(widget.service.streamUserTrips(), (d) => _viajes = d);
    on(widget.service.streamPorticos(), (d) => _porticos = d.docs);
    on(widget.service.streamAuditLogs(), (d) => _auditoria = d.docs);
    _subs.escuchar(
      widget.service.streamConcesionarias(),
      (QuerySnapshot<Map<String, dynamic>> d) {
        if (mounted) setState(() => _concesionarias = d.docs);
      },
      alError: (_) {
        if (mounted) setState(() => _concesionarias = const []);
      },
    );
  }

  void _actualizar() {
    _subs.cancelar();
    setState(() {
      _usuarios = _vehiculos = _viajes = null;
      _porticos = _concesionarias = _auditoria = null;
      _error = null;
    });
    _suscribir();
  }

  DateTime? _desde(DateTime ahora) {
    switch (_periodo) {
      case 'Últimos 30 días':
        return ahora.subtract(const Duration(days: 30));
      case 'Últimos 90 días':
        return ahora.subtract(const Duration(days: 90));
      case 'Este año':
        return DateTime(ahora.year);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error al leer Firestore: $_error'));
    }
    if (_usuarios == null ||
        _vehiculos == null ||
        _viajes == null ||
        _porticos == null ||
        _concesionarias == null ||
        _auditoria == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final ahora = DateTime.now();
    final desde = _desde(ahora);
    final compact = MediaQuery.sizeOf(context).width < 820;

    // --- Usuarios, vehículos y actividad -----------------------------------
    final ultimaActividad = <String, DateTime>{};
    var gasto = 0.0;
    var cruces = 0;
    var viajesPeriodo = 0;
    var viajes30 = 0;
    final usuariosConCruces = <String>{};
    final meses = List.generate(6, (i) => DateTime(ahora.year, ahora.month - (5 - i)));
    final viajesMes = List<int>.filled(6, 0);
    final crucesMes = List<int>.filled(6, 0);

    for (final t in _viajes!) {
      final m = t.data();
      final f = fechaDe(m['date']);
      final uid = t.reference.parent.parent?.id;
      final tolls = m['tolls'] is List ? (m['tolls'] as List).length : 0;
      if (f != null && uid != null) {
        final previo = ultimaActividad[uid];
        if (previo == null || f.isAfter(previo)) ultimaActividad[uid] = f;
      }
      if (f != null) {
        if (f.isAfter(ahora.subtract(const Duration(days: 30)))) viajes30++;
        final i = meses.indexWhere((x) => x.year == f.year && x.month == f.month);
        if (i >= 0) {
          viajesMes[i]++;
          crucesMes[i] += tolls;
        }
      }
      if (desde != null && (f == null || f.isBefore(desde))) continue;
      viajesPeriodo++;
      cruces += tolls;
      gasto += double.tryParse(m['totalCost']?.toString() ?? '') ?? 0;
      if (uid != null && tolls > 0) usuariosConCruces.add(uid);
    }

    final idsConVehiculo = <String>{};
    final tipos = <String, int>{};
    for (final v in _vehiculos!) {
      final d = v.data();
      final ref = d['id_usuario'];
      final uid = ref is DocumentReference ? ref.id : ref?.toString().split('/').last;
      if (uid != null && uid.isNotEmpty) idsConVehiculo.add(uid);
      final tipo = (d['tipo'] ?? d['tipo_vehiculo'] ?? d['categoria'] ?? 'Automóvil')
          .toString()
          .trim();
      tipos[tipo.isEmpty ? 'Automóvil' : tipo] =
          (tipos[tipo.isEmpty ? 'Automóvil' : tipo] ?? 0) + 1;
    }

    var activos = 0;
    var conVehiculo = 0;
    final nuevosMes = List<int>.filled(6, 0);
    final actividad = [0, 0, 0, 0, 0]; // hoy, semana, mes, antiguo, nunca
    for (final u in _usuarios!) {
      final d = u.data();
      final act = ultimaActividad[u.id];
      final esActivo = d['activo'] is bool
          ? d['activo'] as bool
          : (act != null && ahora.difference(act) <= const Duration(days: 30));
      if (esActivo) activos++;
      if (idsConVehiculo.contains(u.id)) conVehiculo++;

      final reg = fechaDe(d['fecha_creacion']);
      if (reg != null) {
        final i = meses.indexWhere((x) => x.year == reg.year && x.month == reg.month);
        if (i >= 0) nuevosMes[i]++;
      }

      if (act == null) {
        actividad[4]++;
      } else {
        final dif = ahora.difference(act);
        if (dif.inHours < 24) {
          actividad[0]++;
        } else if (dif.inDays < 7) {
          actividad[1]++;
        } else if (dif.inDays < 30) {
          actividad[2]++;
        } else {
          actividad[3]++;
        }
      }
    }
    final totalUsuarios = _usuarios!.length;

    // --- Estado operativo ---------------------------------------------------
    final porticos = _porticos!.map(PorticoAdmin.new).toList();
    final porticosActivos = porticos.where((p) => p.activo).length;
    final conTarifa = porticos.where((p) => p.tieneTarifa).length;
    final concesionarias = armarConcesionarias(_concesionarias!, porticos).length;
    final fechasAuditoria = _auditoria!
        .map((d) => fechaDe(d.data()['fecha']))
        .whereType<DateTime>()
        .toList();
    final cambios7 = fechasAuditoria
        .where((f) => ahora.difference(f) <= const Duration(days: 7))
        .length;
    final cambios30 = fechasAuditoria
        .where((f) => ahora.difference(f) <= const Duration(days: 30))
        .length;
    final ultimoCambio = fechasAuditoria.isEmpty
        ? null
        : fechasAuditoria.reduce((a, b) => a.isAfter(b) ? a : b);

    final adopcion = totalUsuarios == 0 ? 0 : (conVehiculo * 100 / totalUsuarios).round();
    final promedio = viajesPeriodo == 0 ? 0.0 : gasto / viajesPeriodo;

    void exportar() {
      final b = StringBuffer()
        ..writeln('Reporte TAG OK - ${fechaIso(ahora)} - $_periodo')
        ..writeln()
        ..writeln('ADOPCION')
        ..writeln('Usuarios registrados,$totalUsuarios')
        ..writeln('Activos,$activos')
        ..writeln('Inactivos,${totalUsuarios - activos}')
        ..writeln('Con vehiculo,$conVehiculo')
        ..writeln()
        ..writeln('USO FUNCIONAL')
        ..writeln('Viajes registrados,$viajesPeriodo')
        ..writeln('Gasto promedio por viaje,${promedio.round()}')
        ..writeln('Cruces registrados,$cruces')
        ..writeln('Gasto en peajes,${gasto.round()}')
        ..writeln()
        ..writeln('ESTADO OPERATIVO')
        ..writeln('Porticos activos,$porticosActivos')
        ..writeln('Porticos inactivos,${porticos.length - porticosActivos}')
        ..writeln('Con tarifa configurada,$conTarifa')
        ..writeln('Concesionarias,$concesionarias')
        ..writeln('Cambios ultimos 7 dias,$cambios7')
        ..writeln('Cambios ultimos 30 dias,$cambios30')
        ..writeln()
        ..writeln('MES,NUEVOS USUARIOS,VIAJES,CRUCES');
      for (var i = 0; i < 6; i++) {
        b.writeln(
          '${_mesesCortos[meses[i].month - 1]} ${meses[i].year},${nuevosMes[i]},${viajesMes[i]},${crucesMes[i]}',
        );
      }
      saveFile(b.toString(), 'reporte_tagok_${fechaIso(ahora)}.csv');
      avisar(context, 'Reporte exportado.');
    }

    return SafeArea(
      child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
              titulo: 'Reportes y estadísticas',
              subtitulo:
                  'Adopción, uso funcional y estado operativo del sistema.',
              acciones: [
                BotonContorno(
                  texto: 'Actualizar',
                  icono: Icons.refresh,
                  onPressed: _actualizar,
                ),
                BotonPrimario(
                  texto: 'Exportar',
                  icono: Icons.download_outlined,
                  onPressed: exportar,
                ),
              ],
            ),
            children: [

            _Seccion(
              'ADOPCIÓN',
              derecha: DesplegableFiltro(
                valor: _periodo,
                opciones: _periodos,
                ancho: 180,
                onChanged: (v) => setState(() => _periodo = v),
              ),
            ),
            GrillaTarjetas(
              tarjetas: [
                TarjetaDato(
                  etiqueta: 'Usuarios registrados',
                  valor: '$totalUsuarios',
                  detalle: 'cuentas en la plataforma',
                  icono: Icons.people_outline,
                ),
                TarjetaDato(
                  etiqueta: 'Activos',
                  valor: '$activos',
                  detalle: 'con viajes en los últimos 30 días',
                  icono: Icons.how_to_reg_outlined,
                  valorColor: kVerde,
                ),
                TarjetaDato(
                  etiqueta: 'Inactivos',
                  valor: '${totalUsuarios - activos}',
                  detalle: 'sin viajes recientes',
                  icono: Icons.person_off_outlined,
                  valorColor: kRojo,
                ),
                TarjetaDato(
                  etiqueta: 'Con vehículo',
                  valor: '$conVehiculo',
                  detalle: '$adopcion% de adopción',
                  icono: Icons.directions_car_outlined,
                ),
              ],
            ),
            const SizedBox(height: 26),
            const _Seccion('USO FUNCIONAL (PRODUCTO)'),
            GrillaTarjetas(
              tarjetas: [
                TarjetaDato(
                  etiqueta: 'Viajes registrados',
                  valor: '$viajesPeriodo',
                  detalle: '$viajes30 en 30 días',
                  icono: Icons.route_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Gasto promedio por viaje',
                  valor: '\$${formatoMiles(promedio)}',
                  detalle: 'sobre $viajesPeriodo viajes',
                  icono: Icons.sell_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Cruces registrados',
                  valor: '$cruces',
                  detalle: '${usuariosConCruces.length} usuarios con cruces',
                  icono: Icons.monitor_heart_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Gasto en peajes',
                  valor: '\$${formatoMiles(gasto)}',
                  detalle: 'en $cruces cruces',
                  valorColor: kAzul,
                  icono: Icons.trending_up,
                ),
              ],
            ),
            const SizedBox(height: 26),
            _FilaGraficos(
              izquierda: _TarjetaGrafico(
                titulo: 'Registros por mes',
                subtitulo: 'Cuántos usuarios nuevos se registraron cada mes.',
                child: _GraficoArea(
                  etiquetas: [for (final m in meses) _mesesCortos[m.month - 1]],
                  nuevos: nuevosMes,
                ),
              ),
              derecha: _TarjetaGrafico(
                titulo: 'Uso de producto por mes',
                subtitulo: 'Viajes y cruces de pórtico registrados.',
                leyenda: const [('Viajes', kAzul), ('Cruces de pórtico', _azulClaro)],
                child: _GraficoBarras(
                  etiquetas: [for (final m in meses) _mesesCortos[m.month - 1]],
                  series: [viajesMes, crucesMes],
                  colores: const [kAzul, _azulClaro],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _FilaGraficos(
              izquierda: _TarjetaGrafico(
                titulo: 'Distribución por tipo de vehículo',
                subtitulo: '${_vehiculos!.length} vehículos registrados',
                child: _Dona(valores: tipos),
              ),
              derecha: _TarjetaGrafico(
                titulo: 'Actividad de usuarios',
                subtitulo: 'Usuarios agrupados por la fecha de su último viaje registrado.',
                child: _GraficoBarras(
                  etiquetas: const [
                    'Hoy',
                    'Esta semana',
                    'Este mes',
                    'Más antiguo',
                    'Sin viajes',
                  ],
                  series: [actividad],
                  colores: const [kAzul],
                ),
              ),
            ),
            const SizedBox(height: 26),
            const _Seccion('ESTADO OPERATIVO'),
            GrillaTarjetas(
              tarjetas: [
                TarjetaDato(
                  etiqueta: 'Pórticos activos',
                  valor: '$porticosActivos',
                  detalle: 'de ${porticos.length} totales',
                  valorColor: kVerde,
                  icono: Icons.location_on_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Pórticos inactivos',
                  valor: '${porticos.length - porticosActivos}',
                  detalle: 'de ${porticos.length} totales',
                  valorColor: kRojo,
                  icono: Icons.location_on_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Con tarifa configurada',
                  valor: '$conTarifa',
                  detalle: '${porticos.length - conTarifa} pendientes',
                  icono: Icons.sell_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Concesionarias',
                  valor: '$concesionarias',
                  detalle: 'autopistas registradas',
                  icono: Icons.route_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Cambios últimos 7 días',
                  valor: '$cambios7',
                  detalle: 'registrados en la auditoría',
                  icono: Icons.monitor_heart_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Cambios últimos 30 días',
                  valor: '$cambios30',
                  detalle: 'registrados en la auditoría',
                  icono: Icons.monitor_heart_outlined,
                ),
                TarjetaDato(
                  etiqueta: 'Última actualización',
                  valor: ultimoCambio == null ? '—' : haceCuanto(ultimoCambio, ahora),
                  detalle: 'último cambio en el panel',
                  icono: Icons.refresh,
                ),
              ],
            ),
          
            ],
          ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto, {this.derecha});

  final String texto;

  /// Control alineado a la derecha, en la misma fila del título.
  final Widget? derecha;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: kGris,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ?derecha,
      ],
    ),
  );
}

class _FilaGraficos extends StatelessWidget {
  const _FilaGraficos({required this.izquierda, required this.derecha});

  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 860) {
        return Column(children: [izquierda, const SizedBox(height: 16), derecha]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: izquierda),
          const SizedBox(width: 16),
          Expanded(child: derecha),
        ],
      );
    },
  );
}

class _TarjetaGrafico extends StatelessWidget {
  const _TarjetaGrafico({
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.leyenda = const [],
  });

  final String titulo;
  final String subtitulo;
  final Widget child;
  final List<(String, Color)> leyenda;

  @override
  Widget build(BuildContext context) => TarjetaBlanca(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kTinta,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitulo, style: const TextStyle(color: kGris, fontSize: 14)),
        const SizedBox(height: 16),
        SizedBox(height: 230, child: child),
        if (leyenda.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final l in leyenda) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: l.$2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(l.$1, style: const TextStyle(color: kGris, fontSize: 12.5)),
                const SizedBox(width: 18),
              ],
            ],
          ),
        ],
      ],
    ),
  );
}

/// Marcas del eje Y: tope redondeado a múltiplo de 3 para tener 4 divisiones.
List<int> _marcas(int maximo) {
  final tope = (((maximo < 1 ? 1 : maximo) + 2) ~/ 3) * 3;
  return [tope, tope * 2 ~/ 3, tope ~/ 3, 0];
}

class _GraficoBarras extends StatelessWidget {
  const _GraficoBarras({
    required this.etiquetas,
    required this.series,
    required this.colores,
  });

  final List<String> etiquetas;
  final List<List<int>> series;
  final List<Color> colores;

  @override
  Widget build(BuildContext context) {
    final maximo = series.expand((s) => s).fold<int>(1, math.max);
    final marcas = _marcas(maximo);
    final tope = marcas.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in marcas)
                Text('$m', style: const TextStyle(color: kGris, fontSize: 12)),
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
                          const Divider(height: 1, color: kBorde),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < etiquetas.length; i++)
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, c) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (int s = 0; s < series.length; s++) ...[
                                      if (s > 0) const SizedBox(width: 3),
                                      Expanded(
                                        child: Container(
                                          height: c.maxHeight * series[s][i] / tope,
                                          decoration: BoxDecoration(
                                            color: colores[s],
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(4),
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
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final e in etiquetas)
                    Expanded(
                      child: Center(
                        child: Text(
                          e,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kGris, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GraficoArea extends StatelessWidget {
  const _GraficoArea({required this.etiquetas, required this.nuevos});

  final List<String> etiquetas;
  final List<int> nuevos;

  @override
  Widget build(BuildContext context) {
    final marcas = _marcas(nuevos.fold<int>(1, math.max));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in marcas)
                Text('$m', style: const TextStyle(color: kGris, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _PintorArea(nuevos: nuevos, tope: marcas.first),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final e in etiquetas)
                    Expanded(
                      child: Center(
                        child: Text(
                          e,
                          style: const TextStyle(color: kGris, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PintorArea extends CustomPainter {
  _PintorArea({required this.nuevos, required this.tope});

  final List<int> nuevos;
  final int tope;

  @override
  void paint(Canvas canvas, Size size) {
    final rejilla = Paint()
      ..color = kBorde
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rejilla);
    }
    if (nuevos.isEmpty) return;
    final n = nuevos.length;
    Offset punto(int i, int v) => Offset(
      size.width * (i + 0.5) / n,
      size.height - size.height * v / tope,
    );

    final linea = Path();
    for (var i = 0; i < n; i++) {
      final o = punto(i, nuevos[i]);
      if (i == 0) {
        linea.moveTo(o.dx, o.dy);
      } else {
        final prev = punto(i - 1, nuevos[i - 1]);
        final cx = (prev.dx + o.dx) / 2;
        linea.cubicTo(cx, prev.dy, cx, o.dy, o.dx, o.dy);
      }
    }
    final area = Path.from(linea)
      ..lineTo(punto(n - 1, 0).dx, size.height)
      ..lineTo(punto(0, 0).dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kAzul.withValues(alpha: 0.28), kAzul.withValues(alpha: 0.02)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = kAzul
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(punto(i, nuevos[i]), 3.5, Paint()..color = kAzul);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorArea old) =>
      old.nuevos != nuevos || old.tope != tope;
}

class _Dona extends StatelessWidget {
  const _Dona({required this.valores});

  final Map<String, int> valores;

  static const List<Color> _colores = [
    kAzul,
    _azulMedio,
    _azulClaro,
    Color(0xFFB7CCFB),
    Color(0xFF93C5FD),
  ];

  @override
  Widget build(BuildContext context) {
    final total = valores.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Center(
        child: Text('Sin vehículos registrados.', style: TextStyle(color: kGris)),
      );
    }
    final entradas = valores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Row(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _PintorDona(
                  [for (final e in entradas) e.value.toDouble()],
                  _colores,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < entradas.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colores[i % _colores.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entradas[i].key} (${entradas[i].value})',
                      style: const TextStyle(color: kGris, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PintorDona extends CustomPainter {
  _PintorDona(this.valores, this.colores);

  final List<double> valores;
  final List<Color> colores;

  @override
  void paint(Canvas canvas, Size size) {
    final total = valores.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;
    final lado = math.min(size.width, size.height);
    final grosor = lado * 0.22;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: lado - grosor,
      height: lado - grosor,
    );
    var inicio = -math.pi / 2;
    for (var i = 0; i < valores.length; i++) {
      final barrido = 2 * math.pi * valores[i] / total;
      canvas.drawArc(
        rect,
        inicio,
        barrido,
        false,
        Paint()
          ..color = colores[i % colores.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor,
      );
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorDona old) =>
      old.valores != valores || old.colores != colores;
}
