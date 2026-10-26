/// Componente que se revisa en una mantención (colección
/// `componentes_mantencion`). Es una tabla en la BD para poder agregar,
/// editar o eliminar componentes sin tocar la app.
class ComponenteMantencion {
  /// Id del documento; es lo que guarda cada mantención en `componentes`.
  final String id;
  final String nombre;

  /// Posición en la lista (menor primero).
  final int orden;

  /// Los inactivos no se ofrecen en el formulario ni se piden a la IA.
  final bool activo;

  const ComponenteMantencion({
    required this.id,
    required this.nombre,
    required this.orden,
    this.activo = true,
  });

  factory ComponenteMantencion.fromJson(Map<String, dynamic> json, String id) {
    return ComponenteMantencion(
      id: id,
      nombre: (json['nombre'] as String?) ?? id,
      orden: (json['orden'] as num?)?.toInt() ?? 0,
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'orden': orden,
        'activo': activo,
      };
}

/// Componentes iniciales. Se usan mientras la colección está vacía y como
/// semilla (`ComponenteMantencionService.sembrarPorDefecto`). Los ids son
/// fijos para que lo guardado en las mantenciones siga valiendo.
const List<ComponenteMantencion> componentesPorDefecto = [
  ComponenteMantencion(id: 'mantencion_general', nombre: 'Mantención general', orden: 1),
  ComponenteMantencion(id: 'cambio_aceite_motor', nombre: 'Cambio aceite motor', orden: 2),
  ComponenteMantencion(id: 'rotacion_neumaticos', nombre: 'Rotación neumáticos', orden: 3),
  ComponenteMantencion(id: 'frenos', nombre: 'Frenos', orden: 4),
  ComponenteMantencion(id: 'filtro_aire', nombre: 'Filtro de aire', orden: 5),
  ComponenteMantencion(id: 'bateria', nombre: 'Batería', orden: 6),
  ComponenteMantencion(id: 'liquido_frenos', nombre: 'Líquido frenos', orden: 7),
];
