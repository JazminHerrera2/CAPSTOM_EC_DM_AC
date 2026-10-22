/// Reglas de dominio del Permiso de Circulación. Funciones puras: todo lo que
/// dependa de "hoy" lo recibe por parámetro para poder probarlo con fecha fija.

/// Resultado de [resolverFechaEmision].
typedef FechaEmisionResuelta = ({DateTime fecha, bool estimada});

/// Fecha de emisión del permiso.
///
/// - Si el documento trae la fecha completa ([fechaLeida]), se usa tal cual.
/// - Si solo trae el año ([anioLeido], ej. 2026), se completa con la fecha en
///   que se ingresó el documento ([fechaIngreso], ej. 22/10/2026) y se marca
///   como `estimada`, para distinguirla de una fecha leída del documento.
/// - Si no trae ni fecha ni año, devuelve null: no se inventa nada.
FechaEmisionResuelta? resolverFechaEmision({
  DateTime? fechaLeida,
  int? anioLeido,
  required DateTime fechaIngreso,
}) {
  if (fechaLeida != null) return (fecha: fechaLeida, estimada: false);
  if (anioLeido == null) return null;
  return (
    fecha: DateTime(fechaIngreso.year, fechaIngreso.month, fechaIngreso.day),
    estimada: true,
  );
}
