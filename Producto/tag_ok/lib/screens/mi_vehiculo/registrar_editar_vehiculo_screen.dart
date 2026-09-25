import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/vehiculo_model.dart';
import '../../data/services/vehiculo_service.dart';

class RegistrarEditarVehiculoScreen extends StatefulWidget {
  final VehiculoModel? vehiculo;

  const RegistrarEditarVehiculoScreen({
    super.key,
    this.vehiculo,
  });

  @override
  State<RegistrarEditarVehiculoScreen> createState() =>
      _RegistrarEditarVehiculoScreenState();
}

class _RegistrarEditarVehiculoScreenState
    extends State<RegistrarEditarVehiculoScreen> {
  // COLORES
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF27364D);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color primaryColor = Color(0xFF4F46E5);

  final VehiculoService _vehiculoService = VehiculoService();

  // CONTROLADORES
  final _patenteCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _tipoCombustibleCtrl = TextEditingController();
  final _kilometrajeCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();

  static const List<String> _tiposVehiculo = [
    'AUTO',
    'CAMIONETA',
    'MOTO',
  ];

  String _tipoVehiculoSel = 'AUTO';

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.vehiculo != null;

  @override
  void initState() {
    super.initState();

    final v = widget.vehiculo;

    if (v != null) {
      _patenteCtrl.text = v.patente;
      _marcaCtrl.text = v.marca ?? '';
      _modeloCtrl.text = v.modelo ?? '';
      _anioCtrl.text = v.anio?.toString() ?? '';

      _tipoVehiculoSel = _tiposVehiculo.contains(v.tipoVehiculo)
          ? v.tipoVehiculo!
          : 'AUTO';

      _tipoCombustibleCtrl.text = v.tipoCombustible ?? '';
      _kilometrajeCtrl.text = v.kilometrajeActual?.toString() ?? '';
      _aliasCtrl.text = v.alias ?? '';
    }
  }

  @override
  void dispose() {
    _patenteCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _tipoCombustibleCtrl.dispose();
    _kilometrajeCtrl.dispose();
    _aliasCtrl.dispose();

    super.dispose();
  }

  String _imagenTipo(String tipo) {
    switch (tipo) {
      case 'CAMIONETA':
        return 'assets/imagenes/vehiculos/camion.png';

      case 'MOTO':
        return 'assets/imagenes/vehiculos/moto.png';

      case 'AUTO':
      default:
        return 'assets/imagenes/vehiculos/auto.png';
    }
  }

  String _nombreTipo(String tipo) {
    switch (tipo) {
      case 'CAMIONETA':
        return 'Camioneta';
      case 'MOTO':
        return 'Moto';
      default:
        return 'Auto';
    }
  }

  Future<void> _guardar() async {
    if (_patenteCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'La patente es obligatoria.';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _error = 'Debes iniciar sesión.';
      });
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        await _vehiculoService.actualizarVehiculo(
          widget.vehiculo!.id,
          kilometrajeActual:
              int.tryParse(_kilometrajeCtrl.text.trim()),
          alias: _aliasCtrl.text.trim().isEmpty
              ? null
              : _aliasCtrl.text.trim(),
        );
      } else {
        await _vehiculoService.registrarVehiculo(
          usuarioId: user.uid,
          patente: _patenteCtrl.text.trim().toUpperCase(),
          marca: _marcaCtrl.text.trim().isEmpty
              ? null
              : _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim().isEmpty
              ? null
              : _modeloCtrl.text.trim(),
          anio: int.tryParse(_anioCtrl.text.trim()),
          tipoVehiculo: _tipoVehiculoSel,
          tipoCombustible:
              _tipoCombustibleCtrl.text.trim().isEmpty
                  ? null
                  : _tipoCombustibleCtrl.text.trim(),
          kilometrajeActual:
              int.tryParse(_kilometrajeCtrl.text.trim()),
          alias: _aliasCtrl.text.trim().isEmpty
              ? null
              : _aliasCtrl.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar el vehículo.';
      });
    }
  }

  InputDecoration _decoracion(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: textMuted,
      ),
      hintStyle: TextStyle(
        color: textMuted.withOpacity(0.55),
      ),
      prefixIcon: icon != null
          ? Icon(
              icon,
              color: textMuted,
              size: 21,
            )
          : null,
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF334155),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _tituloSeccion(
    String titulo,
    String descripcion,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            descripcion,
            style: const TextStyle(
              color: textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorTipoVehiculo() {
    return Row(
      children: _tiposVehiculo.map((tipo) {
        final seleccionado = _tipoVehiculoSel == tipo;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: tipo != _tiposVehiculo.last ? 10 : 0,
            ),
            child: GestureDetector(
              onTap: _esEdicion
                  ? null
                  : () {
                      setState(() {
                        _tipoVehiculoSel = tipo;
                      });
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 135,
                decoration: BoxDecoration(
                  color: seleccionado
                      ? primaryColor.withOpacity(0.14)
                      : surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: seleccionado
                        ? primaryColor
                        : const Color(0xFF334155),
                    width: seleccionado ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          10,
                          10,
                          10,
                          0,
                        ),
                        child: Image.asset(
                          _imagenTipo(tipo),
                          fit: BoxFit.contain,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const Icon(
                              Icons.directions_car_outlined,
                              color: textMuted,
                              size: 42,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (seleccionado) ...[
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          _nombreTipo(tipo),
                          style: TextStyle(
                            color: seleccionado
                                ? textMain
                                : textMuted,
                            fontWeight: seleccionado
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back,
            color: textMain,
          ),
        ),
        title: Text(
          _esEdicion
              ? 'Editar vehículo'
              : 'Agregar vehículo',
          style: const TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            35,
          ),
          children: [
            if (!_esEdicion) ...[
              _tituloSeccion(
                'Tipo de vehículo',
                'Selecciona el vehículo que quieres agregar.',
              ),

              _selectorTipoVehiculo(),

              const SizedBox(height: 28),
            ],

            _tituloSeccion(
              'Información del vehículo',
              _esEdicion
                  ? 'Actualiza la información personal de tu vehículo.'
                  : 'Ingresa los datos principales de tu vehículo.',
            ),

            TextField(
              controller: _patenteCtrl,
              enabled: !_esEdicion,
              textCapitalization:
                  TextCapitalization.characters,
              style: const TextStyle(
                color: textMain,
              ),
              decoration: _decoracion(
                'Patente *',
                hint: 'Ej: ABCD12',
                icon: Icons.badge_outlined,
              ),
            ),

            const SizedBox(height: 14),

            if (!_esEdicion) ...[
              TextField(
                controller: _marcaCtrl,
                style: const TextStyle(
                  color: textMain,
                ),
                decoration: _decoracion(
                  'Marca',
                  hint: 'Ej: Toyota',
                  icon: Icons.directions_car_outlined,
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _modeloCtrl,
                style: const TextStyle(
                  color: textMain,
                ),
                decoration: _decoracion(
                  'Modelo',
                  hint: 'Ej: Corolla',
                  icon: Icons.car_repair_outlined,
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _anioCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: textMain,
                ),
                decoration: _decoracion(
                  'Año',
                  hint: 'Ej: 2022',
                  icon: Icons.calendar_today_outlined,
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _tipoCombustibleCtrl,
                style: const TextStyle(
                  color: textMain,
                ),
                decoration: _decoracion(
                  'Tipo de combustible',
                  hint: 'Ej: Gasolina',
                  icon: Icons.local_gas_station_outlined,
                ),
              ),

              const SizedBox(height: 28),
            ],

            _tituloSeccion(
              'Personalización',
              'Estos datos te ayudarán a identificar y controlar mejor tu vehículo.',
            ),

            TextField(
              controller: _aliasCtrl,
              style: const TextStyle(
                color: textMain,
              ),
              decoration: _decoracion(
                'Alias',
                hint: 'Ej: Mi Auto',
                icon: Icons.sell_outlined,
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _kilometrajeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: textMain,
              ),
              decoration: _decoracion(
                'Kilometraje actual',
                hint: 'Ej: 35000',
                icon: Icons.speed_outlined,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        Colors.redAccent.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor:
                      primaryColor.withOpacity(0.45),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
                child: _guardando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            _esEdicion
                                ? Icons.save_outlined
                                : Icons.add_circle_outline,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            _esEdicion
                                ? 'Guardar cambios'
                                : 'Agregar vehículo',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            if (!_esEdicion) ...[
              const SizedBox(height: 14),

              const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: textMuted,
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Podrás agregar documentos después de registrar el vehículo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}