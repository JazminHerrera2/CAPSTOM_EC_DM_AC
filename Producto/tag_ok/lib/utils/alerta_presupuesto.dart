/// Umbrales de alerta del presupuesto mensual, de mayor a menor.
const List<int> umbralesAlertaPresupuesto = [100, 90, 75, 50];

/// Umbral de alerta (50, 75, 90 o 100) que corresponde al gasto [total] frente
/// al [limite] mensual, o `null` si no corresponde ninguna alerta.
///
/// Función pura: no muestra nada ni toca Firestore. La pantalla del mapa solo
/// se encarga del diálogo y de no repetir una alerta ya vista.
///
/// Un [limite] menor o igual a 0 (o no numérico) significa "sin límite
/// configurado": no hay alerta. Antes se dividía por cero y, con gasto mayor
/// que 0, se disparaba siempre la alerta del 100 %.
int? umbralDeAlerta(double total, double limite) {
  if (!(limite > 0) || limite.isInfinite) return null;
  final porcentaje = (total / limite) * 100;
  for (final umbral in umbralesAlertaPresupuesto) {
    if (porcentaje >= umbral) return umbral;
  }
  return null;
}
