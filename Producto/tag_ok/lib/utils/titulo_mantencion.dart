import '../data/models/tipo_mantencion.dart';

/// Largo máximo del título de una mantención (coincide con firestore.rules).
const int largoMaximoTituloMantencion = 60;

/// Limpia el título que escribió el usuario: recorta los extremos y colapsa
/// los espacios repetidos. No cambia mayúsculas ni minúsculas. Devuelve null
/// si queda vacío o si pasa de [largoMaximoTituloMantencion] (el formulario
/// lo limita al escribir, así que no debería ocurrir).
String? normalizarTituloMantencion(String? texto) {
  final limpio = (texto ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty || limpio.length > largoMaximoTituloMantencion) {
    return null;
  }
  return limpio;
}

/// Igual que [normalizarTituloMantencion], pero recorta en vez de rechazar:
/// para los títulos que propone la IA.
String? recortarTituloMantencion(String? texto) {
  final limpio = (texto ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty) return null;
  return limpio.length > largoMaximoTituloMantencion
      ? limpio.substring(0, largoMaximoTituloMantencion).trimRight()
      : limpio;
}

/// Título a mostrar de una mantención. Las antiguas guardan un valor de la
/// lista anterior (`cambio_aceite`, `otra` + `tipo_otro`...) y se muestran
/// con su etiqueta; cualquier otro texto es el título libre tal cual. Nunca
/// devuelve vacío.
String tituloMantencion(String? tipo, {String? tipoOtro}) {
  final valor = (tipo ?? '').trim();
  final otro = (tipoOtro ?? '').trim();
  if (valor.isEmpty || valor == TipoMantencion.otra.valorFirestore) {
    return otro.isNotEmpty ? otro : TipoMantencion.otra.etiqueta;
  }
  for (final t in TipoMantencion.values) {
    if (t.valorFirestore == valor) return t.etiqueta;
  }
  return valor;
}
