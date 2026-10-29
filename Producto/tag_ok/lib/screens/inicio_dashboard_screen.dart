import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/models/beneficio_model.dart';
import '../data/models/documento_vehicular_model.dart';
import '../data/models/mantencion_model.dart';
import '../data/models/vehiculo_model.dart';
import '../data/services/beneficio_service.dart';
import '../data/services/vehiculo_service.dart';
import 'beneficios/beneficios_screen.dart';
import 'beneficios/detalle_beneficio_screen.dart';
import 'beneficios/imagen_beneficio.dart';
import 'dashboard/dashboard_logica.dart';
import 'dashboard/estado_vehiculo_chip.dart';
import 'dashboard/logo_tag_ok.dart';
import 'herramientas/placeholder_modulo_screen.dart';
import 'mi_vehiculo/documentos_vehiculo_screen.dart';
import 'mi_vehiculo/foto_vehiculo.dart';
import 'notificaciones/notificaciones_screen.dart';
import 'profile_screen.dart';

/// "Inicio" — dashboard "Mi Auto" (Sprint 5, RF-044 a RF-049).
///
/// Datos reales del vehículo seleccionado en el carrusel. Cada fuente se lee
/// por separado y, si no existe, está vacía o no se puede leer (p. ej. las
/// colecciones de Combustible y Estacionamientos del Sprint 4, que aún no
/// existen), cuenta como $0 / "Sin registros" en vez de romper la pantalla.
///
/// Decisiones de alcance: el TAG (viajes) no guarda `vehiculo_id`, así que su
/// gasto se suma solo al vehículo principal (deuda técnica: agregar
/// `vehiculo_id` a los viajes requiere tocar Fase 1). En pantallas anchas el
/// contenido queda en una columna centrada de [_anchoMaximo].
class InicioDashboardScreen extends StatefulWidget {
  /// "Ver todos" de acciones rápidas: abre el hub Herramientas.
  final VoidCallback? onIrAHerramientas;

  /// Acceso rápido a Mantenciones.
  final VoidCallback? onAbrirMantenciones;

  /// Cuando no hay vehículos: lleva a la pestaña de vehículos.
  final VoidCallback? onIrAVehiculos;

  const InicioDashboardScreen({
    super.key,
    this.onIrAHerramientas,
    this.onAbrirMantenciones,
    this.onIrAVehiculos,
  });

  @override
  State<InicioDashboardScreen> createState() => _InicioDashboardScreenState();
}

class _InicioDashboardScreenState extends State<InicioDashboardScreen> {
  static const double _anchoMaximo = 480;

  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final PageController _paginas = PageController(viewportFraction: 0.92);
  final List<StreamSubscription<dynamic>> _subs = [];

  List<VehiculoModel> _vehiculos = const [];
  String _nombre = '';
  String _principal = '';
  List<DocumentoVehicularModel> _documentos = const [];
  List<MantencionModel> _mantenciones = const [];
  List<GastoRegistro> _viajesTag = const [];
  List<GastoRegistro> _combustible = const [];
  List<GastoRegistro> _estacionamientos = const [];
  List<BeneficioModel> _beneficios = const [];
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;

    _escuchar(VehiculoService().streamVehiculosUsuario(uid), (v) => _vehiculos = v);
    _escuchar(db.collection('usuarios').doc(uid).snapshots(), (doc) {
      final data = doc.data();
      _nombre = (data?['nombre_mostrar'] ?? '').toString().trim();
      _principal = (data?['vehiculo_principal_id'] ?? '').toString();
    });
    _escuchar(
      db.collection('documentos_vehiculares').where('uid', isEqualTo: uid).snapshots(),
      (s) => _documentos = [
        for (final d in s.docs) DocumentoVehicularModel.fromJson(d.data(), d.id),
      ],
    );
    _escuchar(
      db.collection('mantenciones').where('uid', isEqualTo: uid).snapshots(),
      (s) => _mantenciones = [
        for (final d in s.docs) MantencionModel.fromJson(d.data(), d.id),
      ],
    );
    _escuchar(
      db.collection('usuarios').doc(uid).collection('trips').snapshots(),
      (s) => _viajesTag = _gastosDeViajes(s.docs),
    );
    _escuchar(_gastosDeColeccion(db, 'abastecimientos', 'total', uid),
        (g) => _combustible = g);
    _escuchar(_gastosDeColeccion(db, 'estacionamientos', 'costo', uid),
        (g) => _estacionamientos = g);
    // Catálogo global: el mismo para todos los vehículos. Solo activos y
    // vigentes, con los destacados primero.
    _escuchar(BeneficioService().streamCatalogo(), (lista) => _beneficios = lista);
  }

  /// Si la fuente falla (no existe, sin permisos), queda el valor inicial
  /// vacío y la pantalla sigue funcionando.
  void _escuchar<T>(Stream<T> stream, void Function(T) alDato) {
    _subs.add(stream.listen(
      (dato) {
        if (mounted) setState(() => alDato(dato));
      },
      onError: (Object e) => debugPrint('Dashboard: fuente no disponible: $e'),
    ));
  }

  static List<GastoRegistro> _gastosDeViajes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lista = <GastoRegistro>[];
    for (final d in docs) {
      try {
        final data = d.data();
        final fecha = DateTime.parse(data['date'] as String);
        final monto = (data['totalCost'] as num).round();
        lista.add((vehiculoId: null, fecha: fecha, monto: monto));
      } catch (_) {
        // Viaje con datos incompletos: no suma.
      }
    }
    return lista;
  }

  static Stream<List<GastoRegistro>> _gastosDeColeccion(
    FirebaseFirestore db,
    String coleccion,
    String campoMonto,
    String uid,
  ) {
    return db
        .collection(coleccion)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final lista = <GastoRegistro>[];
      for (final d in s.docs) {
        final data = d.data();
        final fecha = data['fecha'];
        final monto = data[campoMonto];
        if (fecha is Timestamp && monto is num) {
          lista.add((
            vehiculoId: data['vehiculo_id'] as String?,
            fecha: fecha.toDate(),
            monto: monto.round(),
          ));
        }
      }
      return lista;
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _paginas.dispose();
    super.dispose();
  }

  // --- Derivados ---------------------------------------------------------

  /// Principal primero; luego por antigüedad de registro y patente.
  List<VehiculoModel> get _ordenados {
    final lista = [..._vehiculos];
    lista.sort((a, b) {
      final pa = a.patente == _principal;
      final pb = b.patente == _principal;
      if (pa != pb) return pa ? -1 : 1;
      final ra = a.fechaRegistro;
      final rb = b.fechaRegistro;
      if (ra != rb) {
        if (ra == null) return -1;
        if (rb == null) return 1;
        final c = ra.compareTo(rb);
        if (c != 0) return c;
      }
      return a.patente.compareTo(b.patente);
    });
    return lista;
  }

  VehiculoModel? get _seleccionado {
    final lista = _ordenados;
    if (lista.isEmpty) return null;
    return lista[_indice.clamp(0, lista.length - 1)];
  }

  List<DocumentoVehicularModel> _documentosDe(VehiculoModel v) =>
      _documentos.where((d) => d.vehiculoId == v.id).toList();

  String _estadoDe(VehiculoModel v) => VehiculoModel.calcularEstadoGeneral(
        _documentosDe(v).map((d) => d.fechaVencimiento).toList(),
      );

  ResumenGastos _resumenGastos(VehiculoModel? v) {
    if (v == null) return calcularResumenGastos(const {});
    bool esDe(GastoRegistro g) => g.vehiculoId == v.id;
    return calcularResumenGastos({
      CategoriaGasto.tag: v.patente == _principal ? _viajesTag : const [],
      CategoriaGasto.combustible: _combustible.where(esDe),
      CategoriaGasto.estacionamientos: _estacionamientos.where(esDe),
      CategoriaGasto.mantenciones: gastosDeMantenciones(
        _mantenciones.where((m) => m.vehiculoId == v.id),
      ),
    });
  }

  String _imagenPorDefecto(VehiculoModel v) {
    final tipo = (v.tipoVehiculo ?? '').toUpperCase().trim();
    if (tipo == 'MOTO') return 'assets/imagenes/vehiculos/moto.png';
    if (tipo == 'CAMIONETA' || tipo == 'CAMION' || tipo == 'CAMIÓN') {
      return 'assets/imagenes/vehiculos/camion.png';
    }
    return 'assets/imagenes/vehiculos/auto.png';
  }

  // --- Navegación --------------------------------------------------------

  void _abrirPlaceholder(String titulo, IconData icono, String sprint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceholderModuloScreen(
          titulo: titulo,
          icono: icono,
          sprintEstimado: sprint,
        ),
      ),
    );
  }

  void _abrirDocumentos(VehiculoModel? v) {
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registra un vehículo para ver sus documentos.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentosVehiculoScreen(
          vehiculoId: v.id,
          patenteVehiculo: v.patente,
        ),
      ),
    );
  }

  void _verBeneficios() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BeneficiosScreen()),
      );

  void _abrirBeneficio(BeneficioModel b) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalleBeneficioScreen(beneficio: b)),
      );

  // --- Construcción ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final seleccionado = _seleccionado;
    final estadoGlobal = peorEstado(_vehiculos.map(_estadoDe));
    final primerNombre = _nombre.isEmpty ? 'Conductor' : _nombre.split(' ').first;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoMaximo),
            child: ListView(
              // El botón del mapa sobresale de la barra inferior: margen extra.
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                _header(),
                const SizedBox(height: 20),
                Text(
                  '¡Hola, $primerNombre!',
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtituloGlobal(estadoGlobal, hayVehiculos: _vehiculos.isNotEmpty),
                  style: const TextStyle(color: _textMuted, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _carrusel(),
                const SizedBox(height: 16),
                _resumenes(seleccionado),
                const SizedBox(height: 22),
                _accionesRapidas(seleccionado),
                const SizedBox(height: 22),
                _gastos(seleccionado),
                const SizedBox(height: 16),
                _proximaMantencion(seleccionado),
                const SizedBox(height: 12),
                _tarjetaBeneficios(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const LogoTagOk(),
        const Spacer(),
        const CampanaNotificaciones(),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: _surfaceColor,
            child: Icon(Icons.person, color: _textMuted),
          ),
        ),
      ],
    );
  }

  Widget _tarjeta({required Widget child, EdgeInsets? padding, VoidCallback? onTap}) {
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: child,
        ),
      ),
    );
  }

  // --- Carrusel de vehículos --------------------------------------------

  Widget _carrusel() {
    final lista = _ordenados;
    if (lista.isEmpty) {
      return _tarjeta(
        onTap: widget.onIrAVehiculos,
        child: const Row(
          children: [
            Icon(Icons.directions_car_outlined, color: _primaryColor, size: 40),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Aún no tienes vehículos. Toca para registrar el primero.',
                style: TextStyle(color: _textMain, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final varios = lista.length > 1;
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _paginas,
                itemCount: lista.length,
                onPageChanged: (i) => setState(() => _indice = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _tarjetaVehiculo(lista[i]),
                ),
              ),
              if (varios && _indice > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _flecha(Icons.chevron_left, () => _irA(_indice - 1)),
                ),
              if (varios && _indice < lista.length - 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: _flecha(Icons.chevron_right, () => _irA(_indice + 1)),
                ),
            ],
          ),
        ),
        if (varios) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < lista.length; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _indice ? _primaryColor : Colors.white24,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _irA(int i) => _paginas.animateToPage(
        i,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );

  Widget _flecha(IconData icono, VoidCallback onTap) {
    return Material(
      color: _bgColor.withValues(alpha: 0.85),
      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icono, color: _textMain, size: 22),
        ),
      ),
    );
  }

  Widget _tarjetaVehiculo(VehiculoModel v) {
    final alias = (v.alias ?? '').trim();
    final marcaModelo = [v.marca, v.modelo]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' ');
    final titulo = alias.isNotEmpty
        ? alias
        : (marcaModelo.isNotEmpty ? marcaModelo : 'Mi vehículo');
    final detalle = [v.patente, if (v.anio != null) '${v.anio}'].join(' · ');

    return _tarjeta(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 12),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 100,
            child: FotoVehiculo(
              fotoPath: v.fotoPath,
              assetPredeterminado: _imagenPorDefecto(v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textMuted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: EstadoVehiculoChip(estado: _estadoDe(v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Resúmenes: próximo vencimiento y días ----------------------------

  Widget _resumenes(VehiculoModel? v) {
    final proximo = v == null
        ? null
        : calcularProximoVencimiento(_documentosDe(v));
    final fecha = proximo?.documento.fechaVencimiento;

    final String valorDias;
    final String unidad;
    if (proximo == null) {
      valorDias = '--';
      unidad = 'Sin registros';
    } else if (proximo.dias < 0) {
      valorDias = 'Vencido';
      unidad = 'Próximo vencimiento';
    } else {
      valorDias = '${proximo.dias}';
      unidad = proximo.dias == 1 ? 'día · Próximo vencimiento' : 'días · Próximo vencimiento';
    }

    return Row(
      children: [
        Expanded(
          child: _tarjeta(
            onTap: () => _abrirDocumentos(v),
            child: Row(
              children: [
                _iconoCuadrado(Icons.calendar_month_outlined, const Color(0xFFF97316)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proximo?.documento.tipoDocumento.etiqueta ?? 'Sin documentos',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fecha == null ? 'Sin registros' : 'Vence ${formatearFecha(fecha)}',
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _textMuted, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _tarjeta(
            onTap: () => _abrirDocumentos(v),
            child: Row(
              children: [
                _iconoCuadrado(Icons.description_outlined, _primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valorDias,
                        style: const TextStyle(
                          color: _textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        unidad,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _textMuted, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconoCuadrado(IconData icono, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icono, color: color, size: 20),
    );
  }

  // --- Acciones rápidas --------------------------------------------------

  Widget _accionesRapidas(VehiculoModel? v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Acciones rápidas',
                style: TextStyle(color: _textMain, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: widget.onIrAHerramientas,
              child: const Text(
                'Ver todos',
                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _accion('Documentos', Icons.description_outlined, _primaryColor,
                () => _abrirDocumentos(v)),
            const SizedBox(width: 10),
            _accion('Mantenciones', Icons.build_outlined, const Color(0xFFA855F7),
                widget.onAbrirMantenciones),
            const SizedBox(width: 10),
            _accion('Combustible', Icons.local_gas_station_outlined,
                const Color(0xFF10B981),
                () => _abrirPlaceholder('Combustible y carga',
                    Icons.local_gas_station_outlined, 'Sprint 4')),
            const SizedBox(width: 10),
            _accion('Estaciona-\nmientos', Icons.local_parking_outlined,
                const Color(0xFF3B82F6),
                () => _abrirPlaceholder('Estacionamiento',
                    Icons.local_parking_outlined, 'Sprint 4')),
          ],
        ),
      ],
    );
  }

  Widget _accion(String titulo, IconData icono, Color color, VoidCallback? onTap) {
    return Expanded(
      child: _tarjeta(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          children: [
            _iconoCuadrado(icono, color),
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: _textMain, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  // --- Gastos del mes ----------------------------------------------------

  Widget _gastos(VehiculoModel? v) {
    final r = _resumenGastos(v);
    final maximo = r.totales.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gastos del mes',
          style: TextStyle(color: _textMain, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _tarjeta(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatearPesos(r.totalMes),
                          style: const TextStyle(
                            color: _textMain,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _chipVariacion(r.variacionPct),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _barras(r, maximo)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  for (final c in CategoriaGasto.values)
                    _leyenda(c, r.desglose[c] ?? 0),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Subir el gasto es malo y bajarlo es bueno: color según eso, no según
  /// el signo.
  Widget _chipVariacion(double? pct) {
    final String texto;
    final Color color;
    final IconData icono;
    if (pct == null) {
      texto = 'Sin mes anterior';
      color = _textMuted;
      icono = Icons.remove;
    } else if (pct.abs() < 0.5) {
      texto = '0% vs. mes anterior';
      color = _textMuted;
      icono = Icons.remove;
    } else if (pct > 0) {
      texto = '${pct.round()}% vs. mes anterior';
      color = const Color(0xFFF59E0B);
      icono = Icons.trending_up;
    } else {
      texto = '${pct.abs().round()}% vs. mes anterior';
      color = const Color(0xFF10B981);
      icono = Icons.trending_down;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Siempre 6 barras; sin datos quedan en el alto mínimo.
  Widget _barras(ResumenGastos r, int maximo) {
    const altoMax = 70.0;
    const altoMin = 6.0;
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < r.totales.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: maximo == 0
                          ? altoMin
                          : altoMin + (altoMax - altoMin) * r.totales[i] / maximo,
                      decoration: BoxDecoration(
                        color: i == r.totales.length - 1
                            ? _primaryColor
                            : _primaryColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mesCorto(r.meses[i]),
                      style: const TextStyle(color: _textMuted, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _leyenda(CategoriaGasto c, int monto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: monto > 0 ? _primaryColor : Colors.white24,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${c.etiqueta} ${formatearPesos(monto)}',
          style: const TextStyle(color: _textMuted, fontSize: 12),
        ),
      ],
    );
  }

  // --- Próxima mantención y beneficios (RF-045, RF-047, RF-049) ---------

  Widget _proximaMantencion(VehiculoModel? v) {
    final m = v == null
        ? null
        : calcularProximaMantencion(
            _mantenciones.where((x) => x.vehiculoId == v.id),
          );

    String detalle = 'Sin registros';
    if (m != null) {
      final partes = <String>[
        if (m.proximaFecha != null) formatearFecha(m.proximaFecha!),
        if (m.proximoKilometraje != null)
          '${formatearMiles(m.proximoKilometraje!)} km',
      ];
      detalle = partes.join(' · ');
      final actual = v?.kilometrajeActual;
      if (actual != null && m.proximoKilometraje != null) {
        final faltan = m.proximoKilometraje! - actual;
        detalle += faltan > 0
            ? '\nFaltan ${formatearMiles(faltan)} km'
            : '\nKilometraje alcanzado';
      }
    }

    return _tarjeta(
      onTap: widget.onAbrirMantenciones,
      child: Row(
        children: [
          _iconoCuadrado(Icons.handyman_outlined, const Color(0xFFA855F7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próxima mantención',
                  style: TextStyle(color: _textMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  m?.nombreTipo ?? 'Sin mantenciones programadas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detalle, style: const TextStyle(color: _textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _tarjetaBeneficios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tarjeta(
          child: Row(
            children: [
              _iconoCuadrado(Icons.card_giftcard_outlined, const Color(0xFF10B981)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Beneficios disponibles',
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _beneficios.isEmpty ? 'Sin registros' : '${_beneficios.length}',
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _verBeneficios,
                child: const Text('Ver beneficios'),
              ),
            ],
          ),
        ),
        if (_beneficios.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _beneficios.length > 8 ? 8 : _beneficios.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _miniaturaBeneficio(_beneficios[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _miniaturaBeneficio(BeneficioModel b) {
    return SizedBox(
      width: 140,
      child: Material(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _abrirBeneficio(b),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 3 / 4, child: ImagenBeneficio(beneficio: b)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (b.destacado) ...[
                          const Icon(Icons.star, color: Color(0xFFF59E0B), size: 13),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(
                            b.etiquetaCategoria,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _textMuted, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
