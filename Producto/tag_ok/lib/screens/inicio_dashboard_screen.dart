import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/models/beneficio_model.dart';
import '../data/models/documento_vehicular_model.dart';
import '../data/models/mantencion_model.dart';
import '../data/models/vehiculo_model.dart';
import '../data/services/beneficio_service.dart';
import '../data/services/vehiculo_service.dart';
import 'beneficios/detalle_beneficio_screen.dart';
import 'beneficios/imagen_beneficio.dart';
import 'combustible/combustible_screen.dart';
import 'dashboard/dashboard_logica.dart';
import 'dashboard/encabezado_tag_ok.dart';
import 'dashboard/estado_vehiculo_chip.dart';
import 'dashboard/gastos_historial.dart';
import 'dashboard/historial_gastos_screen.dart';
import 'herramientas/placeholder_modulo_screen.dart';
import 'mi_vehiculo/detalle_vehiculo_screen.dart';
import 'mi_vehiculo/foto_vehiculo.dart';
import 'package:tag_ok/theme/app_colors.dart';

/// "Inicio" — dashboard "Mi Auto" (Sprint 5, RF-044 a RF-049).
///
/// Datos reales del vehículo seleccionado en el carrusel. Cada fuente se lee
/// por separado y, si no existe, está vacía o no se puede leer (p. ej. las
/// colección de Estacionamientos del Sprint 4, que aún no existe), cuenta como $0 / "Sin registros" en vez de romper la pantalla.
///
/// Decisiones de alcance: el TAG (viajes) no guarda `vehiculo_id`, así que su
/// gasto se suma solo al vehículo principal (deuda técnica: agregar
/// `vehiculo_id` a los viajes requiere tocar Fase 1). En pantallas anchas el
/// contenido queda en una columna centrada de [_anchoMaximo].
class InicioDashboardScreen extends StatefulWidget {

  /// Acceso rápido a Mantenciones.
  final VoidCallback? onAbrirMantenciones;

  /// "Ver todo" de la sección Beneficios: abre la pestaña Beneficios.
  final VoidCallback? onIrABeneficios;

  /// Desde el historial de gastos, el apartado TAG abre la pestaña Auditoría
  /// (consumo e historial de viajes).
  final VoidCallback? onIrAAuditoria;

  /// Cuando no hay vehículos: lleva a la pestaña de vehículos.
  final VoidCallback? onIrAVehiculos;

  const InicioDashboardScreen({
    super.key,
    this.onAbrirMantenciones,
    this.onIrABeneficios,
    this.onIrAAuditoria,
    this.onIrAVehiculos,
  });

  @override
  State<InicioDashboardScreen> createState() => _InicioDashboardScreenState();
}

class _InicioDashboardScreenState extends State<InicioDashboardScreen> {
  static const double _anchoMaximo = 480;

  // Radio de esquina de todas las tarjetas del Inicio.
  static const double _radioTarjeta = 20;

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  // Ancho de la tarjeta del vehículo cuando hay varios, como fracción del ancho
  // de la columna: queda alineada a la izquierda y la siguiente se asoma a la
  // derecha. Con un solo vehículo la tarjeta ocupa todo el ancho.
  static const double _anchoTarjetaVehiculo = 0.8;
  static const double _altoTarjetaVehiculo = 112;
  final PageController _paginas =
      PageController(viewportFraction: _anchoTarjetaVehiculo);
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
    _escuchar(
      _gastosDeColeccion(db, 'abastecimientos', 'total', uid,
          titulo: 'Carga de combustible', campoDetalle: 'estacion_servicio'),
      (g) => _combustible = g,
    );
    _escuchar(
      _gastosDeColeccion(db, 'estacionamientos', 'costo', uid,
          titulo: 'Estacionamiento', campoDetalle: 'lugar'),
      (g) => _estacionamientos = g,
    );
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
  ) =>
      gastosDeViajes(docs);

  static Stream<List<GastoRegistro>> _gastosDeColeccion(
    FirebaseFirestore db,
    String coleccion,
    String campoMonto,
    String uid, {
    required String titulo,
    required String campoDetalle,
  }) {
    return db
        .collection(coleccion)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((s) => gastosDeDocumentos(
              s.docs,
              campoMonto: campoMonto,
              titulo: titulo,
              campoDetalle: campoDetalle,
            ));
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

  /// Gastos del vehículo por categoría. El TAG (viajes) no guarda el vehículo,
  /// así que se asigna solo al principal.
  Map<CategoriaGasto, Iterable<GastoRegistro>> _gastosDe(VehiculoModel? v) {
    if (v == null) return const {};
    bool esDe(GastoRegistro g) => g.vehiculoId == v.id;
    return {
      CategoriaGasto.tag: v.patente == _principal ? _viajesTag : const [],
      CategoriaGasto.combustible: _combustible.where(esDe),
      CategoriaGasto.estacionamientos: _estacionamientos.where(esDe),
      CategoriaGasto.mantenciones: gastosDeMantenciones(
        _mantenciones.where((m) => m.vehiculoId == v.id),
      ),
    };
  }

  ResumenGastos _resumenGastos(VehiculoModel? v) =>
      calcularResumenGastos(_gastosDe(v));

  /// "Ver todo": historial con el total pagado y el total de cada tipo,
  /// filtrable por mes y año.
  void _abrirHistorialGastos(VehiculoModel? v) {
    final nombre = v == null
        ? ''
        : ((v.alias ?? '').trim().isNotEmpty
            ? '${v.alias!.trim()} · ${v.patente}'
            : [v.marca, v.modelo, v.patente]
                .where((e) => e != null && e.trim().isNotEmpty)
                .join(' '));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistorialGastosScreen(
          nombreVehiculo: nombre,
          movimientos: movimientosDeGasto(_gastosDe(v)),
          alAbrirCategoria: _abrirCategoriaDeGasto,
        ),
      ),
    );
  }

  /// Abre la página de un tipo de gasto desde el historial. Mantenciones y TAG
  /// viven en pestañas de la app, así que se cierra el historial antes de ir.
  /// Combustible se abre como pantalla aparte; Estacionamientos aún es
  /// "Próximamente" (Sprint 4).
  void _abrirCategoriaDeGasto(CategoriaGasto categoria) {
    switch (categoria) {
      case CategoriaGasto.mantenciones:
        Navigator.pop(context);
        widget.onAbrirMantenciones?.call();
      case CategoriaGasto.tag:
        Navigator.pop(context);
        widget.onIrAAuditoria?.call();
      case CategoriaGasto.combustible:
        _abrirCombustible();
      case CategoriaGasto.estacionamientos:
        _abrirPlaceholder(
            'Estacionamiento', Icons.local_parking_outlined, 'Sprint 4');
    }
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

  void _abrirCombustible() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CombustibleScreen()),
      );

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

  void _abrirDetalleVehiculo(VehiculoModel? v) {
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registra un vehículo para ver su detalle.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalleVehiculoScreen(vehiculo: v)),
    );
  }

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
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        // El encabezado queda fuera de la lista: no se mueve al hacer scroll.
        child: Column(
          children: [
            const EncabezadoTagOk(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _anchoMaximo),
                  child: ListView(
              // El botón del mapa sobresale un poco de la barra inferior.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                Text(
                  '¡Hola, $primerNombre!',
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtituloGlobal(estadoGlobal, hayVehiculos: _vehiculos.isNotEmpty),
                  style: const TextStyle(color: AppColors.textoSecundario, fontSize: 14),
                ),
                const SizedBox(height: 18),
                _carrusel(),
                const SizedBox(height: 24),
                _gastos(seleccionado),
                const SizedBox(height: 12),
                _seccionAtencion(seleccionado),
                const SizedBox(height: 26),
                _accionesRapidas(),
                const SizedBox(height: 26),
                _seccionBeneficios(),
              ],
            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta({required Widget child, EdgeInsets? padding, VoidCallback? onTap}) {
    return Material(
      color: AppColors.superficie,
      borderRadius: BorderRadius.circular(_radioTarjeta),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radioTarjeta),
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }

  /// Título de sección ("Gastos del mes", "Beneficios"…) con un enlace
  /// opcional "Ver todo" a la derecha.
  Widget _tituloSeccion(String titulo, {VoidCallback? verTodo}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (verTodo != null)
          GestureDetector(
            onTap: verTodo,
            child: const Text(
              'Ver todo',
              style: TextStyle(
                color: AppColors.primario,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// Ícono de la marca dentro de un contenedor suave (cuadrado redondeado o
  /// círculo), como en las filas de atención y las acciones rápidas.
  Widget _iconoMarca(IconData icono, {bool circular = false, double tamano = 44}) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: AppColors.contenedorSuave,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(12),
      ),
      child: Icon(icono, color: AppColors.primario, size: tamano * 0.52),
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
            Icon(Icons.directions_car_outlined, color: AppColors.primario, size: 40),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Aún no tienes vehículos. Toca para registrar el primero.',
                style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final varios = lista.length > 1;
    if (!varios) {
      return SizedBox(
        height: _altoTarjetaVehiculo,
        child: _tarjetaVehiculo(lista.first),
      );
    }
    return Column(
      children: [
        SizedBox(
          // Alto fijo; el contenido de la tarjeta no puede desbordarlo (ver
          // _tarjetaVehiculo).
          height: _altoTarjetaVehiculo,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _paginas,
                padEnds: false,
                itemCount: lista.length,
                onPageChanged: (i) => setState(() => _indice = i),
                itemBuilder: (_, i) => Padding(
                  // Separación entre tarjetas.
                  padding: const EdgeInsets.only(right: 10),
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < lista.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _indice ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i == _indice
                      ? AppColors.primario
                      : AppColors.barraInactiva,
                ),
              ),
          ],
        ),
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
      color: AppColors.fondo.withValues(alpha: 0.85),
      shape: const CircleBorder(side: BorderSide(color: Colors.transparent)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icono, color: AppColors.texto, size: 22),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _abrirDetalleVehiculo(v),
      child: Row(
        children: [
          // Foto circular con un anillo lavanda: la imagen (foto o dibujo del
          // auto) llena todo el círculo, sin márgenes, y se recorta lo que sobre.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.barraInactiva,
            ),
            child: ClipOval(
              child: Container(
                width: 68,
                height: 68,
                color: AppColors.contenedorSuave,
                child: FotoVehiculo(
                  fotoPath: v.fotoPath,
                  assetPredeterminado: _imagenPorDefecto(v),
                  paddingPredeterminado: EdgeInsets.zero,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Si el texto no cabe en el ancho, se achica en vez de cortarse o
          // desbordar.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  EstadoVehiculoChip(estado: _estadoDe(v)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Atención: próxima mantención y próximo vencimiento ----------------------

  /// Dos filas alargadas, una debajo de la otra, justo bajo Gastos del mes:
  /// primero el próximo vencimiento y luego la próxima mantención. la próxima
  /// mantención según el kilometraje del vehículo (el que se pidió al
  /// registrarlo, más 10.000 km) y la fecha del documento que vence primero.
  /// Ambas abren el detalle del vehículo.
  Widget _seccionAtencion(VehiculoModel? v) {
    final kmMantencion = kilometrajeProximaMantencion(v?.kilometrajeActual);

    final proximo = v == null
        ? null
        : calcularProximoVencimiento(_documentosDe(v));
    final fecha = proximo?.documento.fechaVencimiento;

    final detalleVencimiento = proximo == null
        ? 'Sin documentos'
        : (proximo.dias < 0
            ? '${proximo.documento.tipoDocumento.etiqueta} · Vencido'
            : proximo.documento.tipoDocumento.etiqueta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Arriba el próximo vencimiento (abre el detalle del vehículo, donde
        // están sus documentos) y debajo la próxima mantención (abre la página
        // de Mantenciones).
        _filaAtencion(
          icono: Icons.calendar_today_outlined,
          titulo: 'Próximo vencimiento',
          valor: fecha == null ? '--' : formatearFecha(fecha),
          detalle: detalleVencimiento,
          onTap: () => _abrirDetalleVehiculo(v),
        ),
        const SizedBox(height: 10),
        _filaAtencion(
          icono: Icons.build_outlined,
          titulo: 'Próxima mantención',
          valor: kmMantencion == null ? '--' : '${formatearMiles(kmMantencion)} km',
          detalle: kmMantencion == null
              ? 'Sin kilometraje registrado'
              : 'A tus',
          onTap: () => widget.onAbrirMantenciones?.call(),
        ),
      ],
    );
  }

  /// Fila baja: ícono, título (con su detalle debajo, si lo hay) y, a la
  /// derecha, el valor. Si el ancho no alcanza, el valor baja a la línea de
  /// abajo y la tarjeta se alarga para contenerlo (no tiene alto fijo, así que
  /// nunca desborda).
  Widget _filaAtencion({
    required IconData icono,
    required String titulo,
    required String valor,
    required String detalle,
    required VoidCallback onTap,
  }) {
    return _tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            _iconoMarca(icono),
            const SizedBox(width: 14),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (detalle.isNotEmpty)
                        Text(
                          detalle,
                          style: const TextStyle(
                            color: AppColors.textoSecundario,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    valor,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.textoSecundario, size: 22),
          ],
        ),
      ),
    );
  }

  // --- Acciones rápidas --------------------------------------------------

  Widget _accionesRapidas() {
    final acciones = <({String titulo, IconData icono, VoidCallback? onTap})>[
      (
        titulo: 'Mantenciones',
        icono: Icons.build_outlined,
        onTap: widget.onAbrirMantenciones,
      ),
      (
        titulo: 'Combustible',
        icono: Icons.local_gas_station_outlined,
        onTap: _abrirCombustible,
      ),
      (
        titulo: 'Estacionamiento',
        icono: Icons.local_parking_outlined,
        onTap: () => _abrirPlaceholder(
            'Estacionamiento', Icons.local_parking_outlined, 'Sprint 4'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Acciones rápidas'),
        const SizedBox(height: 12),
        // Siempre las tres una al lado de la otra y del mismo tamaño: se reparten
        // el ancho disponible, así que en pantallas más anchas se alargan.
        SizedBox(
          height: 104,
          child: Row(
            children: [
              for (var i = 0; i < acciones.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _accion(
                    acciones[i].titulo,
                    acciones[i].icono,
                    acciones[i].onTap,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Ícono en un círculo suave y su nombre debajo.
  Widget _accion(String titulo, IconData icono, VoidCallback? onTap) {
    return _tarjeta(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconoMarca(icono, circular: true),
            const SizedBox(height: 10),
            // Una sola línea: si el nombre no cabe, se achica un poco en vez de
            // bajar de línea y desbordar la tarjeta.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                titulo,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
    );
  }

  // --- Gastos del mes ----------------------------------------------------

  // Alto de la línea del precio (28 px con interlineado 1.2). El tope del
  // gráfico es ese mismo alto: la barra más alta llega a la altura del precio.
  // Contenido de la tarjeta de gastos (precio/gráfico + meses) y su alto total
  // (con 16 px de margen arriba y abajo): la tarjeta del vehículo usa el mismo.
  static const double _altoContenidoGastos = altoContenidoTarjetaGastos;
  static const double _altoPrecio = 34;
  static const double _altoMinBarra = 6;

  Widget _gastos(VehiculoModel? v) {
    final r = _resumenGastos(v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Gastos del mes', verTodo: () => _abrirHistorialGastos(v)),
        const SizedBox(height: 12),
        _tarjeta(
          padding: const EdgeInsets.all(18),
          child: SizedBox(
            height: _altoContenidoGastos,
            child: Row(
            // El monto queda centrado respecto del gráfico (barras + meses).
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                // Una sola línea: si el monto es largo, se achica en vez de
                // partirse, para no mover el tope del gráfico.
                child: SizedBox(
                  height: _altoPrecio,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatearPesos(r.totalMes),
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _barras(r)),
            ],
          ),
          ),
        ),
      ],
    );
  }

  /// Una barra por mes (los últimos 5). La altura NO es proporcional al monto:
  /// depende de la posición del mes entre los de mayor a menor gasto. El que más
  /// gastó llega al tope (el alto del precio) y los demás bajan un escalón por
  /// puesto; un mes sin gastos queda en el alto mínimo. El mes actual va en el
  /// color primario y los demás en lavanda claro.
  Widget _barras(ResumenGastos r) {
    final alturas = alturasPorPosicion(r.totales);
    final ultimo = r.totales.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _altoPrecio,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < alturas.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: _altoMinBarra +
                            (_altoPrecio - _altoMinBarra) * alturas[i],
                        decoration: BoxDecoration(
                          color: i == ultimo
                              ? AppColors.primario
                              : AppColors.barraInactiva,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < r.meses.length; i++)
              Expanded(
                child: Text(
                  mesCorto(r.meses[i]),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i == r.meses.length - 1
                        ? AppColors.primario
                        : AppColors.textoSecundario,
                    fontSize: 10,
                    fontWeight: i == r.meses.length - 1
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- Beneficios --------------------------------------------------------

  /// Título "Beneficios" y, debajo, solo los beneficios (con su imagen): los
  /// destacados primero. Sin ninguno, un aviso corto.
  Widget _seccionBeneficios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Beneficios', verTodo: widget.onIrABeneficios),
        const SizedBox(height: 12),
        if (_beneficios.isEmpty)
          _tarjeta(
            child: const Row(
              children: [
                Icon(Icons.card_giftcard_outlined, color: AppColors.textoSecundario),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aún no hay beneficios disponibles.',
                    style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          // Carrusel hacia el lado. En la web, por defecto el mouse no arrastra las
          // listas; se habilita para que también se pueda deslizar con el mouse.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: const {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: SizedBox(
              // Imagen 3:4 de 140 px de ancho (~187 px) + categoría + título en
              // dos líneas, con margen para que no desborde.
              height: 262,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _beneficios.length > 8 ? 8 : _beneficios.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _miniaturaBeneficio(_beneficios[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _miniaturaBeneficio(BeneficioModel b) {
    return SizedBox(
      width: 140,
      child: Material(
        color: AppColors.superficie,
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
                          const Icon(Icons.star, color: AppColors.advertencia, size: 13),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(
                            b.etiquetaCategoria,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textoSecundario, fontSize: 10),
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
                        color: AppColors.texto,
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
