import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/beneficio_model.dart';
import '../../data/services/storage_service.dart';

IconData iconoCategoriaBeneficio(CategoriaBeneficio? categoria) {
  switch (categoria) {
    case CategoriaBeneficio.combustible:
      return Icons.local_gas_station_outlined;
    case CategoriaBeneficio.talleres:
      return Icons.build_circle_outlined;
    case CategoriaBeneficio.mantenciones:
      return Icons.handyman_outlined;
    case CategoriaBeneficio.estacionamientos:
      return Icons.local_parking_outlined;
    case CategoriaBeneficio.lavado:
      return Icons.local_car_wash_outlined;
    case CategoriaBeneficio.neumaticos:
      return Icons.tire_repair_outlined;
    case CategoriaBeneficio.seguros:
      return Icons.shield_outlined;
    case CategoriaBeneficio.accesorios:
      return Icons.shopping_bag_outlined;
    case CategoriaBeneficio.otros:
      return Icons.category_outlined;
    case null:
      return Icons.card_giftcard_outlined;
  }
}

/// Imagen de un beneficio. `imagen_path` es la ruta de la imagen que subió el
/// administrador (beneficios/{archivo}) y se muestra con una URL firmada que
/// pide la Edge Function, igual que la foto de un vehículo; también acepta una
/// URL https. Sin imagen, mientras carga o si falla, se ve el ícono de la
/// categoría.
class ImagenBeneficio extends StatefulWidget {
  final BeneficioModel beneficio;
  final BoxFit fit;

  const ImagenBeneficio({
    super.key,
    required this.beneficio,
    this.fit = BoxFit.cover,
  });

  @override
  State<ImagenBeneficio> createState() => _ImagenBeneficioState();
}

class _ImagenBeneficioState extends State<ImagenBeneficio> {
  final StorageService _storage = StorageService();
  Future<String>? _urlFirmada;

  String? get _path => widget.beneficio.imagenPath;
  bool get _esUrl => _path != null && _path!.startsWith('https://');
  bool get _esRutaSubida =>
      _path != null && _path!.startsWith('beneficios/') && StorageService.configurado;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void didUpdateWidget(ImagenBeneficio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beneficio.imagenPath != widget.beneficio.imagenPath) {
      _preparar();
    }
  }

  void _preparar() {
    _urlFirmada = _esRutaSubida ? _storage.obtenerUrlFirmada(_path!) : null;
  }

  Widget _respaldo() {
    return Container(
      color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Icon(
        iconoCategoriaBeneficio(widget.beneficio.categoria),
        color: const Color(0xFF1E3A8A),
        size: 36,
      ),
    );
  }

  Widget _imagen(String url, String cacheKey) {
    return CachedNetworkImage(
      imageUrl: url,
      // La URL firmada cambia en cada petición: se cachea por ruta.
      cacheKey: cacheKey,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, _) => _respaldo(),
      errorWidget: (_, _, _) => _respaldo(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_esUrl) return _imagen(_path!, _path!);

    final futuro = _urlFirmada;
    if (futuro == null) return _respaldo();
    return FutureBuilder<String>(
      future: futuro,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return _respaldo();
        return _imagen(url, _path!);
      },
    );
  }
}
