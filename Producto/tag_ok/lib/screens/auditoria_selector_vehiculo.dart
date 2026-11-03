import 'package:flutter/material.dart';

import '../data/models/vehiculo_model.dart';

/// Selector de vehículo de Auditoría, igual al de Mantenciones: una fila de
/// botones con la patente de cada vehículo (desplazable hacia el lado). A
/// diferencia de Mantenciones lleva además "Todos" al comienzo, porque
/// Auditoría también muestra los viajes de todos los vehículos juntos.
/// [patenteElegida] es `null` para "Todos".
class AuditoriaSelectorVehiculo extends StatelessWidget {
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _primary = Color(0xFF1E3A8A);

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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _boton('Todos', patenteElegida == null, () => alElegir(null)),
          for (final v in vehiculos) ...[
            const SizedBox(width: 8),
            _boton(v.patente, patenteElegida == v.patente,
                () => alElegir(v.patente)),
          ],
        ],
      ),
    );
  }

  Widget _boton(String texto, bool activo, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? _primary : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? _primary : Colors.transparent),
        ),
        child: Text(
          texto,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: activo ? Colors.white : _textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
