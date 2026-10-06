import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/vehiculo_model.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/vehiculo_service.dart';
import 'foto_vehiculo.dart';

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

  // Foto nueva elegida por el usuario (aún sin subir).
  Uint8List? _fotoBytes;
  String _fotoMime = 'image/jpeg';

  // El usuario pidió volver a la imagen predeterminada (se aplica al guardar).
  bool _quitarFoto = false;

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

  /// Todos los datos principales son obligatorios (al registrar y al editar);
  /// solo la personalización (alias y kilometraje) es opcional.
  String? _validarDatosPrincipales() {
    if (_marcaCtrl.text.trim().isEmpty) {
      return 'La marca es obligatoria.';
    }

    if (_modeloCtrl.text.trim().isEmpty) {
      return 'El modelo es obligatorio.';
    }

    final anio = int.tryParse(_anioCtrl.text.trim());
    if (_anioCtrl.text.trim().isEmpty) {
      return 'El año es obligatorio.';
    }
    if (anio == null ||
        anio < 1900 ||
        anio > DateTime.now().year + 1) {
      return 'Ingresa un año válido.';
    }

    if (_tipoCombustibleCtrl.text.trim().isEmpty) {
      return 'El tipo de combustible es obligatorio.';
    }

    return null;
  }

  // ------------------------------------------------------------
  // FOTO DEL VEHÍCULO
  // ------------------------------------------------------------

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: textMain),
                title: const Text(
                  'Tomar foto',
                  style: TextStyle(color: textMain),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: textMain),
                title: const Text(
                  'Elegir de la galería',
                  style: TextStyle(color: textMain),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (origen == null) return;

    try {
      final foto = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (foto == null) return;

      final bytes = await foto.readAsBytes();
      if (!mounted) return;

      setState(() {
        _fotoBytes = bytes;
        _quitarFoto = false;
        _fotoMime = foto.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la imagen. Intenta con otra.';
      });
    }
  }

  /// Sube la foto elegida al bucket y devuelve su path.
  Future<String> _subirFoto(String vehiculoId) {
    final storage = StorageService();
    return storage.subirArchivo(
      path: storage.pathFotoVehiculo(
        vehiculoId: vehiculoId,
        extension: _fotoMime == 'image/png' ? 'png' : 'jpg',
      ),
      bytes: _fotoBytes!,
      contentType: _fotoMime,
    );
  }

  /// Vista previa de la foto (la nueva, la ya guardada o la predeterminada) y
  /// botones para agregarla, cambiarla o descartar la elegida.
  Widget _bloqueFoto() {
    final fotoGuardada = _quitarFoto ? null : widget.vehiculo?.fotoPath;
    final tieneFotoGuardada =
        fotoGuardada != null && fotoGuardada.trim().isNotEmpty;
    final hayFoto = _fotoBytes != null || tieneFotoGuardada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: _fotoBytes != null
              ? Image.memory(
                  _fotoBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : FotoVehiculo(
                  fotoPath: fotoGuardada,
                  assetPredeterminado: _imagenTipo(_tipoVehiculoSel),
                  paddingPredeterminado: const EdgeInsets.all(20),
                ),
        ),
        if (_quitarFoto) ...[
          const SizedBox(height: 8),
          const Text(
            'Se quitará tu imagen y se usará la predeterminada al guardar.',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _guardando ? null : _elegirFoto,
                  icon: Icon(
                    hayFoto
                        ? Icons.edit_outlined
                        : Icons.add_a_photo_outlined,
                  ),
                  label: Text(
                    hayFoto
                        ? 'Cambiar imagen del vehículo'
                        : 'Agregar imagen del vehículo',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textMain,
                    side: const BorderSide(color: Color(0xFF475569)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            if (_fotoBytes != null) ...[
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Descartar imagen elegida',
                onPressed: _guardando
                    ? null
                    : () => setState(() => _fotoBytes = null),
                icon: const Icon(
                  Icons.close,
                  color: textMuted,
                ),
              ),
            ] else if (tieneFotoGuardada) ...[
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Quitar imagen',
                onPressed: _guardando
                    ? null
                    : () => setState(() => _quitarFoto = true),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
              ),
            ] else if (_quitarFoto) ...[
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Deshacer',
                onPressed: _guardando
                    ? null
                    : () => setState(() => _quitarFoto = false),
                icon: const Icon(
                  Icons.undo,
                  color: textMuted,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Acepta puntos como separador de miles (160.000 o 160000). Devuelve null
  /// si el campo está vacío; usar [_kilometrajeValido] para distinguir un
  /// campo vacío de uno con texto inválido.
  int? _parseKilometraje() {
    final texto = _kilometrajeCtrl.text.trim().replaceAll('.', '');
    return texto.isEmpty ? null : int.tryParse(texto);
  }

  bool get _kilometrajeValido =>
      _kilometrajeCtrl.text.trim().isEmpty || _parseKilometraje() != null;

  Future<void> _guardar() async {
    if (_patenteCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'La patente es obligatoria.';
      });
      return;
    }

    final errorCampos = _validarDatosPrincipales();
    if (errorCampos != null) {
      setState(() {
        _error = errorCampos;
      });
      return;
    }

    if (!_kilometrajeValido) {
      setState(() {
        _error = 'El kilometraje solo puede contener números '
            '(ej: 160000 o 160.000).';
      });
      return;
    }

    final kilometraje = _parseKilometraje();
    final messenger = ScaffoldMessenger.of(context);

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
        // La foto se sube primero: si falla, no se guarda nada y el usuario
        // no pierde lo que escribió.
        String? nuevaFotoPath;
        if (_fotoBytes != null) {
          if (!StorageService.configurado) {
            throw StorageException(
              'El almacenamiento de imágenes no está configurado.',
            );
          }
          nuevaFotoPath = await _subirFoto(widget.vehiculo!.id);
        }

        await _vehiculoService.actualizarVehiculo(
          widget.vehiculo!.id,
          fotoPath: nuevaFotoPath,
          quitarFoto: _quitarFoto && nuevaFotoPath == null,
          marca: _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim(),
          anio: int.tryParse(_anioCtrl.text.trim()),
          tipoCombustible: _tipoCombustibleCtrl.text.trim(),
          kilometrajeActual: kilometraje,
          alias: _aliasCtrl.text.trim().isEmpty
              ? null
              : _aliasCtrl.text.trim(),
        );

        // Ya con el vehículo actualizado, se borra la foto anterior (si falla
        // solo queda un archivo huérfano; no afecta al usuario).
        final fotoAnterior = widget.vehiculo!.fotoPath;
        if ((nuevaFotoPath != null || _quitarFoto) &&
            fotoAnterior != null &&
            fotoAnterior.trim().isNotEmpty) {
          try {
            await StorageService().eliminarArchivo(fotoAnterior.trim());
          } catch (e) {
            debugPrint('No se pudo eliminar la foto anterior: $e');
          }
        }
      } else {
        final vehiculoId = await _vehiculoService.registrarVehiculo(
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
          kilometrajeActual: kilometraje,
          alias: _aliasCtrl.text.trim().isEmpty
              ? null
              : _aliasCtrl.text.trim(),
        );

        // El vehículo ya está registrado: si la foto falla se avisa, pero no
        // se pierde el registro (se puede agregar después editándolo).
        if (_fotoBytes != null) {
          try {
            if (!StorageService.configurado) {
              throw StorageException(
                'El almacenamiento de imágenes no está configurado.',
              );
            }
            final fotoPath = await _subirFoto(vehiculoId);
            await _vehiculoService.actualizarVehiculo(
              vehiculoId,
              fotoPath: fotoPath,
            );
          } catch (e) {
            debugPrint('No se pudo subir la foto del vehículo: $e');
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Vehículo guardado, pero no se pudo subir la imagen. '
                  'Puedes agregarla editando el vehículo.',
                ),
              ),
            );
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on StorageException catch (e) {
      debugPrint('Error de almacenamiento: $e');
      setState(() {
        _guardando = false;
        _error = 'No se pudo subir la imagen. Revisa tu conexión e '
            'intenta nuevamente.';
      });
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
                  ? 'Actualiza la información de tu vehículo.'
                  : 'Ingresa los datos principales de tu vehículo.',
            ),

            if (_esEdicion) ...[
              _bloqueFoto(),
              const SizedBox(height: 18),
            ],

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

            TextField(
              controller: _marcaCtrl,
              style: const TextStyle(
                color: textMain,
              ),
              decoration: _decoracion(
                'Marca *',
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
                'Modelo *',
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
                'Año *',
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
                'Tipo de combustible *',
                hint: 'Ej: Gasolina',
                icon: Icons.local_gas_station_outlined,
              ),
            ),

            const SizedBox(height: 28),

            _tituloSeccion(
              'Personalización (opcional)',
              'Estos datos te ayudarán a identificar y controlar mejor tu vehículo.',
            ),

            TextField(
              controller: _aliasCtrl,
              style: const TextStyle(
                color: textMain,
              ),
              decoration: _decoracion(
                'Alias (opcional)',
                hint: 'Ej: Mi Auto',
                icon: Icons.sell_outlined,
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _kilometrajeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(
                color: textMain,
              ),
              decoration: _decoracion(
                'Kilometraje actual (opcional)',
                hint: 'Ej: 35000 o 35.000',
                icon: Icons.speed_outlined,
              ),
            ),

            if (!_esEdicion) ...[
              const SizedBox(height: 22),

              const Text(
                'Imagen del vehículo (opcional)',
                style: TextStyle(
                  color: textMain,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Sube una foto de tu vehículo. Si no, verás la imagen '
                'predeterminada según su tipo.',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              _bloqueFoto(),
            ],

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