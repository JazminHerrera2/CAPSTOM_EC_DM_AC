import '../data/models/componente_mantencion_model.dart';
import '../data/models/mantencion_model.dart';

/// Minúsculas y sin tildes, para que "revision" encuentre "Revisión".
String normalizarParaBuscar(String texto) {
  const de = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const a = 'aaaaaeeeeiiiiooooouuuun';
  final b = StringBuffer();
  for (final c in texto.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  return b.toString();
}

/// Todo el texto de una mantención en el que se puede buscar: tipo, taller,
/// descripción, observaciones, comprobante (tipo y número) y los componentes
/// revisados. Los números (km, costo) no cuentan: son cifras, no texto.
String textoBuscable(MantencionModel m) {
  final nombresComponentes = {
    for (final c in componentesPorDefecto) c.id: c.nombre,
  };
  final partes = <String?>[
    m.nombreTipo,
    m.tipo,
    m.tipoOtro,
    m.taller,
    m.descripcion,
    m.observaciones,
    m.tipoComprobante?.etiqueta,
    m.numeroComprobante,
    for (final id in m.componentes)
      nombresComponentes[id] ?? id.replaceAll('_', ' '),
  ];
  return normalizarParaBuscar(
    partes.whereType<String>().where((p) => p.trim().isNotEmpty).join(' '),
  );
}

/// ¿La mantención coincide con lo escrito en el buscador? Cada palabra escrita
/// debe aparecer en algún texto de la mantención (en cualquier orden). Un
/// buscador vacío coincide con todo.
bool coincideConBusqueda(MantencionModel m, String busqueda) {
  final palabras = normalizarParaBuscar(busqueda)
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (palabras.isEmpty) return true;
  final texto = textoBuscable(m);
  return palabras.every(texto.contains);
}
