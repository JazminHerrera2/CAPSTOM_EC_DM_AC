/// Lista ANTERIOR de tipos de mantención. Ya no se elige de una lista: el tipo
/// es un título de texto libre. Se conserva solo para mostrar bien las
/// mantenciones antiguas, cuyo campo `tipo` guarda uno de estos valores (ver
/// `tituloMantencion` en utils/titulo_mantencion.dart). No agregar tipos nuevos.
enum TipoMantencion {
  cambioAceite('cambio_aceite', 'Cambio de aceite'),
  revisionGeneral('revision_general', 'Revisión general'),
  cambioFiltros('cambio_filtros', 'Cambio de filtros'),
  frenos('frenos', 'Frenos'),
  neumaticos('neumaticos', 'Neumáticos'),
  alineacionBalanceo('alineacion_balanceo', 'Alineación y balanceo'),
  bateria('bateria', 'Batería'),
  sistemaElectrico('sistema_electrico', 'Sistema eléctrico'),
  motor('motor', 'Motor'),
  preventiva('preventiva', 'Preventiva'),
  otra('otra', 'Otra');

  const TipoMantencion(this.valorFirestore, this.etiqueta);

  /// Valor que se guarda en Firestore (campo `tipo`).
  final String valorFirestore;

  /// Texto que ve el usuario.
  final String etiqueta;

  /// Etiquetas en el orden en que se muestran en los selectores.
  static List<String> get etiquetas =>
      TipoMantencion.values.map((t) => t.etiqueta).toList();

  static TipoMantencion fromEtiqueta(String etiqueta) {
    return TipoMantencion.values.firstWhere(
      (t) => t.etiqueta == etiqueta,
      orElse: () => TipoMantencion.otra,
    );
  }

  static TipoMantencion fromFirestore(String valor) {
    return TipoMantencion.values.firstWhere(
      (t) => t.valorFirestore == valor,
      orElse: () => TipoMantencion.otra,
    );
  }
}
