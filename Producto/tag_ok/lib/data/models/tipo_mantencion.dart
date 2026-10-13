/// Tipos de mantención del módulo Mantenciones. Única fuente de verdad: las
/// pantallas, el modelo y las reglas de Firestore usan estos mismos valores.
///
/// Si se agrega o renombra un tipo, hay que actualizar también la lista
/// `d.tipo in [...]` de `mantencionValida()` en firestore.rules.
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
