import 'package:flutter/material.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

import '../data/models/vehiculo_model.dart';

/// Selector de vehículo de Auditoría, igual al de Mantenciones, Combustible y
/// Estacionamientos: una fila de botones con la patente de cada vehículo
/// (centrados; desplazables hacia el lado si son muchos). Siempre hay un
/// vehículo elegido: no existe la opción "Todos".
class AuditoriaSelectorVehiculo extends StatelessWidget {
  final List<VehiculoModel> vehiculos;
  final String? patenteElegida;
  final ValueChanged<String> alElegir;

  /// Margen de la fila. Por defecto el mismo de los filtros de las demás
  /// pantallas; se puede achicar si el contenedor ya tiene su propio margen.
  final EdgeInsets padding;

  const AuditoriaSelectorVehiculo({
    super.key,
    required this.vehiculos,
    required this.patenteElegida,
    required this.alElegir,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    // Centrados cuando caben; si son muchos, se desplazan hacia el lado.
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: c.maxWidth - padding.horizontal,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < vehiculos.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _boton(vehiculos[i].patente),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _boton(String patente) {
    final activo = patenteElegida == patente;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadios.tarjeta),
      onTap: () => alElegir(patente),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? AppColors.primario : AppColors.superficie,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        ),
        child: Text(
          patente,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: activo ? AppColors.sobrePrimario : AppColors.textoSecundario,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
