import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/estacionamiento_model.dart';
import 'package:tag_ok/features/registro_inteligente/estacionamiento_extraction.dart';

/// Registro de estacionamiento con IA (HU-19 a HU-21): interpretación de la
/// respuesta de la IA. Sin red: las respuestas son simuladas.
void main() {
  final ahora = DateTime(2026, 11, 12, 18, 0);

  Map<String, dynamic> respuesta({
    Object? lugar = 'Mall Plaza Egaña',
    Object? fechaEntrada = '2026-11-11',
    Object? horaEntrada = '10:30',
    Object? fechaSalida,
    Object? horaSalida = '12:05',
    Object? duracion,
    Object? monto = '3.500',
    List<String> dudosos = const [],
  }) =>
      {
        'lugar': lugar,
        'fecha_entrada': fechaEntrada,
        'hora_entrada': horaEntrada,
        'fecha_salida': fechaSalida,
        'hora_salida': horaSalida,
        'duracion_minutos': duracion,
        'monto_total': monto,
        'campos_dudosos': dudosos,
      };

  group('interpretarHora y minutosDeTexto', () {
    test('horas en los formatos habituales; las imposibles se descartan', () {
      expect(interpretarHora('10:30'), (hora: 10, minuto: 30));
      expect(interpretarHora('09:05:59'), (hora: 9, minuto: 5));
      expect(interpretarHora('15.45'), (hora: 15, minuto: 45));
      expect(interpretarHora('15h30'), (hora: 15, minuto: 30));
      expect(interpretarHora('25:00'), isNull);
      expect(interpretarHora('10:75'), isNull);
      expect(interpretarHora(null), isNull);
    });

    test('duraciones en minutos, H:MM o con unidades', () {
      expect(minutosDeTexto('95'), 95);
      expect(minutosDeTexto('1:35'), 95);
      expect(minutosDeTexto('1 h 35 min'), 95);
      expect(minutosDeTexto('2 horas'), 120);
      expect(minutosDeTexto('45 min'), 45);
      expect(minutosDeTexto('mucho'), isNull);
      expect(minutosDeTexto(''), isNull);
    });
  });

  group('parseEstacionamientoExtraido', () {
    test('ticket completo: arma entrada y salida, calcula la duración y lee el monto', () {
      final d = parseEstacionamientoExtraido(respuesta(), ahora: ahora);
      expect(d.lugar, 'Mall Plaza Egaña');
      expect(d.entrada, DateTime(2026, 11, 11, 10, 30));
      expect(d.salida, DateTime(2026, 11, 11, 12, 5));
      expect(d.duracionMin, 95);
      expect(d.costo, 3500, reason: 'el punto separa los miles');
      expect(d.camposDudosos, isEmpty);
      expect(d.confianza, 1.0);
      expect(d.vacia, isFalse);
    });

    test('la duración del ticket se respeta si cuadra con las horas (tolerancia de 2 min)', () {
      final d = parseEstacionamientoExtraido(respuesta(duracion: '1:36'), ahora: ahora);
      expect(d.duracionMin, 96);
      expect(d.camposDudosos, isNot(contains(dudosoEstDuracion)));
    });

    test('si la duración del ticket no cuadra con las horas, se marca como dudosa', () {
      final d = parseEstacionamientoExtraido(respuesta(duracion: '45'), ahora: ahora);
      expect(d.duracionMin, 45, reason: 'se muestra la del ticket, pero resaltada');
      expect(d.camposDudosos, contains(dudosoEstDuracion));
      expect(d.confianza, lessThan(1));
    });

    test('ticket de entrada (sin salida): todo lo demás se lee y la salida queda vacía', () {
      final d = parseEstacionamientoExtraido(
        respuesta(horaSalida: null, monto: null),
        ahora: ahora,
      );
      expect(d.entrada, DateTime(2026, 11, 11, 10, 30));
      expect(d.salida, isNull);
      expect(d.duracionMin, isNull);
      expect(d.costo, isNull);
      expect(d.camposDudosos, isEmpty);
    });

    test('salida antes que la entrada sin fecha de salida: se asume medianoche y se marca', () {
      final d = parseEstacionamientoExtraido(
        respuesta(horaEntrada: '23:40', horaSalida: '00:25'),
        ahora: ahora,
      );
      expect(d.salida, DateTime(2026, 11, 12, 0, 25));
      expect(d.duracionMin, 45);
      expect(d.camposDudosos, contains(dudosoEstSalida));
    });

    test('con fecha de salida explícita se usa esa fecha', () {
      final d = parseEstacionamientoExtraido(
        respuesta(horaEntrada: '22:00', fechaSalida: '12/11/2026', horaSalida: '08:00'),
        ahora: ahora,
      );
      expect(d.fechaSalida, DateTime(2026, 11, 12));
      expect(d.salida, DateTime(2026, 11, 12, 8, 0));
      expect(d.duracionMin, 600);
      expect(d.camposDudosos, isEmpty);
    });

    test('fecha de salida explícita anterior a la entrada: salida dudosa y sin duración calculada', () {
      final d = parseEstacionamientoExtraido(
        respuesta(fechaSalida: '2026-11-10', horaSalida: '09:00'),
        ahora: ahora,
      );
      expect(d.camposDudosos, contains(dudosoEstSalida));
      expect(d.duracionMin, isNull);
    });

    test('fecha chilena día/mes/año; fecha futura o ilegible se descarta y se marca', () {
      expect(parseEstacionamientoExtraido(respuesta(fechaEntrada: '05/03/2026'), ahora: ahora).fecha,
          DateTime(2026, 3, 5));
      final futura = parseEstacionamientoExtraido(respuesta(fechaEntrada: '2027-01-01'), ahora: ahora);
      expect(futura.fecha, isNull);
      expect(futura.entrada, isNull, reason: 'sin fecha no se puede armar la hora completa');
      expect(futura.horaEntrada, (hora: 10, minuto: 30), reason: 'la hora leída se conserva para la revisión');
      expect(futura.camposDudosos, contains(dudosoEstFecha));
    });

    test('solo tarifa, sin total pagado: el monto queda vacío (no se calcula)', () {
      final d = parseEstacionamientoExtraido(respuesta(monto: null), ahora: ahora);
      expect(d.costo, isNull);
    });

    test('valores fuera de los límites de las reglas se descartan o se topan', () {
      final d = parseEstacionamientoExtraido(
        respuesta(monto: '99.999.999', duracion: '60000', horaEntrada: null, horaSalida: null),
        ahora: ahora,
      );
      expect(d.costo, isNull, reason: 'máximo 10.000.000');
      expect(d.duracionMin, duracionMaximaMin, reason: 'tope de 30 días');
      final largo = parseEstacionamientoExtraido(respuesta(lugar: 'x' * 150), ahora: ahora);
      expect(largo.lugar!.length, 100);
    });

    test('campos dudosos de la IA: solo se aceptan las claves conocidas', () {
      final d = parseEstacionamientoExtraido(
        respuesta(dudosos: ['costo', 'patente', 'inventado']),
        ahora: ahora,
      );
      expect(d.camposDudosos, {dudosoEstCosto});
      expect(d.confianza, closeTo(4 / 5, 0.001), reason: '5 campos leídos, 1 dudoso');
    });

    test('respuesta vacía: no se leyó nada y la fecha queda marcada', () {
      final d = parseEstacionamientoExtraido({
        'lugar': null, 'fecha_entrada': null, 'hora_entrada': null,
        'fecha_salida': null, 'hora_salida': null, 'duracion_minutos': null,
        'monto_total': null, 'campos_dudosos': <String>[],
      }, ahora: ahora);
      expect(d.vacia, isTrue);
      expect(d.confianza, isNull);
      expect(d.camposDudosos, {dudosoEstFecha});
    });
  });
}
