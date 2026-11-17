import 'package:tag_ok/theme/app_estilos.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/estacionamiento_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/estacionamiento_service.dart';
import '../../data/services/vehiculo_service.dart';
import '../dashboard/dashboard_logica.dart';
import '../dashboard/filtro_mes_anio.dart';
import '../mantenimiento/widgets_gasto.dart' show clp;
import 'detalle_estacionamiento_screen.dart';
import 'registro_estacionamiento_screen.dart';
import 'registro_comprobante_screen.dart';

class EstacionamientosScreen extends StatefulWidget {
  const EstacionamientosScreen({super.key});

  @override
  State<EstacionamientosScreen> createState() =>
      _EstacionamientosScreenState();
}

class _EstacionamientosScreenState extends State<EstacionamientosScreen> {
  static Color get bgColor => AppColors.fondo;
  static Color get surfaceColor => AppColors.superficie;
  static Color get primaryColor => AppColors.primario;
  static Color get textMain => AppColors.texto;
  static Color get textMuted => AppColors.textoSecundario;

  final VehiculoService _vehiculoService = VehiculoService();
  final EstacionamientoService _service = EstacionamientoService();

  String? _vehiculoId;
  int? _mes;
  int? _anio;
  String? _streamDe;
  Stream<List<EstacionamientoModel>>? _stream;
  Timer? _reloj;
  bool _finalizando = false;
  VehiculoModel? _vehiculoVisible;

  String get _usuarioId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    // El tiempo se calcula desde Firestore, no desde este temporizador.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Stream<List<EstacionamientoModel>> _streamPara(String vehiculoId) {
    if (_streamDe != vehiculoId || _stream == null) {
      _streamDe = vehiculoId;
      _stream = _service.streamPorVehiculo(vehiculoId);
    }
    return _stream!;
  }

  void _elegirVehiculo(String id) {
    setState(() {
      _vehiculoId = id;
      _mes = null;
      _anio = null;
    });
  }

  String _fechaHora(DateTime fecha) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  String _duracion(Duration duracion) {
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes.remainder(60);
    final segundos = duracion.inSeconds.remainder(60);
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(horas)}:${dos(minutos)}:${dos(segundos)}';
  }

  /// Botón +: registrar un documento (boleta) con IA o a mano.
  Future<void> _abrirDocumento(VehiculoModel vehiculo) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroComprobanteScreen(vehiculoId: vehiculo.id),
      ),
    );
  }

  /// Iniciar cronometraje: pide la ubicación del auto y arranca el conteo.
  Future<void> _abrirRegistro(VehiculoModel vehiculo) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroEstacionamientoScreen(vehiculo: vehiculo),
      ),
    );
  }

  Future<void> _finalizarTiempo(EstacionamientoModel e) async {
    if (_finalizando) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar cronometraje'),
        content: const Text(
          'Se detendrá el conteo. A continuación podrás leer la boleta con IA '
          'o ingresar los datos del pago manualmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar cronometraje'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _finalizando = true);
    final salida = DateTime.now();
    try {
      await _service.finalizar(
        estacionamientoId: e.id,
        fechaSalida: salida,
      );
      if (!mounted) return;
      // Al detener el tiempo se abre de inmediato el registro del comprobante
      // (con IA o manual). Si el usuario sale sin guardar, el estacionamiento
      // queda pendiente y puede completarlo desde su tarjeta.
      setState(() => _finalizando = false);
      await _abrirComprobante(e, salida: salida);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo finalizar: $error')),
      );
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  Future<void> _abrirComprobante(
    EstacionamientoModel estacionamiento, {
    DateTime? salida,
  }) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroComprobanteScreen(
          estacionamiento: estacionamiento,
          salidaInicial: salida,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Estacionamientos',
          style: TextStyle(color: textMain, fontWeight: FontWeight.w700),
        ),
        iconTheme: IconThemeData(color: textMain),
      ),
      body: StreamBuilder<List<VehiculoModel>>(
        stream: _vehiculoService.streamVehiculosUsuario(_usuarioId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No fue posible cargar los vehículos.'));
          }
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .doc(_usuarioId)
                .snapshots(),
            builder: (context, userSnapshot) {
              final principal =
                  (userSnapshot.data?.data()?['vehiculo_principal_id'] ?? '')
                      .toString();
              final vehiculos = [
                ...(snapshot.data ?? const <VehiculoModel>[]),
              ]..sort((a, b) {
                  final esA = a.patente == principal;
                  final esB = b.patente == principal;
                  if (esA == esB) return 0;
                  return esA ? -1 : 1;
                });

              VehiculoModel? vehiculo;
              for (final v in vehiculos) {
                if (v.id == _vehiculoId) vehiculo = v;
              }
              vehiculo ??= vehiculos.isEmpty ? null : vehiculos.first;
              final seleccionado = vehiculo;
              _vehiculoVisible = seleccionado;

              return SafeArea(
                child: Column(
                  children: [
                    if (vehiculos.isNotEmpty)
                      _filtrosVehiculos(vehiculos, seleccionado?.id),
                    Expanded(
                      child: seleccionado == null
                          ? _sinVehiculos()
                          : _contenido(seleccionado),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _vehiculoVisible == null
          ? null
          : FloatingActionButton(
              heroTag: 'registrarEstacionamiento',
              backgroundColor: primaryColor,
              tooltip: 'Registrar documento',
              onPressed: () => _abrirDocumento(_vehiculoVisible!),
              child: Icon(Icons.add, color: AppColors.sobrePrimario, size: 30),
            ),
    );
  }

  Widget _filtrosVehiculos(List<VehiculoModel> vehiculos, String? activo) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (final v in vehiculos) ...[
            InkWell(
              borderRadius: BorderRadius.circular(AppRadios.tarjeta),
              onTap: () => _elegirVehiculo(v.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: activo == v.id ? primaryColor : surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadios.tarjeta),
                ),
                child: Text(
                  v.patente,
                  style: TextStyle(
                    color: activo == v.id ? AppColors.sobrePrimario : textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _contenido(VehiculoModel vehiculo) {
    return StreamBuilder<List<EstacionamientoModel>>(
      stream: _streamPara(vehiculo.id),
      builder: (context, snapshot) {
        final todos = snapshot.data ?? const <EstacionamientoModel>[];
        // Solo hay uno en curso por vehículo. Mientras corre, se ve su conteo
        // arriba y recién al cerrarlo pasa al historial.
        final enCurso = todos.where((e) => e.estaActivo).firstOrNull;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
          children: [
            _tarjetaGastoMes(todos),
            const SizedBox(height: 18),
            // Título de la sección, igual que "Gastado en ..." de arriba.
            Text(
              'Cronometraje',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            enCurso == null
                ? _botonIniciar(vehiculo)
                : _tarjetaCronometraje(enCurso),
            const SizedBox(height: 22),
            _historial(snapshot, todos),
          ],
        );
      },
    );
  }

  Widget _botonIniciar(VehiculoModel vehiculo) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _abrirRegistro(vehiculo),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: AppColors.sobrePrimario,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadios.control),
          ),
        ),
        icon: const Icon(Icons.timer_outlined),
        label: const Text(
          'Iniciar cronometraje',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  /// El estacionamiento en curso: el conteo, dónde quedó el auto y el botón
  /// para cerrarlo. Aún no aparece en el historial.
  Widget _tarjetaCronometraje(EstacionamientoModel e) {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: primaryColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tiempo transcurrido',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.exito.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadios.chip),
                ),
                child: Text(
                  'En curso',
                  style: TextStyle(
                    color: AppColors.exito,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _duracion(e.duracion),
              style: TextStyle(
                color: textMain,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Entrada: ${_fechaHora(e.fechaEntrada)}',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          if (e.direccion != null && e.direccion!.isNotEmpty)
            _detalle(Icons.place_outlined, e.direccion!),
          if (e.nivel != null && e.nivel!.isNotEmpty)
            _detalle(Icons.layers_outlined, 'Nivel: ${e.nivel}'),
          if (e.sector != null && e.sector!.isNotEmpty)
            _detalle(Icons.grid_view_outlined, 'Sector: ${e.sector}'),
          if (puedeVerUbicacion(e)) ...[
            const SizedBox(height: 6),
            _botonVerUbicacion(e),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _finalizando ? null : () => _finalizarTiempo(e),
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadios.control),
                ),
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Cerrar cronometraje'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonVerUbicacion(EstacionamientoModel e) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => verUbicacionEnMapa(context, e),
        icon: const Icon(Icons.map_outlined),
        label: const Text('Ver ubicación'),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadios.control),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaGastoMes(List<EstacionamientoModel> todos) {
    final hoy = DateTime.now();
    final delMes = todos.where((e) =>
        e.estado == EstadoEstacionamiento.finalizado &&
        e.fechaEntrada.month == hoy.month &&
        e.fechaEntrada.year == hoy.year).toList();
    final total = delMes.fold<int>(0, (suma, e) => suma + (e.costo ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastado en ${nombreDelMes(hoy.month).toLowerCase()}',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            boxShadow: AppSombras.tarjeta,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clp(total),
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                delMes.length == 1
                    ? '1 estacionamiento pagado'
                    : '${delMes.length} estacionamientos pagados',
                style: TextStyle(
                  color: AppColors.textoSecundario,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<EstacionamientoModel> _filtrar(List<EstacionamientoModel> todos) {
    return todos.where((e) {
      // El que está corriendo se ve arriba, no en el historial.
      if (e.estaActivo) return false;
      // Los pendientes de comprobante siempre se ven, para poder completarlos.
      if (e.pendienteDeComprobante) return true;
      if (_anio != null && e.fechaEntrada.year != _anio) return false;
      if (_mes != null && e.fechaEntrada.month != _mes) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final pa = a.pendienteDeComprobante ? 0 : 1;
        final pb = b.pendienteDeComprobante ? 0 : 1;
        final diferencia = pa.compareTo(pb);
        return diferencia != 0
            ? diferencia
            : b.fechaEntrada.compareTo(a.fechaEntrada);
      });
  }

  Widget _historial(
    AsyncSnapshot<List<EstacionamientoModel>> snapshot,
    List<EstacionamientoModel> todos,
  ) {
    if (snapshot.hasError) {
      return Text(
        'No fue posible cargar el historial. Revisa la conexión y los permisos.',
        style: TextStyle(color: textMuted),
      );
    }
    if (!snapshot.hasData) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }
    final lista = _filtrar(todos);
    final anios = {for (final e in todos) e.fechaEntrada.year}.toList()
      ..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Historial de estacionamientos',
                style: TextStyle(
                  color: textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${lista.length} registros',
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (todos.isNotEmpty) ...[
          const SizedBox(height: 12),
          FiltroMesAnio(
            mes: _mes,
            anio: _anio,
            anios: anios,
            alCambiarMes: (v) => setState(() => _mes = v),
            alCambiarAnio: (v) => setState(() => _anio = v),
          ),
        ],
        const SizedBox(height: 12),
        if (lista.isEmpty)
          _estadoVacio()
        else
          for (final e in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _tarjetaEstacionamiento(e),
            ),
      ],
    );
  }

  void _abrirDetalle(EstacionamientoModel e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleEstacionamientoScreen(estacionamiento: e),
      ),
    );
  }

  /// Nombre del estacionamiento; si no se le puso, su dirección.
  String _tituloDe(EstacionamientoModel e) {
    if (e.lugar.trim().isNotEmpty) return e.lugar.trim();
    final direccion = e.direccion?.trim() ?? '';
    return direccion.isNotEmpty ? direccion : 'Estacionamiento';
  }

  /// "1 h 35 min" a partir de minutos.
  String _minutos(int total) {
    final horas = total ~/ 60;
    final minutos = total % 60;
    if (horas == 0) return '$minutos min';
    return minutos == 0 ? '$horas h' : '$horas h $minutos min';
  }

  /// Tarjeta del historial: nombre, entrada, precio debajo, duración y el
  /// botón para ver la ubicación. La flecha lleva al detalle completo.
  Widget _tarjetaEstacionamiento(EstacionamientoModel e) {
    final pendiente = e.pendienteDeComprobante;
    final minutos = e.minutosTranscurridos() ?? e.duracion.inMinutes;
    final precio = pendiente
        ? 'Pendiente de comprobante'
        : (e.costo == null ? 'Sin precio' : clp(e.costo!));
    final estiloLinea = TextStyle(
      color: textMuted,
      fontSize: 12,
      height: 1.35,
    );
    return TarjetaApp(
      onTap: () => _abrirDetalle(e),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.local_parking_outlined,
                  color: primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tituloDe(e),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Entrada: ${_fechaHora(e.fechaEntrada)}',
                      style: estiloLinea,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      precio,
                      style: pendiente
                          ? estiloLinea.copyWith(color: AppColors.alerta)
                          : estiloLinea,
                    ),
                    const SizedBox(height: 4),
                    Text('Duración: ${_minutos(minutos)}', style: estiloLinea),
                  ],
                ),
              ),
              // La flecha para ver el detalle, igual que en Mantenciones.
              Icon(Icons.chevron_right, color: textMuted),
            ],
          ),
          // Pendiente de comprobante: el botón para completarlo está a la vista,
          // sin tener que abrir el detalle.
          if (pendiente) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _abrirComprobante(e),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadios.control),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Registrar comprobante'),
              ),
            ),
          ],
          if (puedeVerUbicacion(e)) ...[
            const SizedBox(height: 12),
            _botonVerUbicacion(e),
          ],
        ],
      ),
    );
  }

  Widget _detalle(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        children: [
          Icon(Icons.local_parking_outlined, color: primaryColor, size: 48),
          SizedBox(height: 16),
          Text(
            'Aún no hay estacionamientos registrados',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Presiona + para registrar un estacionamiento con tu boleta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sinVehiculos() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Text(
          'Primero registra un vehículo desde Mi Vehículo '
          'para utilizar Estacionamientos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textMuted, fontSize: 15),
        ),
      ),
    );
  }
}
