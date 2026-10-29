import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/documento_vehicular_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/vehiculo_service.dart';
import 'documentos_vehiculo_seccion.dart';
import 'foto_vehiculo.dart';
import 'registrar_editar_vehiculo_screen.dart';

/// Detalle de un vehículo. Escucha el documento en Firestore para reflejar al
/// instante los cambios (por ejemplo, el kilometraje tras editarlo); mientras
/// carga, o si el documento ya no existe, usa el [vehiculo] recibido.
class DetalleVehiculoScreen extends StatelessWidget {
  final VehiculoModel vehiculo;

  const DetalleVehiculoScreen({
    super.key,
    required this.vehiculo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('vehiculos')
          .doc(vehiculo.id)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final actual = data != null && data.exists
            ? VehiculoModel.fromJson(data.data()!, data.id)
            : vehiculo;

        return _DetalleVehiculoVista(vehiculo: actual);
      },
    );
  }
}

class _DetalleVehiculoVista extends StatelessWidget {
  final VehiculoModel vehiculo;

  const _DetalleVehiculoVista({
    required this.vehiculo,
  });

  static const Color _bgColor = Color(0xFFF1F5F9);
  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _surfaceLight = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  // ------------------------------------------------------------
  // IMAGEN SEGÚN TIPO DE VEHÍCULO
  // ------------------------------------------------------------

  String _imagenVehiculo() {
    final tipo =
        (vehiculo.tipoVehiculo ?? '').toUpperCase().trim();

    if (tipo == 'MOTO') {
      return 'assets/imagenes/vehiculos/moto.png';
    }

    if (tipo == 'CAMIONETA' ||
        tipo == 'CAMION' ||
        tipo == 'CAMIÓN') {
      return 'assets/imagenes/vehiculos/camion.png';
    }

    return 'assets/imagenes/vehiculos/auto.png';
  }

  String _nombreTipo() {
    final tipo =
        (vehiculo.tipoVehiculo ?? '').toUpperCase().trim();

    if (tipo == 'MOTO') return 'Moto';

    if (tipo == 'CAMIONETA' ||
        tipo == 'CAMION' ||
        tipo == 'CAMIÓN') {
      return 'Camión';
    }

    return 'Auto';
  }

  // ------------------------------------------------------------
  // ESTADOS
  // ------------------------------------------------------------

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Atención requerida':
        return Colors.redAccent;

      case 'Próximo vencimiento':
        return const Color(0xFFF97316);

      case 'Todo al día':
        return const Color(0xFF10B981);

      default:
        return _textMuted;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'Atención requerida':
        return Icons.error_outline;

      case 'Próximo vencimiento':
        return Icons.schedule_outlined;

      case 'Todo al día':
        return Icons.check_circle_outline;

      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alias =
        vehiculo.alias?.trim().isNotEmpty == true
            ? vehiculo.alias!.trim()
            : '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''}'.trim();

    final nombrePrincipal =
        alias.isEmpty ? vehiculo.patente : alias;

    final marcaModelo =
        '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''}'.trim();

    return Scaffold(
      backgroundColor: _bgColor,

      // ----------------------------------------------------------
      // APP BAR
      // ----------------------------------------------------------

      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: _textMain,
        ),
        title: const Text(
          'Detalle de vehículo',
          style: TextStyle(
            color: _textMain,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Editar vehículo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      RegistrarEditarVehiculoScreen(
                    vehiculo: vehiculo,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.edit_outlined,
              color: _textMain,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ----------------------------------------------------------
      // DOCUMENTOS
      // ----------------------------------------------------------

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('documentos_vehiculares')
            .where(
              'uid',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '',
            )
            .where(
              'vehiculo_id',
              isEqualTo: vehiculo.id,
            )
            .snapshots(),
        builder: (context, snapshot) {
          final documentos =
              (snapshot.data?.docs ?? [])
                  .map(
                    (d) =>
                        DocumentoVehicularModel.fromJson(
                      d.data(),
                      d.id,
                    ),
                  )
                  .toList();

          final estado =
              VehiculoModel.calcularEstadoGeneral(
            documentos
                .map((d) => d.fechaVencimiento)
                .toList(),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              35,
            ),
            children: [
              // --------------------------------------------------
              // HERO VEHÍCULO
              // --------------------------------------------------

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 220,
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: FotoVehiculo(
                        fotoPath: vehiculo.fotoPath,
                        assetPredeterminado: _imagenVehiculo(),
                        paddingPredeterminado:
                            const EdgeInsets.all(20),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  nombrePrincipal,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _textMain,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Información del vehículo',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _mostrarInformacion(context),
                                icon: const Icon(
                                  Icons.info_outline,
                                  color: _textMuted,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),

                          if (marcaModelo.isNotEmpty &&
                              marcaModelo != nombrePrincipal) ...[
                            const SizedBox(height: 5),
                            Text(
                              marcaModelo,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _colorEstado(estado)
                                  .withOpacity(0.10),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                color: _colorEstado(estado)
                                    .withOpacity(0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _iconoEstado(estado),
                                  color:
                                      _colorEstado(estado),
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  estado,
                                  style: TextStyle(
                                    color:
                                        _colorEstado(estado),
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // --------------------------------------------------
              // DOCUMENTOS
              // --------------------------------------------------

              const Text(
                'Documentos',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 14),

              // Mismas tarjetas que la pantalla Documentos: nombre, estado,
              // vencimiento y "Actualizar". Al tocar una se abre su detalle.
              DocumentosVehiculoSeccion(
                vehiculoId: vehiculo.id,
                patenteVehiculo: vehiculo.patente,
                documentos: documentos,
                mostrarTitulo: false,
                mostrarVehiculo: false,
                mostrarBotonAgregar: true,
              ),

              const SizedBox(height: 28),

              // --------------------------------------------------
              // ELIMINAR VEHÍCULO
              // --------------------------------------------------

              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _confirmarEliminar(context, nombrePrincipal),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar vehículo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: Colors.redAccent.withOpacity(0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // ELIMINAR
  // ------------------------------------------------------------

  Future<void> _confirmarEliminar(
    BuildContext context,
    String nombre,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¿Eliminar vehículo?',
                  style: TextStyle(color: _textMain),
                ),
              ),
            ],
          ),
          content: Text(
            'Se eliminará "$nombre" junto con todos sus documentos y '
            'avisos de vencimiento. Esta acción no se puede deshacer.',
            style: const TextStyle(
              color: _textMuted,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true || !context.mounted) return;

    // Bloquea la pantalla mientras se borra.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await VehiculoService().eliminarVehiculo(vehiculo.id);

      navigator.pop(); // cierra el indicador de carga
      navigator.pop(); // vuelve a Mi Vehículo
      messenger.showSnackBar(
        const SnackBar(content: Text('Vehículo eliminado.')),
      );
    } catch (e) {
      debugPrint('No se pudo eliminar el vehículo ${vehiculo.id}: $e');
      navigator.pop(); // cierra el indicador de carga
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo eliminar el vehículo. Intenta nuevamente.',
          ),
        ),
      );
    }
  }

  /// 160000 -> "160.000"
  String _conMiles(int valor) => valor.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );

  bool _tieneValor(String? valor) =>
      valor != null && valor.trim().isNotEmpty;

  // ------------------------------------------------------------
  // INFORMACIÓN ADICIONAL
  // ------------------------------------------------------------

  /// Ventana emergente con los datos del vehículo: patente, tipo, marca, modelo,
  /// año, combustible y kilometraje (solo los que existen).
  void _mostrarInformacion(BuildContext context) {
    final filas = <Widget>[
      _filaInformacion(
        Icons.badge_outlined,
        'Patente',
        vehiculo.patente,
      ),
      _filaInformacion(
        Icons.directions_car_outlined,
        'Tipo',
        _nombreTipo(),
      ),
      if (_tieneValor(vehiculo.marca))
        _filaInformacion(
          Icons.directions_car_filled_outlined,
          'Marca',
          vehiculo.marca!,
        ),
      if (_tieneValor(vehiculo.modelo))
        _filaInformacion(
          Icons.car_repair_outlined,
          'Modelo',
          vehiculo.modelo!,
        ),
      if (vehiculo.anio != null)
        _filaInformacion(
          Icons.calendar_today_outlined,
          'Año',
          '${vehiculo.anio}',
        ),
      if (_tieneValor(vehiculo.tipoCombustible))
        _filaInformacion(
          Icons.local_gas_station_outlined,
          'Combustible',
          vehiculo.tipoCombustible!,
        ),
      if (vehiculo.kilometrajeActual != null)
        _filaInformacion(
          Icons.speed_outlined,
          'Kilometraje',
          '${_conMiles(vehiculo.kilometrajeActual!)} km',
        ),
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _surfaceColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: _textMuted),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Información del vehículo',
                          style: TextStyle(
                            color: _textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: _textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...filas,
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filaInformacion(IconData icono, String etiqueta, String valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(icono, color: _textMuted, size: 20),
          const SizedBox(width: 12),
          Text(
            etiqueta,
            style: const TextStyle(color: _textMuted, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _textMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
