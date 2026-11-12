/// Un registro de la colección `auditoria` listo para mostrarse en la
/// Bitácora de Auditoría (RF-054).
///
/// La colección recibe registros de dos lugares, con campos distintos:
///  - **Panel admin** (`AdminFirestoreService.logAction`): `adminEmail`,
///    `action`, `target`, `details`, `fecha`.
///  - **App** (`AuditoriaService` de tag_ok, formato del diccionario de
///    datos): `usuario_id`, `accion`, `tipo_entidad`, `entidad_id`, `detalle`,
///    `origen`, `fecha`.
///
/// Esta clase los deja en un solo formato. No modifica los datos guardados.
class RegistroAuditoria {
  const RegistroAuditoria({
    required this.fecha,
    required this.esDeLaApp,
    required this.responsable,
    required this.accion,
    required this.objetivo,
    required this.detalle,
    required this.fuente,
  });

  /// Valor crudo de `fecha` (normalmente un Timestamp de Firestore).
  final Object? fecha;

  /// `true` si lo escribió la app; `false` si lo escribió el panel admin.
  final bool esDeLaApp;

  /// Correo del administrador o del usuario de la app que hizo la acción.
  final String responsable;

  /// Código de la acción: `EDIT_USER`, `DELETE_PORTICO`... (panel) o `CREAR`,
  /// `ELIMINAR` (app).
  final String accion;

  /// Sobre qué se hizo la acción ("Mantención", "usuario@correo.cl"...).
  final String objetivo;

  final String detalle;

  /// De dónde viene: "Panel admin", "App · Manual", "App · IA" o
  /// "App · Sistema".
  final String fuente;

  /// Arma el registro desde los datos de Firestore. [correosUsuarios] traduce
  /// el `usuario_id` de la app (uid) al correo del usuario; si no está, se
  /// muestra el uid.
  factory RegistroAuditoria.desde(
    Map<String, dynamic> data, {
    Map<String, String> correosUsuarios = const {},
  }) {
    final esDeLaApp =
        data.containsKey('tipo_entidad') || data.containsKey('accion');
    if (!esDeLaApp) {
      return RegistroAuditoria(
        fecha: data['fecha'],
        esDeLaApp: false,
        responsable: _texto(data['adminEmail'], 'Sistema'),
        accion: _texto(data['action'], ''),
        objetivo: _texto(data['target'], ''),
        detalle: _texto(data['details'], ''),
        fuente: 'Panel admin',
      );
    }

    final uid = _texto(data['usuario_id'], '');
    return RegistroAuditoria(
      fecha: data['fecha'],
      esDeLaApp: true,
      responsable: uid.isEmpty
          ? 'Sistema'
          : (correosUsuarios[uid] ?? 'Usuario $uid'),
      accion: _texto(data['accion'], ''),
      objetivo: etiquetaEntidadAuditoria(_texto(data['tipo_entidad'], '')),
      detalle: _texto(data['detalle'], ''),
      fuente: 'App · ${etiquetaOrigenAuditoria(_texto(data['origen'], ''))}',
    );
  }

  /// `true` si [busqueda] (en minúsculas) aparece en el responsable, el
  /// objetivo, el detalle o la fuente.
  bool coincideCon(String busqueda) {
    if (busqueda.isEmpty) return true;
    return [responsable, objetivo, detalle, fuente]
        .any((campo) => campo.toLowerCase().contains(busqueda));
  }

  static String _texto(Object? valor, String siFalta) {
    final texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? siFalta : texto;
  }
}

/// Nombre legible de un `tipo_entidad` de la app.
String etiquetaEntidadAuditoria(String tipoEntidad) => switch (tipoEntidad) {
      'MANTENCION' => 'Mantención',
      'ABASTECIMIENTO' => 'Carga de combustible',
      'DOCUMENTO_VEHICULAR' => 'Documento vehicular',
      'VEHICULO' => 'Vehículo',
      '' => '-',
      _ => tipoEntidad,
    };

/// Nombre legible de un `origen` de la app (`manual`, `ia`, `sistema`).
String etiquetaOrigenAuditoria(String origen) => switch (origen) {
      'ia' => 'IA',
      'manual' => 'Manual',
      'sistema' => 'Sistema',
      '' => 'Sin origen',
      _ => origen,
    };
