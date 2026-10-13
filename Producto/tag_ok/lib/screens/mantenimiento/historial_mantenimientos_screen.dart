import 'package:flutter/material.dart';

import '../../data/models/mantencion_model.dart';
import '../../data/models/tipo_mantencion.dart';
import '../../data/services/mantencion_service.dart';
import 'selector_tipo_mantencion.dart';
import 'tarjeta_mantencion.dart';

class HistorialMantenimientosScreen extends StatefulWidget {
  /// Patente del vehículo elegido en Mantenciones.
  final String? patente;

  /// Vehículo elegido en Mantenciones; sus mantenciones son las que se listan.
  final String? vehiculoId;

  const HistorialMantenimientosScreen({
    super.key,
    this.patente,
    this.vehiculoId,
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
  static const String _todosLosTipos = 'Todos los tipos';
  String _tipoSeleccionado = _todosLosTipos;
  final TextEditingController _otroTipoController = TextEditingController();

  Stream<List<MantencionModel>>? _stream;

  @override
  void initState() {
    super.initState();
    final id = widget.vehiculoId;
    if (id != null) {
      _stream = MantencionService()
          .streamPorVehiculo(id, estado: EstadoMantencion.realizada);
    }
    // El texto de "Otra" filtra la lista mientras se escribe.
    _otroTipoController.addListener(() => setState(() {}));
  }

  /// Aplica el filtro de tipo (el de vehículo ya viene en la consulta).
  List<MantencionModel> _filtrar(List<MantencionModel> todas) {
    if (_tipoSeleccionado == _todosLosTipos) return todas;
    final tipo = TipoMantencion.fromEtiqueta(_tipoSeleccionado);
    final texto = _otroTipoController.text.trim().toLowerCase();
    return todas.where((m) {
      if (m.tipo != tipo) return false;
      if (tipo == TipoMantencion.otra && texto.isNotEmpty) {
        return (m.tipoOtro ?? '').toLowerCase().contains(texto);
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _otroTipoController.dispose();
    super.dispose();
  }


  final List<String> _tipos = TipoMantencion.etiquetas;

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

            _selectorTipo(),

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
  // FILTRO TIPO
  // ================================================================

  Widget _selectorTipo() {
    return SelectorTipoMantencion(
      opciones: [_todosLosTipos, ..._tipos],
      valor: _tipoSeleccionado,
      flotante: true,
      onChanged: (v) => setState(() => _tipoSeleccionado = v),
      otroController: _otroTipoController,
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
