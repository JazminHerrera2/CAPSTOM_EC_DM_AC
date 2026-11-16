import 'package:flutter/material.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

import '../data/models/vehiculo_model.dart';

/// Selector de vehículo de Auditoría, igual al de Mantenciones, Combustible y
/// Estacionamientos: una fila de botones con la patente de cada vehículo
/// (desplazable hacia el lado). Siempre hay un vehículo elegido: no existe la
/// opción "Todos".
class AuditoriaSelectorVehiculo extends StatelessWidget {
  final List<VehiculoModel> vehiculos;
  final String? patenteElegida;
  final ValueChanged<String> alElegir;

  /// Margen de la fila. Por defecto el mismo de los filtros de las demás
  /// pantallas; se puede achicar si el contenedor ya tiene su propio margen.
  final EdgeInsetsGeometry padding;

  const AuditoriaSelectorVehiculo({
    super.key,
    required this.vehiculos,
    required this.patenteElegida,
    required this.alElegir,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final v in vehiculos) ...[
            InkWell(
              borderRadius: BorderRadius.circular(AppRadios.tarjeta),
              onTap: () => alElegir(v.patente),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: patenteElegida == v.patente
                      ? AppColors.primario
                      : AppColors.superficie,
                  borderRadius: BorderRadius.circular(AppRadios.tarjeta),
                ),
                child: Text(
                  v.patente,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: patenteElegida == v.patente
                        ? Colors.white
                        : AppColors.textoSecundario,
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
}
