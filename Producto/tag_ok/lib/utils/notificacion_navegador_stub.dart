/// Fuera de web no hay notificaciones del navegador (en Android/iOS se usan
/// las notificaciones locales de `RecordatoriosLocalesService`).
bool get navegadorSoportaNotificaciones => false;

/// 'granted' | 'denied' | 'default' | 'unsupported'
String get permisoNotificacionNavegador => 'unsupported';

Future<String> pedirPermisoNotificacionNavegador() async => 'unsupported';

void mostrarNotificacionNavegador({
  required String titulo,
  required String cuerpo,
  String? tag,
}) {}
