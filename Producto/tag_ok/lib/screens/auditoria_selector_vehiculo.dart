import 'package:flutter/material.dart';

import '../data/models/vehiculo_model.dart';
import 'mi_vehiculo/foto_vehiculo.dart';

/// Carrusel de vehículos de Auditoría: el mismo del Inicio (foto, nombre y
/// patente, con flechas y puntos), más una primera tarjeta "Todos los
/// vehículos". Al deslizar o tocar una flecha se elige el vehículo cuyos viajes
/// se muestran. [patenteElegida] es `null` para "Todos".
class AuditoriaSelectorVehiculo extends StatefulWidget {
  final List<VehiculoModel> vehiculos;
  final String? patenteElegida;
  final ValueChanged<String?> alElegir;

  const AuditoriaSelectorVehiculo({
    super.key,
    required this.vehiculos,
    required this.patenteElegida,
    required this.alElegir,
  });

  @override
  State<AuditoriaSelectorVehiculo> createState() =>
      _AuditoriaSelectorVehiculoState();
}

class _AuditoriaSelectorVehiculoState extends State<AuditoriaSelectorVehiculo> {
  static const double _anchoTarjeta = 0.8;
  static const double _alto = 84;
  static const Color _bg = Color(0xFFF1F5F9);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _primary = Color(0xFF1E3A8A);

  late final PageController _paginas =
      PageController(viewportFraction: _anchoTarjeta, initialPage: _indice);

  /// 0 = Todos; 1..n = vehículos.
  int get _indice {
    final p = widget.patenteElegida;
    if (p == null) return 0;
    final i = widget.vehiculos.indexWhere((v) => v.patente == p);
    return i < 0 ? 0 : i + 1;
  }

  @override
  void didUpdateWidget(AuditoriaSelectorVehiculo old) {
    super.didUpdateWidget(old);
    // "Limpiar" u otro cambio externo: llevar el carrusel a la tarjeta elegida.
    if (_paginas.hasClients && (_paginas.page?.round() ?? 0) != _indice) {
      _paginas.animateToPage(_indice,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _irA(int i) => _paginas.animateToPage(i,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final total = widget.vehiculos.length + 1;
    final actual = _indice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          SizedBox(
            height: _alto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: _paginas,
                  padEnds: false,
                  itemCount: total,
                  onPageChanged: (i) => widget.alElegir(
                      i == 0 ? null : widget.vehiculos[i - 1].patente),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: i == 0
                        ? _tarjetaTodos()
                        : _tarjetaVehiculo(widget.vehiculos[i - 1]),
                  ),
                ),
                if (actual > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _flecha(Icons.chevron_left, () => _irA(actual - 1)),
                  ),
                if (actual < total - 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _flecha(Icons.chevron_right, () => _irA(actual + 1)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == actual ? _primary : const Color(0xFFCBD5E1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flecha(IconData icono, VoidCallback onTap) => Material(
        color: _bg.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icono, color: _textMain, size: 22),
          ),
        ),
      );

  Widget _marco(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _tarjetaTodos() => _marco(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: _bg,
              child: Icon(Icons.directions_car, color: _primary, size: 30),
            ),
            const SizedBox(width: 14),
            const Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Todos los vehículos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  Text('Desliza para elegir uno',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  String _imagenPorDefecto(VehiculoModel v) {
    final tipo = (v.tipoVehiculo ?? '').toUpperCase().trim();
    if (tipo == 'MOTO') return 'assets/imagenes/vehiculos/moto.png';
    if (tipo == 'CAMIONETA' || tipo == 'CAMION' || tipo == 'CAMIÓN') {
      return 'assets/imagenes/vehiculos/camion.png';
    }
    return 'assets/imagenes/vehiculos/auto.png';
  }

  Widget _tarjetaVehiculo(VehiculoModel v) {
    final alias = (v.alias ?? '').trim();
    final marcaModelo = [v.marca, v.modelo]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' ');
    final titulo = alias.isNotEmpty
        ? alias
        : (marcaModelo.isNotEmpty ? marcaModelo : 'Mi vehículo');
    final detalle = [v.patente, if (v.anio != null) '${v.anio}'].join(' · ');
    return _marco(
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: Container(
              width: 64,
              height: 64,
              color: _bg,
              child: FotoVehiculo(
                fotoPath: v.fotoPath,
                assetPredeterminado: _imagenPorDefecto(v),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text(detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
