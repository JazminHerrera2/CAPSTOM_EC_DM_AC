/// Reglas de dominio del Permiso de Circulación. Funciones puras: todo lo que
/// dependa de "hoy" lo recibe por parámetro para poder probarlo con fecha fija.

/// Casilla marcada en el comprobante del permiso (apartado "Total / Cuota 1 /
/// Cuota 2" al costado derecho). Dice cuánto está pagado:
/// - [total]: pagado completo.
/// - [cuota1]: solo la primera cuota; falta la segunda.
/// - [cuota2]: la segunda cuota marcada, es decir, ya pagó ambas.
enum FormaPagoPermiso {
  total('total', 'Total'),
  cuota1('cuota_1', 'Cuota 1'),
  cuota2('cuota_2', 'Cuota 2');

  const FormaPagoPermiso(this.valorFirestore, this.etiqueta);

  /// Valor que se guarda en Firestore (campo `forma_pago`).
  final String valorFirestore;

  /// Texto que ve el usuario.
  final String etiqueta;

  static FormaPagoPermiso? fromFirestore(String? valor) {
    return FormaPagoPermiso.values
        .where((f) => f.valorFirestore == valor)
        .firstOrNull;
  }
}

// Reglas de vencimiento. Se confirmarán con la fuente oficial: si cambian, se
// cambian solo acá.

/// Permiso pagado por completo (casilla Total o Cuota 2): vence el 31 de marzo
/// del año siguiente al de la emisión.
const int mesVencimientoPagado = 3;
const int diaVencimientoPagado = 31;
const int aniosSumadosPagado = 1;

/// Solo la primera cuota (casilla Cuota 1): vence el 31 de agosto del mismo
/// año de la emisión.
const int mesVencimientoPrimeraCuota = 8;
const int diaVencimientoPrimeraCuota = 31;

/// Fecha de vencimiento del permiso según la casilla marcada. El año se toma
/// de la fecha de emisión (leída del documento o estimada).
DateTime fechaVencimientoPermiso({
  required FormaPagoPermiso formaPago,
  required DateTime fechaEmision,
}) {
  switch (formaPago) {
    case FormaPagoPermiso.total:
    case FormaPagoPermiso.cuota2:
      return DateTime(
        fechaEmision.year + aniosSumadosPagado,
        mesVencimientoPagado,
        diaVencimientoPagado,
      );
    case FormaPagoPermiso.cuota1:
      return DateTime(
        fechaEmision.year,
        mesVencimientoPrimeraCuota,
        diaVencimientoPrimeraCuota,
      );
  }
}

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
