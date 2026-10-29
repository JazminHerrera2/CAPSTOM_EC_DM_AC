import 'package:cloud_firestore/cloud_firestore.dart';

/// Categorías de beneficio (RF-034). El texto de [etiqueta] es lo que se
/// guarda en Firestore (`categoria`) y lo que ve el usuario.
enum CategoriaBeneficio {
  combustible('Combustible'),
  talleres('Talleres'),
  mantenciones('Mantenciones'),
  estacionamientos('Estacionamientos'),
  lavado('Lavado'),
  neumaticos('Neumáticos'),
  seguros('Seguros'),
  accesorios('Accesorios'),

  /// El administrador escribe el nombre de la categoría (`categoria_otra`).
  otros('Otros');

  final String etiqueta;
  const CategoriaBeneficio(this.etiqueta);

  /// `null` si el texto no corresponde a ninguna categoría conocida.
  static CategoriaBeneficio? desdeEtiqueta(Object? valor) {
    if (valor is! String) return null;
    final buscado = valor.trim().toLowerCase();
    for (final c in values) {
      if (c.etiqueta.toLowerCase() == buscado) return c;
    }
    return null;
  }
}

/// Filtro de vigencia del catálogo (RF-033). El catálogo ya muestra solo lo
/// vigente; [porVencer] deja los que terminan dentro de [diasPorVencer] días.
enum FiltroVigencia { cualquiera, porVencer }

const int diasPorVencer = 30;

DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

/// Beneficio del catálogo global (colección `beneficios`). Lo administra el
/// backoffice y lo leen todos los usuarios con sesión; no referencia a ningún
/// usuario ni vehículo. El id del documento es el `beneficio_id` del
/// diccionario de datos (no se guarda como campo aparte).
///
/// `imagenPath` es una URL https externa (decisión de alcance: la subida de
/// imágenes a Supabase queda como mejora futura).
class BeneficioModel {
  final String id;
  final CategoriaBeneficio? categoria;

  /// Nombre de la categoría cuando [categoria] es `otros`.
  final String? categoriaOtra;
  final String titulo;
  final String? descripcion;
  final String? empresa;
  final String? imagenPath;
  final String? urlExterna;
  final String? ubicacion;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? condiciones;
  final bool destacado;
  final bool activo;

  const BeneficioModel({
    required this.id,
    required this.titulo,
    this.categoria,
    this.categoriaOtra,
    this.descripcion,
    this.empresa,
    this.imagenPath,
    this.urlExterna,
    this.ubicacion,
    this.fechaInicio,
    this.fechaFin,
    this.condiciones,
    this.destacado = false,
    this.activo = true,
  });

  /// Tolerante: un campo ausente o de tipo inesperado no rompe el catálogo.
  factory BeneficioModel.fromJson(Map<String, dynamic> json, String id) {
    String? texto(String clave) {
      final v = json[clave];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    DateTime? fecha(String clave) {
      final v = json[clave];
      return v is Timestamp ? v.toDate() : null;
    }

    return BeneficioModel(
      id: id,
      categoria: CategoriaBeneficio.desdeEtiqueta(json['categoria']),
      categoriaOtra: texto('categoria_otra'),
      titulo: texto('titulo') ?? 'Beneficio',
      descripcion: texto('descripcion'),
      empresa: texto('empresa'),
      imagenPath: texto('imagen_path'),
      urlExterna: texto('url_externa'),
      ubicacion: texto('ubicacion'),
      fechaInicio: fecha('fecha_inicio'),
      fechaFin: fecha('fecha_fin'),
      condiciones: texto('condiciones'),
      destacado: json['destacado'] == true,
      activo: json['activo'] != false,
    );
  }

  /// Para el backoffice. Los opcionales vacíos no se escriben.
  Map<String, dynamic> toJson() => {
        if (categoria != null) 'categoria': categoria!.etiqueta,
        if (categoria == CategoriaBeneficio.otros && categoriaOtra != null)
          'categoria_otra': categoriaOtra,
        'titulo': titulo,
        if (descripcion != null) 'descripcion': descripcion,
        if (empresa != null) 'empresa': empresa,
        if (imagenPath != null) 'imagen_path': imagenPath,
        if (urlExterna != null) 'url_externa': urlExterna,
        if (ubicacion != null) 'ubicacion': ubicacion,
        if (fechaInicio != null)
          'fecha_inicio': Timestamp.fromDate(fechaInicio!),
        if (fechaFin != null) 'fecha_fin': Timestamp.fromDate(fechaFin!),
        if (condiciones != null) 'condiciones': condiciones,
        'destacado': destacado,
        'activo': activo,
      };

  /// Categoría tal como se muestra: el texto libre si es "Otros".
  String get etiquetaCategoria {
    if (categoria == CategoriaBeneficio.otros) return categoriaOtra ?? 'Otros';
    return categoria?.etiqueta ?? 'Beneficio';
  }

  /// Vigente en [ahora], por fecha calendario: el día de inicio y el de fin
  /// cuentan como vigentes. Sin fechas, siempre vigente.
  bool estaVigente([DateTime? ahora]) {
    final hoy = _soloFecha(ahora ?? DateTime.now());
    final inicio = fechaInicio;
    final fin = fechaFin;
    if (inicio != null && _soloFecha(inicio).isAfter(hoy)) return false;
    if (fin != null && _soloFecha(fin).isBefore(hoy)) return false;
    return true;
  }

  /// RF-030: lo que ve el conductor (activo y dentro de vigencia).
  bool visibleParaConductor([DateTime? ahora]) =>
      activo && estaVigente(ahora);

  /// Termina dentro de [dias] días (y sigue vigente).
  bool vencePronto([DateTime? ahora, int dias = diasPorVencer]) {
    final fin = fechaFin;
    if (fin == null || !estaVigente(ahora)) return false;
    final hoy = _soloFecha(ahora ?? DateTime.now());
    return !_soloFecha(fin).isAfter(hoy.add(Duration(days: dias)));
  }
}

/// Criterios de búsqueda del catálogo (RF-033). `null` = sin filtrar.
class FiltroBeneficios {
  final CategoriaBeneficio? categoria;

  /// Texto libre; coincide si está contenido en `ubicacion`, sin distinguir
  /// mayúsculas ni tildes.
  final String? ubicacion;
  final FiltroVigencia vigencia;

  const FiltroBeneficios({
    this.categoria,
    this.ubicacion,
    this.vigencia = FiltroVigencia.cualquiera,
  });
}

String _sinTildes(String s) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().runes) {
    final ch = String.fromCharCode(c);
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  return b.toString().trim();
}

/// Catálogo que ve el conductor: solo activos y vigentes, filtrados según
/// [filtro], con los destacados primero. Dentro de cada grupo, los que
/// terminan antes van antes (los sin fecha de fin, al final) y luego por
/// título. No muta [todos].
List<BeneficioModel> catalogoParaConductor(
  Iterable<BeneficioModel> todos, {
  FiltroBeneficios filtro = const FiltroBeneficios(),
  DateTime? ahora,
}) {
  final momento = ahora ?? DateTime.now();
  final buscada = _sinTildes(filtro.ubicacion ?? '');

  final lista = todos.where((b) {
    if (!b.visibleParaConductor(momento)) return false;
    if (filtro.categoria != null && b.categoria != filtro.categoria) {
      return false;
    }
    if (buscada.isNotEmpty &&
        !_sinTildes(b.ubicacion ?? '').contains(buscada)) {
      return false;
    }
    if (filtro.vigencia == FiltroVigencia.porVencer &&
        !b.vencePronto(momento)) {
      return false;
    }
    return true;
  }).toList();

  lista.sort((a, b) {
    if (a.destacado != b.destacado) return a.destacado ? -1 : 1;
    final fa = a.fechaFin;
    final fb = b.fechaFin;
    if (fa != fb) {
      if (fa == null) return 1;
      if (fb == null) return -1;
      final c = fa.compareTo(fb);
      if (c != 0) return c;
    }
    return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
  });
  return lista;
}
