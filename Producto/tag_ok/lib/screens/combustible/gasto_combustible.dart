import '../../data/models/abastecimiento_model.dart';

/// Lógica pura del gasto en combustible: no depende de widgets ni de
/// Firestore, y todo lo que depende de "hoy" entra por parámetro para poder
/// probarlo con una fecha fija. Los meses se comparan por fecha calendario
/// local.

/// Total gastado, cantidad de cargas y energía/combustible cargado en un mes.
typedef ResumenCombustible = ({
  int total,
  int cantidad,
  double litros,
  double kwh,
});

/// Suma las cargas del mes de [mes]. Las cargas sin total (registro parcial)
/// cuentan como carga y suman su cantidad, pero no suman dinero.
ResumenCombustible calcularResumenMes(
  Iterable<AbastecimientoModel> cargas,
  DateTime mes,
) {
  var total = 0;
  var cantidad = 0;
  var litros = 0.0;
  var kwh = 0.0;
  for (final c in cargas) {
    if (c.fecha.year != mes.year || c.fecha.month != mes.month) continue;
    cantidad++;
    total += c.total ?? 0;
    final qty = c.cantidad ?? 0;
    if (c.tipoAbastecimiento == TipoAbastecimiento.cargaElectrica) {
      kwh += qty;
    } else {
      litros += qty;
    }
  }
  return (total: total, cantidad: cantidad, litros: litros, kwh: kwh);
}

/// Completa el dato que falta cuando se conocen los otros dos de
/// litros × precio = total. Devuelve los tres valores (los que ya venían se
/// respetan). Con menos de dos datos no calcula nada.
({double? cantidad, double? precioUnitario, int? total}) completarCarga({
  double? cantidad,
  double? precioUnitario,
  int? total,
}) {
  if (total == null && cantidad != null && precioUnitario != null) {
    total = (cantidad * precioUnitario).round();
  } else if (cantidad == null &&
      total != null &&
      precioUnitario != null &&
      precioUnitario > 0) {
    cantidad = double.parse((total / precioUnitario).toStringAsFixed(3));
  } else if (precioUnitario == null &&
      total != null &&
      cantidad != null &&
      cantidad > 0) {
    precioUnitario = double.parse((total / cantidad).toStringAsFixed(1));
  }
  return (cantidad: cantidad, precioUnitario: precioUnitario, total: total);
}

/// Cantidad con hasta 3 decimales y coma decimal, sin ceros sobrantes:
/// 32.451 → "32,451", 45.0 → "45", 12.5 → "12,5".
String formatoCantidad(double valor) {
  var texto = valor.toStringAsFixed(3);
  texto = texto
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return texto.replaceAll('.', ',');
}
