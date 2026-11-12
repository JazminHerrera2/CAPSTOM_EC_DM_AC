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
import '../mantenimiento/widgets_gasto.dart' show TokensGasto, clp;
import 'registro_estacionamiento_screen.dart';
import 'registro_comprobante_screen.dart';

class EstacionamientosScreen extends StatefulWidget {
  const EstacionamientosScreen({super.key});

  @override
  State<EstacionamientosScreen> createState() =>
      _EstacionamientosScreenState();
}

class _EstacionamientosScreenState extends State<EstacionamientosScreen> {
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Colors.white;
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

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
        title: const Text('Finalizar tiempo'),
        content: const Text(
          'Se detendrá el cronómetro y el estacionamiento quedará '
          'pendiente de registrar su comprobante de pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Finalizar tiempo'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _finalizando = true);
    try {
      await _service.finalizar(
        estacionamientoId: e.id,
        fechaSalida: DateTime.now(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiempo detenido. Comprobante pendiente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo finalizar: $error')),
      );
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  Future<void> _abrirComprobante(EstacionamientoModel estacionamiento) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroComprobanteScreen(estacionamiento: estacionamiento),
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
        title: const Text(
          'Estacionamientos',
          style: TextStyle(color: textMain, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: textMain),
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
          : FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              onPressed: () => _abrirRegistro(_vehiculoVisible!),
              icon: const Icon(Icons.add),
              label: const Text('Estacionamiento'),
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
              borderRadius: BorderRadius.circular(20),
              onTap: () => _elegirVehiculo(v.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: activo == v.id ? primaryColor : surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  v.patente,
                  style: TextStyle(
                    color: activo == v.id ? Colors.white : textMuted,
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _tarjetaGastoMes(todos),
            const SizedBox(height: 22),
            _historial(snapshot, todos),
          ],
        );
      },
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
          style: const TextStyle(
            color: TokensGasto.textoPrincipal,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TokensGasto.fondoCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clp(total),
                style: const TextStyle(
                  color: TokensGasto.textoPrincipal,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                delMes.length == 1
                    ? '1 estacionamiento pagado'
                    : '${delMes.length} estacionamientos pagados',
                style: const TextStyle(
                  color: TokensGasto.textoSecundario,
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
      // Los activos y pendientes siempre se ven para no ocultar acciones.
      if (e.estado != EstadoEstacionamiento.finalizado) return true;
      if (_anio != null && e.fechaEntrada.year != _anio) return false;
      if (_mes != null && e.fechaEntrada.month != _mes) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        int prioridad(EstacionamientoModel e) {
          if (e.estaActivo) return 0;
          if (e.pendienteDeComprobante) return 1;
          return 2;
        }
        final diferencia = prioridad(a).compareTo(prioridad(b));
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
      return const Text(
        'No fue posible cargar el historial. Revisa la conexión y los permisos.',
        style: TextStyle(color: textMuted),
      );
    }
    if (!snapshot.hasData) {
      return const Center(
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
            const Expanded(
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
              style: const TextStyle(
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

  Widget _tarjetaEstacionamiento(EstacionamientoModel e) {
    final activo = e.estaActivo;
    final pendiente = e.pendienteDeComprobante;
    final etiqueta = activo
        ? 'En curso'
        : pendiente
            ? 'Pendiente de comprobante'
            : 'Finalizado';
    final colorEstado = activo
        ? const Color(0xFF047857)
        : pendiente
            ? const Color(0xFFB45309)
            : primaryColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_parking_outlined,
                  color: primaryColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.lugar,
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (e.costo != null)
                Text(
                  clp(e.costo!),
                  style: const TextStyle(
                    color: textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              etiqueta,
              style: TextStyle(
                color: colorEstado,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (e.direccion != null && e.direccion!.isNotEmpty)
            _detalle(Icons.place_outlined, e.direccion!),
          if (e.nivel != null && e.nivel!.isNotEmpty)
            _detalle(Icons.layers_outlined, 'Nivel: ${e.nivel}'),
          if (e.sector != null && e.sector!.isNotEmpty)
            _detalle(Icons.grid_view_outlined, 'Sector: ${e.sector}'),
          _detalle(Icons.login_outlined, 'Entrada: ${_fechaHora(e.fechaEntrada)}'),
          if (e.fechaSalida != null)
            _detalle(Icons.logout_outlined, 'Salida: ${_fechaHora(e.fechaSalida!)}'),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 19, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                _duracion(e.duracion),
                style: const TextStyle(
                  color: textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (activo || pendiente) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: activo
                    ? (_finalizando ? null : () => _finalizarTiempo(e))
                    : () => _abrirComprobante(e),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: Icon(activo ? Icons.stop_circle_outlined : Icons.receipt_long_outlined),
                label: Text(activo ? 'Finalizar tiempo' : 'Registrar comprobante'),
              ),
            ),
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
              style: const TextStyle(color: textMuted, fontSize: 12),
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
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
            'Presiona + Estacionamiento para iniciar tu primer registro.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sinVehiculos() {
    return const Center(
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
