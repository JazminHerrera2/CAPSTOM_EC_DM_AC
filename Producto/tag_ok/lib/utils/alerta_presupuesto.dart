import '../data/models/trip_history.dart';

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

/// Gasto del mes calendario de [ahora]: suma solo los viajes cuya fecha cae en
/// el mismo mes y año (en hora local). Es lo que se compara con el límite
/// mensual; antes se sumaban todos los viajes de la historia.
double gastoDelMes(Iterable<TripHistory> viajes, DateTime ahora) {
  final hoy = ahora.toLocal();
  var total = 0.0;
  for (final viaje in viajes) {
    final fecha = viaje.date.toLocal();
    if (fecha.year == hoy.year && fecha.month == hoy.month) {
      total += viaje.totalCost;
    }
  }
  return total;
}

/// Clave con la que se recuerda en `usuarios/{uid}.alertas_vistas` que el
/// [umbral] ya se avisó en el mes calendario de [ahora] (p. ej. `2026-10_75`).
/// Usa el mismo criterio de mes que [gastoDelMes]; el formato no cambia
/// (sin cero a la izquierda) para no invalidar las alertas ya guardadas.
String claveAlertaMensual(DateTime ahora, int umbral) {
  final hoy = ahora.toLocal();
  return '${hoy.year}-${hoy.month}_$umbral';
}
