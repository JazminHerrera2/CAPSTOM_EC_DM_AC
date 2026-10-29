import '../../data/models/documento_vehicular_model.dart';
import '../../data/models/mantencion_model.dart';

/// Lógica pura del dashboard "Mi Auto": gastos por mes, próximo vencimiento,
/// próxima mantención y estado global. No depende de widgets ni de Firestore;
/// todo lo que depende de "hoy" entra por parámetro para poder probarlo.

enum CategoriaGasto {
  tag('TAG'),
  combustible('Combustible'),
  estacionamientos('Estacionamientos'),
  mantenciones('Mantenciones');

  final String etiqueta;
  const CategoriaGasto(this.etiqueta);
}

/// Un gasto suelto: de qué vehículo es (si se sabe), cuándo, cuánto y una
/// descripción corta para el historial.
typedef GastoRegistro = ({
  String? vehiculoId,
  DateTime fecha,
  int monto,
  String titulo,
  String? detalle,
});

/// Meses que muestra el gráfico del Inicio (el actual y los 4 anteriores).
const int mesesDelGrafico = 5;

/// Gastos de los últimos [mesesDelGrafico] meses, el mes actual al final
/// (RF-044, RF-048).
class ResumenGastos {
  /// Primer día de cada mes, del más antiguo al actual.
  final List<DateTime> meses;

  /// Total de cada mes, en el mismo orden que [meses].
  final List<int> totales;

  /// Total del mes actual por categoría. Incluye las 4, aunque sea 0.
  final Map<CategoriaGasto, int> desglose;

  const ResumenGastos({
    required this.meses,
    required this.totales,
    required this.desglose,
  });

  int get totalMes => totales.last;
  int get totalMesAnterior => totales[totales.length - 2];

  /// Variación % del mes actual contra el anterior. `null` si el mes
  /// anterior fue $0 (no se puede calcular).
  double? get variacionPct {
    if (totalMesAnterior == 0) return null;
    return (totalMes - totalMesAnterior) / totalMesAnterior * 100;
  }
}

/// Altura de cada barra del gráfico, de 0 a 1, según su POSICIÓN y no según el
/// monto: el mes que más gastó llega al tope (1.0) y los demás bajan un escalón
/// por cada puesto que ocupan (de mayor a menor gasto). Meses con el mismo
/// gasto comparten puesto; un mes sin gastos queda en 0.
///
/// Ej. con 5 meses: [10, 50, 30, 0, 40] -> [0.4, 1.0, 0.6, 0.0, 0.8].
List<double> alturasPorPosicion(List<int> totales) {
  final distintos = totales.where((t) => t > 0).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  final n = totales.length;
  return [
    for (final t in totales)
      t <= 0 ? 0.0 : (1 - distintos.indexOf(t) / n).clamp(0.0, 1.0),
  ];
}

/// Suma [registros] por mes y categoría. Siempre devuelve [cantidadMeses]
/// meses (con $0 donde no hay datos); lo anterior a esos meses y lo posterior
/// al mes actual no cuenta.
ResumenGastos calcularResumenGastos(
  Map<CategoriaGasto, Iterable<GastoRegistro>> registros, {
  DateTime? ahora,
  int cantidadMeses = mesesDelGrafico,
}) {
  final hoy = ahora ?? DateTime.now();
  final meses = [
    for (var i = cantidadMeses - 1; i >= 0; i--)
      DateTime(hoy.year, hoy.month - i),
  ];
  final totales = List<int>.filled(cantidadMeses, 0);
  final desglose = {for (final c in CategoriaGasto.values) c: 0};

  for (final entrada in registros.entries) {
    for (final r in entrada.value) {
      final indice = meses.indexWhere(
        (m) => m.year == r.fecha.year && m.month == r.fecha.month,
      );
      if (indice < 0) continue;
      totales[indice] += r.monto;
      if (indice == cantidadMeses - 1) {
        desglose[entrada.key] = desglose[entrada.key]! + r.monto;
      }
    }
  }
  return ResumenGastos(meses: meses, totales: totales, desglose: desglose);
}

/// Mantenciones realizadas con costo y fecha, como gastos.
List<GastoRegistro> gastosDeMantenciones(Iterable<MantencionModel> lista) {
  return [
    for (final m in lista)
      if (m.estado == EstadoMantencion.realizada &&
          m.costo != null &&
          m.fecha != null)
        (
          vehiculoId: m.vehiculoId,
          fecha: m.fecha!,
          monto: m.costo!,
          titulo: m.nombreTipo,
          detalle: m.taller,
        ),
  ];
}

// --- Historial de gastos ---------------------------------------------------

/// Un gasto del historial, con su categoría (mantención, TAG, etc.).
class MovimientoGasto {
  final CategoriaGasto categoria;
  final DateTime fecha;
  final int monto;
  final String titulo;
  final String? detalle;

  const MovimientoGasto({
    required this.categoria,
    required this.fecha,
    required this.monto,
    required this.titulo,
    this.detalle,
  });
}

/// Todos los gastos de [registros] en una sola lista, del más reciente al más
/// antiguo (a igual fecha, el de mayor monto primero).
List<MovimientoGasto> movimientosDeGasto(
  Map<CategoriaGasto, Iterable<GastoRegistro>> registros,
) {
  final lista = <MovimientoGasto>[
    for (final e in registros.entries)
      for (final r in e.value)
        MovimientoGasto(
          categoria: e.key,
          fecha: r.fecha,
          monto: r.monto,
          titulo: r.titulo,
          detalle: r.detalle,
        ),
  ];
  lista.sort((a, b) {
    final porFecha = b.fecha.compareTo(a.fecha);
    return porFecha != 0 ? porFecha : b.monto.compareTo(a.monto);
  });
  return lista;
}

/// Filtra por año y/o por mes (1 a 12). `null` = sin filtrar por ese criterio.
List<MovimientoGasto> filtrarMovimientos(
  Iterable<MovimientoGasto> movimientos, {
  int? anio,
  int? mes,
}) {
  return movimientos.where((m) {
    if (anio != null && m.fecha.year != anio) return false;
    if (mes != null && m.fecha.month != mes) return false;
    return true;
  }).toList();
}

/// Años en que hay gastos, del más reciente al más antiguo.
List<int> aniosConMovimientos(Iterable<MovimientoGasto> movimientos) {
  final anios = {for (final m in movimientos) m.fecha.year};
  return anios.toList()..sort((a, b) => b.compareTo(a));
}

/// Total por categoría. Incluye las cuatro, aunque sea $0.
Map<CategoriaGasto, int> totalesPorCategoria(
  Iterable<MovimientoGasto> movimientos,
) {
  final totales = {for (final c in CategoriaGasto.values) c: 0};
  for (final m in movimientos) {
    totales[m.categoria] = totales[m.categoria]! + m.monto;
  }
  return totales;
}

int sumarMovimientos(Iterable<MovimientoGasto> movimientos) =>
    movimientos.fold(0, (suma, m) => suma + m.monto);

const List<String> _nombresMeses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// "Octubre" para el mes 1 a 12.
String nombreDelMes(int mes) => _nombresMeses[mes - 1];

/// "Octubre 2026".
String nombreMes(DateTime mes) => '${_nombresMeses[mes.month - 1]} ${mes.year}';

/// Cada cuántos kilómetros toca una mantención.
const int intervaloMantencionKm = 10000;

/// Kilometraje de la próxima mantención: el que tiene el vehículo (el que se
/// pide al registrarlo) más [intervaloMantencionKm]. `null` si no tiene.
int? kilometrajeProximaMantencion(
  int? kilometrajeActual, {
  int intervalo = intervaloMantencionKm,
}) {
  if (kilometrajeActual == null || kilometrajeActual < 0) return null;
  return kilometrajeActual + intervalo;
}

/// Pesos chilenos con separador de miles: `$ 178.500`.
String formatearPesos(int monto) => '\$ ${formatearMiles(monto)}';

String formatearMiles(int n) {
  final texto = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) b.write('.');
    b.write(texto[i]);
  }
  return b.toString();
}

/// `dd/MM/yyyy`.
String formatearFecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

const List<String> _mesesCortos = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

String mesCorto(DateTime mes) => _mesesCortos[mes.month - 1];

typedef ProximoVencimiento = ({DocumentoVehicularModel documento, int dias});

/// Documento con el vencimiento más cercano (RF-046) y los días que faltan
/// desde hoy; negativo si ya venció. `null` si ninguno tiene fecha.
ProximoVencimiento? calcularProximoVencimiento(
  Iterable<DocumentoVehicularModel> documentos, {
  DateTime? ahora,
}) {
  final hoy = ahora ?? DateTime.now();
  final hoyUtc = DateTime.utc(hoy.year, hoy.month, hoy.day);
  DocumentoVehicularModel? mejor;
  DateTime? mejorFecha;
  for (final d in documentos) {
    final f = d.fechaVencimiento;
    if (f == null) continue;
    final fecha = DateTime.utc(f.year, f.month, f.day);
    if (mejorFecha == null || fecha.isBefore(mejorFecha)) {
      mejor = d;
      mejorFecha = fecha;
    }
  }
  if (mejor == null || mejorFecha == null) return null;
  return (documento: mejor, dias: mejorFecha.difference(hoyUtc).inDays);
}

/// Próxima mantención programada (RF-045): primero las que tienen fecha
/// (la más cercana), luego las que solo tienen kilometraje (el menor).
MantencionModel? calcularProximaMantencion(Iterable<MantencionModel> lista) {
  final programadas =
      lista.where((m) => m.estado == EstadoMantencion.programada).toList();
  final conFecha = programadas.where((m) => m.proximaFecha != null).toList()
    ..sort((a, b) => a.proximaFecha!.compareTo(b.proximaFecha!));
  if (conFecha.isNotEmpty) return conFecha.first;
  final soloKm =
      programadas.where((m) => m.proximoKilometraje != null).toList()
        ..sort((a, b) => a.proximoKilometraje!.compareTo(b.proximoKilometraje!));
  return soloKm.isEmpty ? null : soloKm.first;
}

int _urgencia(String estado) {
  switch (estado) {
    case 'Atención requerida':
      return 0;
    case 'Próximo vencimiento':
      return 1;
    case 'Todo al día':
      return 2;
    default:
      return 3;
  }
}

/// El peor estado de una lista de estados de vehículos; "Sin información" si
/// la lista está vacía o ninguno tiene información.
String peorEstado(Iterable<String> estados) {
  String peor = 'Sin información';
  for (final e in estados) {
    if (_urgencia(e) < _urgencia(peor)) peor = e;
  }
  return peor;
}

/// Subtítulo del saludo según el estado global.
String subtituloGlobal(String estado, {required bool hayVehiculos}) {
  if (!hayVehiculos) return 'Registra tu vehículo para comenzar.';
  switch (estado) {
    case 'Todo al día':
      return 'Todo en orden, sigamos así.';
    case 'Próximo vencimiento':
      return 'Tienes vencimientos próximos.';
    case 'Atención requerida':
      return 'Hay documentos que requieren tu atención.';
    default:
      return 'Agrega los documentos de tus vehículos.';
  }
}
