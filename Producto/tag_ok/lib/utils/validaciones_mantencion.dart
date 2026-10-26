import '../data/models/mantencion_model.dart';
import '../data/models/tipo_mantencion.dart';

/// Validaciones del registro de mantenciones. Funciones puras: lo que depende
/// de "hoy" o de las mantenciones ya guardadas se recibe por parámetro, así se
/// prueban con datos fijos. Las fechas se comparan por día calendario.

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

// ---------------------------------------------------------------- fecha

enum EstadoFechaMantencion {
  /// Sin fecha: es obligatoria.
  vacia,

  /// Posterior a hoy: se bloquea.
  futura,

  /// De hace más de 12 meses: se advierte, no se bloquea.
  antigua,
  ok,
}

EstadoFechaMantencion estadoFechaMantencion(DateTime? fecha, DateTime hoy) {
  if (fecha == null) return EstadoFechaMantencion.vacia;
  final dia = _dia(fecha);
  final hoyDia = _dia(hoy);
  if (dia.isAfter(hoyDia)) return EstadoFechaMantencion.futura;
  final limite = DateTime(hoyDia.year - 1, hoyDia.month, hoyDia.day);
  if (dia.isBefore(limite)) return EstadoFechaMantencion.antigua;
  return EstadoFechaMantencion.ok;
}

String mensajeFechaAntigua(DateTime fecha) =>
    'Este documento es de ${fecha.year}, ¿es correcto?';

// ---------------------------------------------------------- kilometraje

/// Una mantención anterior del vehículo con más kilometraje que la nueva.
typedef KilometrajeAnterior = ({int km, DateTime fecha});

/// Si [km] es menor al de una mantención **anterior o del mismo día** del
/// vehículo, devuelve la de mayor kilometraje (para avisar). Null si no hay
/// problema. Solo se miran las realizadas con fecha y kilometraje.
KilometrajeAnterior? kilometrajeMenorAlAnterior({
  required int km,
  required DateTime fecha,
  required Iterable<MantencionModel> existentes,
}) {
  final dia = _dia(fecha);
  KilometrajeAnterior? mayor;
  for (final m in existentes) {
    final f = m.fecha;
    final k = m.kilometraje;
    if (m.estado != EstadoMantencion.realizada || f == null || k == null) {
      continue;
    }
    if (_dia(f).isAfter(dia)) continue;
    if (mayor == null || k > mayor.km) mayor = (km: k, fecha: f);
  }
  return (mayor != null && km < mayor.km) ? mayor : null;
}

/// Último kilometraje conocido del vehículo: el mayor entre el del vehículo y
/// el de sus mantenciones realizadas. Se ofrece como sugerencia, nunca se
/// escribe solo.
int? kilometrajeSugerido({
  int? kmVehiculo,
  required Iterable<MantencionModel> existentes,
}) {
  int? mayor = kmVehiculo;
  for (final m in existentes) {
    final k = m.kilometraje;
    if (m.estado != EstadoMantencion.realizada || k == null) continue;
    if (mayor == null || k > mayor) mayor = k;
  }
  return mayor;
}

// ---------------------------------------------------- número de documento

String _normalizarNumero(String? numero) => (numero ?? '').trim().toLowerCase();

/// `true` si el número de factura o boleta ya está en otra mantención
/// realizada del vehículo (posible duplicado).
bool numeroDocumentoDuplicado(
  String? numero,
  Iterable<MantencionModel> existentes,
) {
  final buscado = _normalizarNumero(numero);
  if (buscado.isEmpty) return false;
  return existentes.any(
    (m) =>
        m.estado == EstadoMantencion.realizada &&
        _normalizarNumero(m.numeroComprobante) == buscado,
  );
}

// ---------------------------------------------------------------- costo

/// IVA vigente en Chile.
const double ivaChile = 0.19;

/// `true` si [total] ≈ [neto] × 1,19. La tolerancia es la mayor entre $10 y el
/// 0,5% del total, para no alertar por redondeos de la factura.
bool totalCuadraConNeto({required int total, required int neto}) {
  final esperado = neto * (1 + ivaChile);
  final tolerancia = total * 0.005 > 10 ? total * 0.005 : 10;
  return (total - esperado).abs() <= tolerancia;
}

// ------------------------------------------------- próxima mantención

/// Próxima mantención sugerida (km y/o fecha).
typedef ProximaMantencionSugerida = ({int? km, DateTime? fecha});

/// PUNTO DE EXTENSIÓN. Acá se calculará la próxima mantención sugerida cuando el
/// cliente entregue su base estándar de mantenciones por kilometraje. Hoy no
/// hay intervalos definidos, así que no sugiere nada (null): no se inventan.
ProximaMantencionSugerida? sugerirProximaMantencion({
  required TipoMantencion tipo,
  int? kilometraje,
  DateTime? fecha,
}) {
  return null;
}
