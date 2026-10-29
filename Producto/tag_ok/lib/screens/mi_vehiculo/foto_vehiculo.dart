import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/services/storage_service.dart';

/// Imagen de un vehículo: la foto que subió el usuario o, si no tiene (o no se
/// pudo cargar), la imagen predeterminada según su tipo.
///
/// `foto_path` es una ruta dentro del bucket privado, no una URL: se pide una
/// URL firmada a la Edge Function al mostrarla (igual que los documentos).
/// Mientras carga, o si falla, se ve la imagen predeterminada.
class FotoVehiculo extends StatefulWidget {
  final String? fotoPath;
  final String assetPredeterminado;

  /// Margen alrededor de la imagen. Se aplica igual a la ilustración
  /// predeterminada y a la foto del usuario, y ambas se ajustan completas
  /// dentro del marco (sin recortarse).
  final EdgeInsets paddingPredeterminado;

  /// Cómo se ajusta la imagen al marco, tanto la foto del usuario como el
  /// dibujo predeterminado. `contain` (por defecto) la muestra entera; `cover`
  /// llena el marco y recorta lo que sobre.
  final BoxFit fit;

  const FotoVehiculo({
    super.key,
    required this.fotoPath,
    required this.assetPredeterminado,
    this.paddingPredeterminado = EdgeInsets.zero,
    this.fit = BoxFit.contain,
  });

  @override
  State<FotoVehiculo> createState() => _FotoVehiculoState();
}

class _FotoVehiculoState extends State<FotoVehiculo> {
  final StorageService _storage = StorageService();
  Future<String>? _urlFuture;

  bool get _tieneFoto =>
      StorageService.configurado &&
      widget.fotoPath != null &&
      widget.fotoPath!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cargarUrl();
  }

  @override
  void didUpdateWidget(FotoVehiculo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fotoPath != widget.fotoPath) {
      _cargarUrl();
    }
  }

  void _cargarUrl() {
    _urlFuture =
        _tieneFoto ? _storage.obtenerUrlFirmada(widget.fotoPath!.trim()) : null;
  }

  Widget _predeterminada() {
    return Padding(
      padding: widget.paddingPredeterminado,
      child: Image.asset(
        widget.assetPredeterminado,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.directions_car_outlined,
            color: Color(0xFF1E3A8A),
            size: 70,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final futuro = _urlFuture;
    if (futuro == null) return _predeterminada();

    return FutureBuilder<String>(
      future: futuro,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return _predeterminada();

        return Padding(
          padding: widget.paddingPredeterminado,
          child: CachedNetworkImage(
            imageUrl: url,
            // La URL firmada cambia en cada petición: se cachea por ruta.
            cacheKey: widget.fotoPath!.trim(),
            // Por defecto contain: la foto se ve entera y se achica según el
            // espacio, igual que la imagen predeterminada.
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, _) => _predeterminada(),
            errorWidget: (_, _, _) => _predeterminada(),
          ),
        );
      },
    );
  }
}
