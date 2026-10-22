/// Campos normalizados y los que quedan "dudosos" (la UI los resalta para que
/// el usuario los revise antes de guardar).
typedef CamposValidados = ({
  Map<String, dynamic> campos,
  Set<String> dudosos,
});

final RegExp _patenteChilena = RegExp(
  r'^([A-Z]{4}\d{2}|[A-Z]{2}\d{4}|[A-Z]{3}\d{2}|[A-Z]{2}\d{3})$',
);

/// Deja solo letras y números en mayúscula: "ab-cd 12" → "ABCD12". Descarta el
/// dígito verificador que traen algunos documentos tras un guion
/// ("KZZZ60-0" → "KZZZ60").
String normalizarPatente(String patente) {
  var p = patente.toUpperCase().trim();
  final conVerificador =
      RegExp(r'^([A-Z]{2,4}[\s.\-·]*\d{2,4})\s*-\s*[\dK]$').firstMatch(p);
  if (conVerificador != null) p = conVerificador.group(1)!;
  return p.replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// `true` si [patenteNormalizada] tiene un formato chileno válido: autos
/// (`BBBB10`, `AB1234`) y motos (`BBB11`, `AA123`).
bool esPatenteChilena(String patenteNormalizada) =>
    _patenteChilena.hasMatch(patenteNormalizada);

DateTime? _fechaValida(int anio, int mes, int dia) {
  final fecha = DateTime(anio, mes, dia);
  return (fecha.year == anio && fecha.month == mes && fecha.day == dia)
      ? fecha
      : null;
}

const Map<String, int> _meses = {
  'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4, 'mayo': 5, 'junio': 6,
  'julio': 7, 'agosto': 8, 'septiembre': 9, 'setiembre': 9, 'octubre': 10,
  'noviembre': 11, 'diciembre': 12,
};

/// Interpreta "YYYY-MM-DD", "DD/MM/YYYY" (también con "-" o ".") o "26 febrero
/// 2026". Devuelve null si no es una fecha real (p. ej. 2026-02-31).
DateTime? interpretarFecha(String texto) {
  final t = texto.trim();
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(t);
  if (iso != null) {
    return _fechaValida(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final cl = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$').firstMatch(t);
  if (cl != null) {
    return _fechaValida(
      int.parse(cl.group(3)!),
      int.parse(cl.group(2)!),
      int.parse(cl.group(1)!),
    );
  }
  final enPalabras = RegExp(
    r'^(\d{1,2})\s*(?:de\s+)?([A-Za-zÁÉÍÓÚáéíóú]+)\s*(?:de\s+)?(\d{4})$',
  ).firstMatch(t);
  if (enPalabras != null) {
    final mes = _meses[enPalabras.group(2)!.toLowerCase()
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u')];
    if (mes != null) {
      return _fechaValida(
        int.parse(enPalabras.group(3)!),
        mes,
        int.parse(enPalabras.group(1)!),
      );
    }
  }
  return null;
}

String _iso(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-'
    '${f.month.toString().padLeft(2, '0')}-'
    '${f.day.toString().padLeft(2, '0')}';

/// Fecha en el formato "YYYY-MM-DD" que usan los campos de fecha de la revisión.
String formatoIsoFecha(DateTime f) => _iso(f);

/// Normaliza y valida lo que devolvió la IA, sin depender de que acierte:
///
/// - **Patente**: se pasa a mayúsculas sin separadores; si no tiene formato
///   chileno queda como dudosa (se conserva el valor para que el usuario lo
///   corrija).
/// - **Fechas**: se convierten a `YYYY-MM-DD`; una fecha imposible se descarta
///   (queda como dudosa). Una emisión futura o anterior a 1990, o un
///   vencimiento anterior a la emisión o a más de 15 años, quedan dudosos.
/// - **Textos**: se recortan los espacios.
///
/// [ahora] solo existe para poder probarlo con una fecha fija.
CamposValidados validarCamposExtraidos(
  Map<String, dynamic> campos, {
  DateTime? ahora,
}) {
  final hoy = ahora ?? DateTime.now();
  final limpios = <String, dynamic>{};
  final dudosos = <String>{};

  for (final entry in campos.entries) {
    final valor = entry.value;
    limpios[entry.key] = valor is String ? valor.trim() : valor;
  }

  // Patente.
  final patenteRaw = limpios['patente'];
  if (patenteRaw is String) {
    final p = normalizarPatente(patenteRaw);
    if (p.isEmpty) {
      limpios.remove('patente');
    } else {
      limpios['patente'] = p;
      if (!esPatenteChilena(p)) dudosos.add('patente');
    }
  }

  // Fechas.
  DateTime? emision;
  DateTime? vencimiento;
  for (final clave in const ['fecha_emision', 'fecha_vencimiento']) {
    final raw = limpios[clave];
    if (raw == null) continue;
    final fecha = interpretarFecha(raw.toString());
    if (fecha == null) {
      limpios.remove(clave);
      dudosos.add(clave);
      continue;
    }
    limpios[clave] = _iso(fecha);
    if (clave == 'fecha_emision') {
      emision = fecha;
    } else {
      vencimiento = fecha;
    }
  }

  final manana = DateTime(hoy.year, hoy.month, hoy.day).add(
    const Duration(days: 1),
  );
  if (emision != null && (emision.isAfter(manana) || emision.year < 1990)) {
    dudosos.add('fecha_emision');
  }
  if (vencimiento != null) {
    final demasiadoLejos = DateTime(hoy.year + 15, hoy.month, hoy.day);
    if (vencimiento.year < 1990 || vencimiento.isAfter(demasiadoLejos)) {
      dudosos.add('fecha_vencimiento');
    }
    if (emision != null && vencimiento.isBefore(emision)) {
      dudosos.add('fecha_vencimiento');
      dudosos.add('fecha_emision');
    }
  }

  return (campos: limpios, dudosos: dudosos);
}
