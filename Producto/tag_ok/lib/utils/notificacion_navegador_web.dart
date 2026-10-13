import 'dart:html' as html;

bool get navegadorSoportaNotificaciones => html.Notification.supported;

/// 'granted' | 'denied' | 'default' | 'unsupported'
String get permisoNotificacionNavegador => navegadorSoportaNotificaciones
    ? (html.Notification.permission ?? 'default')
    : 'unsupported';

/// Debe llamarse desde un gesto del usuario (un toque): Safari y Chrome
/// pueden ignorar o silenciar el permiso si se pide sin interacción.
Future<String> pedirPermisoNotificacionNavegador() async {
  if (!navegadorSoportaNotificaciones) return 'unsupported';
  return html.Notification.requestPermission();
}

void mostrarNotificacionNavegador({
  required String titulo,
  required String cuerpo,
  String? tag,
}) {
  if (permisoNotificacionNavegador != 'granted') return;
  try {
    // `tag` evita duplicados: el navegador reemplaza una notificación
    // existente con el mismo tag.
    html.Notification(titulo, body: cuerpo, tag: tag, icon: 'icons/Icon-192.png');
  } catch (_) {
    // Algunos navegadores móviles no permiten `new Notification()`; no es
    // crítico, el aviso sigue visible en la bandeja de la app.
  }
}
