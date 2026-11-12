import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/estacionamiento_model.dart';
import 'openai_extraction_service.dart';
import 'preparar_imagen.dart';
import 'validacion_campos.dart';

/// Registro de estacionamiento con IA (HU-19 a HU-21, RF-020 a RF-022): la IA
/// lee la foto o el PDF del ticket o boleta y devuelve los datos que reconoce.
/// El usuario los revisa, completa lo que falte (HU-20) y confirma antes de
/// guardar (HU-21). Mismo patrón que `combustible_extraction.dart`.

/// Claves de los campos que pueden quedar marcados como dudosos en la revisión.
const String dudosoEstLugar = 'lugar';
const String dudosoEstFecha = 'fecha';
const String dudosoEstEntrada = 'hora_entrada';
const String dudosoEstSalida = 'hora_salida';
const String dudosoEstDuracion = 'duracion';
const String dudosoEstCosto = 'costo';

/// Todas las claves anteriores: lo único que se acepta como "dudoso".
const List<String> _clavesDudosas = [
  dudosoEstLugar,
  dudosoEstFecha,
  dudosoEstEntrada,
  dudosoEstSalida,
  dudosoEstDuracion,
  dudosoEstCosto,
];

/// Hora del día leída del ticket (sin fecha).
typedef HoraDelDia = ({int hora, int minuto});

/// Datos que la IA reconoció en el ticket. Todo es opcional: lo que no se lee
/// con certeza queda en null y el usuario lo completa en la revisión (CU20 E1).
/// Nunca se inventa ni se calcula un dato que el ticket no trae (por ejemplo,
/// el monto a partir de una tarifa por minuto).
class EstacionamientoExtraido {
  final String? lugar;

  /// Fecha de entrada (o del ticket, si solo trae una).
  final DateTime? fecha;
  final HoraDelDia? horaEntrada;
  final HoraDelDia? horaSalida;

  /// Fecha de salida, solo si el ticket la trae y es distinta de la entrada.
  final DateTime? fechaSalida;

  /// Duración leída del ticket o, si no viene, calculada con las horas leídas.
  /// Con tope de 30 días, como lo que se guarda.
  final int? duracionMin;

  /// Monto TOTAL pagado, en pesos.
  final int? costo;

  /// Campos que la revisión debe resaltar.
  final Set<String> camposDudosos;

  /// Proporción (0 a 1) de campos leídos sin duda. Null si no se leyó ninguno.
  final double? confianza;

  const EstacionamientoExtraido({
    this.lugar,
    this.fecha,
    this.horaEntrada,
    this.horaSalida,
    this.fechaSalida,
    this.duracionMin,
    this.costo,
    this.camposDudosos = const {},
    this.confianza,
  });

  /// `true` si la IA no logró leer ningún dato.
  bool get vacia =>
      lugar == null &&
      fecha == null &&
      horaEntrada == null &&
      horaSalida == null &&
      duracionMin == null &&
      costo == null;

  /// Fecha y hora completas de entrada, si hay fecha y hora.
  DateTime? get entrada => _combinar(fecha, horaEntrada);

  /// Fecha y hora completas de salida. Si el ticket no trae fecha de salida se
  /// usa la de entrada, y si así la salida queda antes que la entrada, se
  /// asume que pasó la medianoche (y [parseEstacionamientoExtraido] lo marca
  /// como dudoso para que el usuario lo revise).
  DateTime? get salida {
    final inicio = entrada;
    final fin = _combinar(fechaSalida ?? fecha, horaSalida);
    if (inicio == null || fin == null) return fin;
    if (fechaSalida == null && fin.isBefore(inicio)) {
      return fin.add(const Duration(days: 1));
    }
    return fin;
  }
}

/// Une una fecha y una hora en una fecha y hora completas. Null si falta
/// alguna de las dos.
DateTime? _combinar(DateTime? fecha, HoraDelDia? hora) {
  if (fecha == null || hora == null) return null;
  return DateTime(fecha.year, fecha.month, fecha.day, hora.hora, hora.minuto);
}

/// Campo del esquema JSON que puede ser texto o null, con su descripción
/// para la IA.
Map<String, dynamic> _campoTexto(String descripcion) => {
      'type': ['string', 'null'],
      'description': descripcion,
    };

/// JSON Schema estricto de OpenAI: todo va en `required` y lo que no se lee
/// con certeza se devuelve como null.
Map<String, dynamic> _esquemaEstacionamiento() {
  final properties = <String, dynamic>{
    'lugar': _campoTexto(
      'Nombre del estacionamiento, del recinto o la dirección (por ejemplo '
      '"Mall Plaza Egaña" o "Saba - Costanera Center"). Null si no se lee.',
    ),
    'fecha_entrada': _campoTexto('Fecha de entrada en formato YYYY-MM-DD.'),
    'hora_entrada': _campoTexto('Hora de entrada en formato HH:MM (24 horas).'),
    'fecha_salida': _campoTexto(
      'Fecha de salida en formato YYYY-MM-DD, solo si el ticket la muestra.',
    ),
    'hora_salida': _campoTexto('Hora de salida en formato HH:MM (24 horas).'),
    'duracion_minutos': _campoTexto(
      'Tiempo de permanencia en minutos, solo el número, si el ticket lo '
      'muestra (por ejemplo "95" si dice 1:35 o 1 h 35 min).',
    ),
    'monto_total': _campoTexto(
      'Monto TOTAL pagado en pesos chilenos (solo el número).',
    ),
    'campos_dudosos': {
      'type': 'array',
      'items': {'type': 'string', 'enum': _clavesDudosas},
      'description':
          'Campos que leíste pero de los que dudas. Lista vacía si no hay.',
    },
  };
  return {
    'type': 'object',
    'properties': properties,
    'required': properties.keys.toList(),
    'additionalProperties': false,
  };
}

/// Instrucciones que recibe la IA junto con la foto del ticket: qué leer,
/// en qué formato y qué ignorar (datos personales).
String _promptEstacionamiento() => '''
Eres un asistente experto en tickets y boletas de estacionamientos chilenos
(malls, edificios, clínicas, aeropuertos, operadores como Saba, Central
Parking o República, y parquímetros municipales). Analiza el comprobante
recibido (imagen o PDF) y extrae solo los campos que se piden.

Extrae únicamente lo que puedas reconocer con certeza. Si un dato no es
legible o no aparece, devuélvelo como null: nunca inventes, calcules ni
infieras un valor. Si lees un dato pero dudas de él (foto torcida o borrosa,
cifras que no cuadran), devuélvelo igual e inclúyelo en "campos_dudosos".

Reglas:
- "lugar": el nombre del estacionamiento o recinto del membrete, o su
  dirección. No el nombre del cliente.
- "fecha_entrada": la fecha de ingreso, en formato "YYYY-MM-DD". Si el ticket
  solo trae una fecha, úsala aquí. Los documentos chilenos escriben
  día/mes/año ("05/03/2026" es el 5 de marzo de 2026, no el 3 de mayo).
- "hora_entrada" y "hora_salida": en formato "HH:MM" de 24 horas ("3:15 PM" es
  "15:15"). Busca rótulos como "Entrada", "Ingreso", "Llegada", "Salida",
  "Egreso" o "Pago". Si el ticket es solo de entrada y no tiene salida,
  "hora_salida" es null.
- "fecha_salida": solo si el ticket muestra una fecha de salida; si no, null.
- "duracion_minutos": el tiempo de permanencia si el ticket lo muestra
  ("Tiempo", "Permanencia", "Estadía"), convertido a minutos ("1:35" o
  "1 h 35 min" son 95). Si no aparece, null: no lo calcules con las horas.
- "monto_total": el TOTAL pagado en pesos chilenos, solo con números. En Chile
  el punto separa los miles ("3.500" son tres mil quinientos pesos). Si solo
  aparece una tarifa (por ejemplo "\$25 por minuto") y no el total pagado,
  devuelve null.
- "campos_dudosos": los campos que leíste pero de los que dudas (puede ser una
  lista vacía).
- Privacidad: ignora y no devuelvas datos personales (patente, nombre, RUT,
  correo ni teléfono). Solo se extraen los campos de esta lista.''';

/// Número entero de un texto como "3.500" o "$3.500,00" (el punto separa
/// miles en Chile). Null si no hay dígitos.
int? _entero(Object? valor) {
  if (valor == null) return null;
  var texto = valor.toString().trim();
  // Descarta decimales ("3500,00") antes de quitar separadores de miles.
  texto = texto.replaceFirst(RegExp(r'[,.]\d{1,2}$'), '');
  final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  return digitos.isEmpty ? null : int.tryParse(digitos);
}

/// Interpreta "HH:MM", "HH:MM:SS", "H.MM" o "15h30". Null si no es una hora
/// real.
HoraDelDia? interpretarHora(Object? valor) {
  final t = valor?.toString().trim().toLowerCase() ?? '';
  final m = RegExp(r'^(\d{1,2})\s*[:.h]\s*(\d{2})').firstMatch(t);
  if (m == null) return null;
  final hora = int.parse(m.group(1)!);
  final minuto = int.parse(m.group(2)!);
  if (hora > 23 || minuto > 59) return null;
  return (hora: hora, minuto: minuto);
}

/// Minutos de un texto como "95", "1:35", "1 h 35 min" o "45 min". Null si no
/// se entiende.
int? minutosDeTexto(Object? valor) {
  final t = valor?.toString().trim().toLowerCase() ?? '';
  if (t.isEmpty) return null;
  final hm = RegExp(r'^(\d{1,4})\s*:\s*(\d{2})$').firstMatch(t);
  if (hm != null) {
    return int.parse(hm.group(1)!) * 60 + int.parse(hm.group(2)!);
  }
  final conHoras =
      RegExp(r'^(\d{1,4})\s*(?:h|hr|hrs|hora|horas)\b\s*(?:(\d{1,2})\s*(?:m|min|mins|minutos)?)?$')
          .firstMatch(t);
  if (conHoras != null) {
    return int.parse(conHoras.group(1)!) * 60 +
        int.parse(conHoras.group(2) ?? '0');
  }
  final soloMin = RegExp(r'^(\d{1,6})\s*(?:m|min|mins|minutos)?$').firstMatch(t);
  return soloMin == null ? null : int.parse(soloMin.group(1)!);
}

/// Un estacionamiento no puede ser futuro (se tolera 1 día por la zona
/// horaria) ni anterior a 1990: una fecha así es casi seguro un error de
/// lectura.
DateTime? _fechaPlausible(DateTime? fecha, {DateTime? ahora}) {
  if (fecha == null) return null;
  final hoy = ahora ?? DateTime.now();
  final limite =
      DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 1));
  return (fecha.year < 1990 || fecha.isAfter(limite)) ? null : fecha;
}

/// Fecha leída por la IA, solo si es real y plausible; si no, null.
DateTime? _fecha(Object? valor, {DateTime? ahora}) {
  final t = valor?.toString().trim() ?? '';
  return t.isEmpty ? null : _fechaPlausible(interpretarFecha(t), ahora: ahora);
}

/// Texto sin espacios sobrantes y recortado a [maximo] caracteres (el
/// límite de las reglas). Null si está vacío.
String? _texto(Object? valor, int maximo) {
  final t = valor?.toString().trim() ?? '';
  if (t.isEmpty) return null;
  return t.length > maximo ? t.substring(0, maximo) : t;
}

/// Diferencia tolerada entre la duración que dice el ticket y la calculada con
/// las horas (los tickets suelen redondear al minuto o cobrar por bloques).
const int toleranciaDuracionMin = 2;

/// Interpreta el JSON de la IA. Los límites coinciden con las reglas de
/// Firestore (`estacionamientoValido`), para que lo extraído siempre se pueda
/// guardar. Un valor fuera de rango se descarta.
EstacionamientoExtraido parseEstacionamientoExtraido(
  Map<String, dynamic> json, {
  DateTime? ahora,
}) {
  final fecha = _fecha(json['fecha_entrada'], ahora: ahora);
  final fechaSalidaLeida = _fecha(json['fecha_salida'], ahora: ahora);
  // Una fecha de salida igual a la de entrada no aporta nada.
  final fechaSalida = (fechaSalidaLeida != null &&
          fecha != null &&
          fechaSalidaLeida.year == fecha.year &&
          fechaSalidaLeida.month == fecha.month &&
          fechaSalidaLeida.day == fecha.day)
      ? null
      : fechaSalidaLeida;
  final horaEntrada = interpretarHora(json['hora_entrada']);
  final horaSalida = interpretarHora(json['hora_salida']);
  final lugar = _texto(json['lugar'], 100);

  final costoLeido = _entero(json['monto_total']);
  final costo =
      (costoLeido != null && costoLeido <= 10000000) ? costoLeido : null;

  final dudosos = <String>{
    for (final c in json['campos_dudosos'] is List
        ? json['campos_dudosos'] as List
        : const [])
      if (_clavesDudosas.contains(c.toString())) c.toString(),
  };
  // La fecha es obligatoria para guardar: si no se pudo leer, se destaca.
  if (fecha == null) dudosos.add(dudosoEstFecha);

  final base = EstacionamientoExtraido(
    fecha: fecha,
    horaEntrada: horaEntrada,
    horaSalida: horaSalida,
    fechaSalida: fechaSalida,
  );
  final entrada = base.entrada;
  final salida = base.salida;

  // Salida antes que la entrada el mismo día: se asumió que pasó la
  // medianoche (ver [EstacionamientoExtraido.salida]); el usuario lo revisa.
  final cruzaMedianoche = entrada != null &&
      salida != null &&
      fechaSalida == null &&
      horaSalida != null &&
      horaEntrada != null &&
      (horaSalida.hora * 60 + horaSalida.minuto) <
          (horaEntrada.hora * 60 + horaEntrada.minuto);
  if (cruzaMedianoche) dudosos.add(dudosoEstSalida);
  // Con fecha de salida explícita anterior a la entrada: es un error de
  // lectura.
  final salidaInvalida =
      entrada != null && salida != null && salida.isBefore(entrada);
  if (salidaInvalida) dudosos.add(dudosoEstSalida);

  // Duración: la del ticket; si no trae, la calculada con las horas leídas.
  final calculada = (entrada != null && salida != null && !salidaInvalida)
      ? duracionEnMinutos(entrada, salida)
      : null;
  final leida = minutosDeTexto(json['duracion_minutos']);
  if (leida != null &&
      calculada != null &&
      (leida - calculada).abs() > toleranciaDuracionMin) {
    // No cuadran: no se elige una, se marca para que el usuario decida.
    dudosos.add(dudosoEstDuracion);
  }
  final duracionBruta = leida ?? calculada;
  final duracion = duracionBruta == null
      ? null
      : (duracionBruta > duracionMaximaMin ? duracionMaximaMin : duracionBruta);

  // Confianza: proporción de campos leídos que no quedaron dudosos.
  final leidos = <String>[
    if (lugar != null) dudosoEstLugar,
    if (fecha != null) dudosoEstFecha,
    if (horaEntrada != null) dudosoEstEntrada,
    if (horaSalida != null) dudosoEstSalida,
    if (leida != null) dudosoEstDuracion,
    if (costo != null) dudosoEstCosto,
  ];
  final confianza = leidos.isEmpty
      ? null
      : leidos.where((c) => !dudosos.contains(c)).length / leidos.length;

  return EstacionamientoExtraido(
    lugar: lugar,
    fecha: fecha,
    horaEntrada: horaEntrada,
    horaSalida: horaSalida,
    fechaSalida: fechaSalida,
    duracionMin: duracion,
    costo: costo,
    camposDudosos: dudosos,
    confianza: confianza,
  );
}

/// Lee el ticket o boleta de un estacionamiento con OpenAI (misma cascada de
/// modelos y reintentos que el Registro Inteligente, a través de la Edge
/// Function `ia-extraccion`). Lanza la excepción si la IA falla: el llamador
/// debe ofrecer el registro manual (CU19 E2).
Future<EstacionamientoExtraido> extraerEstacionamiento({
  required Uint8List bytes,
  required String mimeType,
  OpenAiExtractionService? servicio,
  void Function(String etapa)? alCambiarEtapa,
}) async {
  // Imagen reducida, con orientación corregida y en JPEG de buena calidad.
  if (imagenRequierePreparacion(bytes, mimeType)) {
    alCambiarEtapa?.call(etapaPreparandoImagen);
    await Future.delayed(const Duration(milliseconds: 80));
  }
  final preparada = await prepararImagenParaIa(bytes, mimeType);
  alCambiarEtapa?.call(etapaAnalizando);

  final respuesta = await (servicio ?? OpenAiExtractionService())
      .generarJsonConFallback(
    partes: [
      EvidenciaArchivo(preparada.mimeType, preparada.bytes),
      EvidenciaTexto(_promptEstacionamiento()),
    ],
    esquemaJson: _esquemaEstacionamiento(),
    nombreEsquema: 'estacionamiento',
  );

  final json = jsonDecode(respuesta);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Respuesta de la IA con formato inesperado.');
  }
  return parseEstacionamientoExtraido(json);
}
