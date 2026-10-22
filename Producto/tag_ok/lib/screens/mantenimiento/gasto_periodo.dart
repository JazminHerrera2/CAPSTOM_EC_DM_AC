import '../../data/models/mantencion_model.dart';

/// Lógica pura del card "Gasto en mantenciones": periodos y agregados. No
/// depende de widgets ni de Firestore; todo lo que depende de "hoy" lo recibe
/// por parámetro para poder probarlo con una fecha fija. Los periodos se
/// comparan por fecha calendario local (año y mes del `DateTime` de la
/// mantención), nunca por hora.

enum TipoPeriodo { mes, anio, todo }

const List<String> _nombresMeses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _capitalizar(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// Un periodo mostrado en el card: un mes, un año o todo el historial.
class PeriodoGasto {
  final TipoPeriodo tipo;

  /// Primer día del mes (tipo mes) o 1 de enero (tipo año). Sin uso en `todo`.
  final DateTime inicio;

  PeriodoGasto._(this.tipo, this.inicio);

  factory PeriodoGasto.mes(DateTime fecha) =>
      PeriodoGasto._(TipoPeriodo.mes, DateTime(fecha.year, fecha.month));

  factory PeriodoGasto.anio(DateTime fecha) =>
      PeriodoGasto._(TipoPeriodo.anio, DateTime(fecha.year));

  factory PeriodoGasto.todo() => PeriodoGasto._(TipoPeriodo.todo, DateTime(1900));

  /// Periodo del [tipo] que contiene a [fecha].
  factory PeriodoGasto.de(TipoPeriodo tipo, DateTime fecha) {
    switch (tipo) {
      case TipoPeriodo.mes:
        return PeriodoGasto.mes(fecha);
      case TipoPeriodo.anio:
        return PeriodoGasto.anio(fecha);
      case TipoPeriodo.todo:
        return PeriodoGasto.todo();
    }
  }

  /// `true` si [fecha] cae dentro del periodo (siempre en `todo`).
  bool contiene(DateTime fecha) {
    switch (tipo) {
      case TipoPeriodo.mes:
        return fecha.year == inicio.year && fecha.month == inicio.month;
      case TipoPeriodo.anio:
        return fecha.year == inicio.year;
      case TipoPeriodo.todo:
        return true;
    }
  }

  /// "Octubre 2026", "2026" o "Todo".
  String get etiqueta {
    switch (tipo) {
      case TipoPeriodo.mes:
        return '${_capitalizar(_nombresMeses[inicio.month - 1])} ${inicio.year}';
      case TipoPeriodo.anio:
        return '${inicio.year}';
      case TipoPeriodo.todo:
        return 'Todo';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodoGasto && other.tipo == tipo && other.inicio == inicio;

  @override
  int get hashCode => Object.hash(tipo, inicio);
}

/// Total y cantidad de mantenciones de un periodo.
typedef ResumenGasto = ({int total, int cantidad});

/// Suma las mantenciones **realizadas con costo** del [periodo]. Las
/// programadas todavía no se gastaron y las sin costo no tienen monto que
/// sumar: no cuentan. Las sin fecha solo cuentan en `todo`.
ResumenGasto calcularGasto(
  Iterable<MantencionModel> mantenciones,
  PeriodoGasto periodo,
) {
  var total = 0;
  var cantidad = 0;
  for (final m in mantenciones) {
    final costo = m.costo;
    if (m.estado != EstadoMantencion.realizada || costo == null) continue;
    if (periodo.tipo != TipoPeriodo.todo) {
      final fecha = m.fecha;
      if (fecha == null || !periodo.contiene(fecha)) continue;
    }
    total += costo;
    cantidad++;
  }
  return (total: total, cantidad: cantidad);
}

/// Mes más antiguo con una mantención realizada (null si no hay ninguna).
DateTime? primerMesConMantenciones(Iterable<MantencionModel> mantenciones) {
  DateTime? primero;
  for (final m in mantenciones) {
    final fecha = m.fecha;
    if (m.estado != EstadoMantencion.realizada || fecha == null) continue;
    if (primero == null || fecha.isBefore(primero)) primero = fecha;
  }
  return primero == null ? null : DateTime(primero.year, primero.month);
}
