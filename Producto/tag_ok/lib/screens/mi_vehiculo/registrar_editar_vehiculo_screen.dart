import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/vehiculo_service.dart';

/// CU1 (registrar, [vehiculo] == null) y CU2 (modificar km/alias/foto,
/// [vehiculo] != null) — un solo formulario reusado en ambos modos, tal
/// como quedó definido en el plan de Sprint 2.
class RegistrarEditarVehiculoScreen extends StatefulWidget {
  final VehiculoModel? vehiculo;

  const RegistrarEditarVehiculoScreen({super.key, this.vehiculo});

  @override
  State<RegistrarEditarVehiculoScreen> createState() =>
      _RegistrarEditarVehiculoScreenState();
}

class _RegistrarEditarVehiculoScreenState
    extends State<RegistrarEditarVehiculoScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color surfaceColor = const Color(0xFF1E293B);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF4F46E5);

  final VehiculoService _vehiculoService = VehiculoService();
  final StorageService _storageService = StorageService();

  final _patenteCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  // Mismas opciones que la categoría TAG de vehiculos_screen.dart
  // (AUTO/CAMIONETA/MOTO), para que ambos módulos usen exactamente el
  // mismo contenido.
  static const List<String> _tiposVehiculo = ['AUTO', 'CAMIONETA', 'MOTO'];
  String _tipoVehiculoSel = 'AUTO';
  final _tipoCombustibleCtrl = TextEditingController();
  final _kilometrajeCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();

  Uint8List? _fotoBytes;
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

  Future<void> _elegirFoto() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (imagen == null) return;
    final bytes = await imagen.readAsBytes();
    setState(() => _fotoBytes = bytes);
  }

  Future<void> _guardar() async {
    if (_patenteCtrl.text.trim().isEmpty) {
      setState(() => _error = 'La patente es obligatoria.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Debes iniciar sesión.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        String? fotoPath;
        if (_fotoBytes != null) {
          fotoPath = await _storageService.subirArchivo(
            path: 'vehiculos/${widget.vehiculo!.id}/foto.jpg',
            bytes: _fotoBytes!,
            contentType: 'image/jpeg',
          );
        }
        await _vehiculoService.actualizarVehiculo(
          widget.vehiculo!.id,
          kilometrajeActual: int.tryParse(_kilometrajeCtrl.text.trim()),
          alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
          fotoPath: fotoPath,
        );
      } else {
        await _vehiculoService.registrarVehiculo(
          usuarioId: user.uid,
          patente: _patenteCtrl.text.trim().toUpperCase(),
          marca: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim().isEmpty ? null : _modeloCtrl.text.trim(),
          anio: int.tryParse(_anioCtrl.text.trim()),
          tipoVehiculo: _tipoVehiculoSel,
          tipoCombustible: _tipoCombustibleCtrl.text.trim().isEmpty
              ? null
              : _tipoCombustibleCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textMuted),
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
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
          _esEdicion ? 'Modificar vehículo' : 'Registrar vehículo',
          style: TextStyle(color: textMain),
        ),
        iconTheme: IconThemeData(color: textMain),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _patenteCtrl,
              enabled: !_esEdicion,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: textMain),
              decoration: _decoracion('Patente'),
            ),
            const SizedBox(height: 14),
            if (!_esEdicion) ...[
              TextField(
                controller: _marcaCtrl,
                style: TextStyle(color: textMain),
                decoration: _decoracion('Marca'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _modeloCtrl,
                style: TextStyle(color: textMain),
                decoration: _decoracion('Modelo'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _anioCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: _decoracion('Año'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _tipoVehiculoSel,
                dropdownColor: surfaceColor,
                style: TextStyle(color: textMain),
                decoration: _decoracion('Tipo de vehículo'),
                items: _tiposVehiculo
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _tipoVehiculoSel = value);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _tipoCombustibleCtrl,
                style: TextStyle(color: textMain),
                decoration: _decoracion('Tipo de combustible'),
              ),
            ],
            if (_esEdicion) ...[
              TextField(
                controller: _kilometrajeCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textMain),
                decoration: _decoracion('Kilometraje actual'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _aliasCtrl,
                style: TextStyle(color: textMain),
                decoration: _decoracion('Alias (ej: Mi Auto)'),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _elegirFoto,
                icon: Icon(Icons.photo_camera_outlined, color: textMain),
                label: Text(
                  _fotoBytes != null ? 'Foto seleccionada' : 'Agregar fotografía (opcional)',
                  style: TextStyle(color: textMain),
                ),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _esEdicion ? 'Guardar cambios' : 'Registrar',
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
