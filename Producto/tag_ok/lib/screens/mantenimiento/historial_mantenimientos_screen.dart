import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/services/mantencion_service.dart';
import 'gasto_periodo.dart';
import 'tarjeta_mantencion.dart';

class HistorialMantenimientosScreen extends StatefulWidget {
  /// Patente del vehículo elegido en Mantenciones.
  final String? patente;

  /// Vehículo elegido en Mantenciones; sus mantenciones son las que se listan.
  final String? vehiculoId;

  /// Si viene (desde "Ver detalle" del card de gasto), el historial se abre
  /// filtrado por ese mes o año; el usuario puede quitar el filtro.
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
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF334155);

  late final String _vehiculoSeleccionado =
      widget.patente ?? 'Todos los vehículos';
  final TextEditingController _busquedaController = TextEditingController();

  Stream<List<MantencionModel>>? _stream;

  /// Filtro de periodo activo (null = sin filtro).
  PeriodoGasto? _periodo;

  @override
  void initState() {
    super.initState();
    _periodo = widget.periodo;
    final id = widget.vehiculoId;
    if (id != null) {
      _stream = MantencionService()
          .streamPorVehiculo(id, estado: EstadoMantencion.realizada);
    }
    // La búsqueda filtra la lista mientras se escribe.
    _busquedaController.addListener(() => setState(() {}));
  }

  /// Aplica la búsqueda por título (el de vehículo ya viene en la consulta).
  List<MantencionModel> _filtrar(List<MantencionModel> registradas) {
    final periodo = _periodo;
    final todas = periodo == null
        ? registradas
        : registradas
            .where((m) => m.fecha != null && periodo.contiene(m.fecha!))
            .toList();
    final texto = _busquedaController.text.trim().toLowerCase();
    if (texto.isEmpty) return todas;
    return todas
        .where((m) => m.nombreTipo.toLowerCase().contains(texto))
        .toList();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            _cabecera(),

            const SizedBox(height: 24),

            const Text(
              'Filtrar historial',
              style: TextStyle(
                color: textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            _selectorVehiculo(),

            const SizedBox(height: 10),

            _campoBusqueda(),

            if (_periodo != null) ...[
              const SizedBox(height: 10),
              _chipPeriodo(_periodo!),
            ],

            const SizedBox(height: 26),

            _seccionLista(),
          ],
        ),
      ),
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

  Widget _seccionLista() {
    final stream = _stream;
    if (stream == null) {
      return Column(
        children: [
          _encabezadoLista(0),
          const SizedBox(height: 12),
          _estadoVacio(detalle: 'Registra un vehículo para ver su historial.'),
        ],
      );
    }

    return StreamBuilder<List<MantencionModel>>(
      stream: stream,
      builder: (context, snapshot) {
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
                    : _periodo != null
                        ? 'No hay mantenciones que coincidan con los filtros.'
                        : 'No hay mantenciones de este tipo para el vehículo.',
              )
            else
              for (final m in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TarjetaMantencion(mantencion: m),
                ),
          ],
        );
      },
    );
  }

  // ================================================================
  // CABECERA
  // ================================================================

  Widget _cabecera() {
    return const Text(
      'Aquí podrás revisar las mantenciones y servicios realizados a tus vehículos.',
      style: TextStyle(
        color: textMuted,
        fontSize: 13,
        height: 1.45,
      ),
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
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_car_outlined,
            color: textMuted,
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
  // FILTRO PERIODO
  // ================================================================

  /// Aviso del periodo filtrado, con una X para quitarlo.
  Widget _chipPeriodo(PeriodoGasto periodo) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 4),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, color: primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Periodo: ${periodo.etiqueta}',
              style: const TextStyle(
                color: textMain,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              tooltip: 'Quitar filtro de periodo',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () => setState(() => _periodo = null),
              icon: const Icon(Icons.close_rounded, size: 18),
              color: textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // BÚSQUEDA POR TÍTULO
  // ================================================================

  Widget _campoBusqueda() {
    return TextField(
      controller: _busquedaController,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: textMain, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Buscar por tipo de mantención',
        hintStyle: const TextStyle(color: textMuted),
        prefixIcon: const Icon(Icons.search_rounded, color: textMuted, size: 21),
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
          color: Colors.white.withOpacity(0.05),
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
