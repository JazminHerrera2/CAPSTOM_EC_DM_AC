import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/models/tipo_mantencion.dart';
import '../../data/services/mantencion_service.dart';
import '../../utils/busqueda_mantencion.dart';
import '../dashboard/filtro_mes_anio.dart';
import 'gasto_periodo.dart';
import 'selector_tipo_mantencion.dart';
import 'tarjeta_mantencion.dart';

class HistorialMantenimientosScreen extends StatefulWidget {
  /// Patente del vehículo elegido en Mantenciones.
  final String? patente;

  /// Vehículo elegido en Mantenciones; sus mantenciones son las que se listan.
  final String? vehiculoId;

  /// Si viene, el historial se abre filtrado por ese mes o año; el usuario
  /// puede cambiarlo en el panel de filtros.
  final PeriodoGasto? periodo;

  const HistorialMantenimientosScreen({
    super.key,
    this.patente,
    this.vehiculoId,
    this.periodo,
  });

  @override
  State<HistorialMantenimientosScreen> createState() =>
      _HistorialMantenimientosScreenState();
}

class _HistorialMantenimientosScreenState
    extends State<HistorialMantenimientosScreen> {
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFCBD5E1);

  late final String _vehiculoSeleccionado =
      widget.patente ?? 'Todos los vehículos';
  final TextEditingController _busquedaController = TextEditingController();

  Stream<List<MantencionModel>>? _stream;

  // Filtros del panel (se abre con el ícono junto a la búsqueda). null = todos.
  int? _mes;
  int? _anio;
  String? _tipoFiltro;
  bool _mostrarFiltros = false;

  static const String _opcionTodos = 'Todos';
  static const String _opcionOtros = 'Otros';
  static final List<String> _etiquetasTipo = [
    for (final t in TipoMantencion.values)
      if (t != TipoMantencion.otra) t.etiqueta,
  ];
  static final List<String> _opcionesTipo = [
    _opcionTodos,
    ..._etiquetasTipo,
    _opcionOtros,
  ];

  bool get _hayFiltros => _mes != null || _anio != null || _tipoFiltro != null;

  @override
  void initState() {
    super.initState();
    // Si se abre con un periodo, ese mes o año parte aplicado.
    final periodo = widget.periodo;
    if (periodo != null && periodo.tipo != TipoPeriodo.todo) {
      _anio = periodo.inicio.year;
      if (periodo.tipo == TipoPeriodo.mes) _mes = periodo.inicio.month;
    }
    final id = widget.vehiculoId;
    if (id != null) {
      _stream = MantencionService()
          .streamPorVehiculo(id, estado: EstadoMantencion.realizada);
    }
    // La búsqueda filtra la lista mientras se escribe.
    _busquedaController.addListener(() => setState(() {}));
  }

  void _limpiarFiltros() => setState(() {
        _mes = null;
        _anio = null;
        _tipoFiltro = null;
      });

  /// ¿El título de la mantención coincide con el tipo elegido? "Otros" = los
  /// que no corresponden a ninguno de la lista.
  bool _coincideTipo(MantencionModel m, String tipo) {
    final titulo = m.nombreTipo.trim().toLowerCase();
    if (tipo == _opcionOtros) {
      return !_etiquetasTipo.any((e) => e.toLowerCase() == titulo);
    }
    return titulo == tipo.toLowerCase();
  }

  /// Aplica mes, año, tipo y búsqueda en todo el texto de la mantención (el
  /// vehículo ya viene en la consulta).
  List<MantencionModel> _filtrar(List<MantencionModel> registradas) {
    final texto = _busquedaController.text;
    return registradas.where((m) {
      final fecha = m.fecha;
      if (_anio != null && (fecha == null || fecha.year != _anio)) return false;
      if (_mes != null && (fecha == null || fecha.month != _mes)) return false;
      final tipo = _tipoFiltro;
      if (tipo != null && !_coincideTipo(m, tipo)) return false;
      if (!coincideConBusqueda(m, texto)) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: textMain,
        ),
        title: const Text(
          'Historial de mantenciones',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: stream == null
            ? _contenido(null)
            : StreamBuilder<List<MantencionModel>>(
                stream: stream,
                builder: (context, snapshot) => _contenido(snapshot),
              ),
      ),
    );
  }

  Widget _contenido(AsyncSnapshot<List<MantencionModel>>? snapshot) {
    final todas = snapshot?.data ?? const <MantencionModel>[];
    final anios = {
      for (final m in todas)
        if (m.fecha != null) m.fecha!.year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        _selectorVehiculo(),

        const SizedBox(height: 10),

        // Búsqueda y, a su lado, el ícono que abre los filtros.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _campoBusqueda()),
            const SizedBox(width: 10),
            _botonFiltros(),
          ],
        ),

        if (_mostrarFiltros) ...[
          const SizedBox(height: 10),
          _panelFiltros(anios),
        ],

        const SizedBox(height: 26),

        _seccionLista(snapshot),
      ],
    );
  }

  // ================================================================
  // FILTROS (MES, AÑO Y TIPO)
  // ================================================================

  /// Ícono de filtros, a la derecha de la búsqueda. Se resalta cuando el panel
  /// está abierto o hay filtros aplicados.
  Widget _botonFiltros() {
    final activo = _mostrarFiltros || _hayFiltros;
    return Tooltip(
      message: 'Filtros',
      child: GestureDetector(
        onTap: () => setState(() => _mostrarFiltros = !_mostrarFiltros),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: activo ? primaryColor : surfaceColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                color: activo ? Colors.white : primaryColor,
                size: 22,
              ),
              if (_hayFiltros && !_mostrarFiltros)
                Positioned(
                  top: 11,
                  right: 11,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mes y año (mismos desplegables que el historial de gastos) y el tipo de
  /// mantención en acordeón.
  Widget _panelFiltros(List<int> anios) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FiltroMesAnio(
          mes: _mes,
          anio: _anio,
          anios: anios,
          alCambiarMes: (v) => setState(() => _mes = v),
          alCambiarAnio: (v) => setState(() => _anio = v),
        ),
        const SizedBox(height: 10),
        SelectorTipoMantencion(
          label: 'Tipo de mantención',
          hint: _opcionTodos,
          opciones: _opcionesTipo,
          valor: _tipoFiltro,
          onChanged: (v) =>
              setState(() => _tipoFiltro = v == _opcionTodos ? null : v),
        ),
        if (_hayFiltros)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _limpiarFiltros,
              child: const Text('Limpiar filtros'),
            ),
          ),
      ],
    );
  }

  // ================================================================
  // LISTA
  // ================================================================

  Widget _encabezadoLista(int cantidad) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Mantenciones realizadas',
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            cantidad == 1 ? '1 registro' : '$cantidad registros',
            style: const TextStyle(
              color: primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _seccionLista(AsyncSnapshot<List<MantencionModel>>? snapshot) {
    if (snapshot == null) {
      return Column(
        children: [
          _encabezadoLista(0),
          const SizedBox(height: 12),
          _estadoVacio(detalle: 'Registra un vehículo para ver su historial.'),
        ],
      );
    }
    if (snapshot.hasError) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'No fue posible cargar las mantenciones.',
            style: TextStyle(color: textMuted),
          ),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    final todas = snapshot.data!;
    final lista = _filtrar(todas);

    return Column(
      children: [
        _encabezadoLista(lista.length),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          _estadoVacio(
            detalle: todas.isEmpty
                ? null
                : 'No hay mantenciones que coincidan con los filtros.',
          )
        else
          for (final m in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaMantencion(mantencion: m),
            ),
      ],
    );
  }

  // ================================================================
  // FILTRO VEHÍCULO
  // ================================================================

  /// Solo muestra el vehículo elegido en Mantenciones; no se puede cambiar
  /// desde acá (sin toque ni flecha).
  Widget _selectorVehiculo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_car_outlined,
            color: primaryColor,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo',
                  style: TextStyle(color: textMuted, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  _vehiculoSeleccionado,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // BÚSQUEDA (EN TODO EL TEXTO)
  // ================================================================

  Widget _campoBusqueda() {
    return TextField(
      controller: _busquedaController,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Buscar por tipo, taller, descripción...',
        hintStyle: const TextStyle(color: textMuted),
        prefixIcon: const Icon(Icons.search_rounded, color: primaryColor, size: 21),
        suffixIcon: _busquedaController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close_rounded, size: 18),
                color: textMuted,
                onPressed: _busquedaController.clear,
              ),
        filled: true,
        fillColor: surfaceColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  // ================================================================
  // ESTADO VACÍO
  // ================================================================

  Widget _estadoVacio({String? detalle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.car_repair_outlined,
              color: primaryColor,
              size: 32,
            ),
          ),

          const SizedBox(height: 17),

          const Text(
            'Aún no hay mantenciones registradas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            detalle ??
                'Cuando registres una mantención, podrás encontrarla en este historial.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),

        ],
      ),
    );
  }
}
