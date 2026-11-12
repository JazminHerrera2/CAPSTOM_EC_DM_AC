import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/estacionamiento_model.dart';
import 'package:tag_ok/data/services/ubicacion_service.dart';

/// Estacionamientos (RF-016 a RF-019): modelo, duración del cronómetro,
/// distancia al auto y mensajes de error del GPS (CU18).
void main() {
  final entrada = DateTime(2026, 11, 11, 10, 30);

  group('duracionEnMinutos', () {
    test('cuenta minutos completos', () {
      expect(duracionEnMinutos(entrada, DateTime(2026, 11, 11, 12, 5)), 95);
      expect(duracionEnMinutos(entrada, entrada.add(const Duration(seconds: 59))), 0);
    });

    test('cruza la medianoche (por eso las horas guardan la fecha)', () {
      expect(
        duracionEnMinutos(DateTime(2026, 11, 11, 23, 40), DateTime(2026, 11, 12, 0, 25)),
        45,
      );
    });

    test('nunca es negativa', () {
      expect(duracionEnMinutos(entrada, entrada.subtract(const Duration(minutes: 5))), 0);
    });
  });

  group('EstacionamientoModel', () {
    test('activo (cronómetro): toJson deja la salida en null y el estado activo', () {
      final e = EstacionamientoModel(
        id: '',
        uid: 'u1',
        vehiculoId: 'v1',
        fecha: entrada,
        horaEntrada: entrada,
        estado: EstadoEstacionamiento.activo,
      );
      final json = e.toJson();
      expect(json['estado'], 'activo');
      expect(json['hora_entrada'], Timestamp.fromDate(entrada));
      expect(json['hora_salida'], isNull);
      expect(json['origen_registro'], 'manual');
      expect(json.containsKey('archivo_path'), isFalse);
    });

    test('toJson usa exactamente los campos que aceptan las reglas', () {
      final json = EstacionamientoModel(id: '', uid: 'u1', vehiculoId: 'v1', fecha: entrada)
          .toJson();
      expect(json.keys.toSet(), {
        'uid', 'vehiculo_id', 'fecha', 'lugar', 'hora_entrada', 'hora_salida',
        'duracion_min', 'costo', 'ubicacion', 'observacion', 'estado',
        'origen_registro', 'fecha_captura', 'confianza_ia',
      });
    });

    test('fromJson lee la ubicación como GeoPoint y vuelve igual en toJson', () {
      final e = EstacionamientoModel.fromJson({
        'uid': 'u1',
        'vehiculo_id': 'v1',
        'fecha': Timestamp.fromDate(entrada),
        'lugar': 'Costanera Center',
        'hora_entrada': Timestamp.fromDate(entrada),
        'hora_salida': Timestamp.fromDate(DateTime(2026, 11, 11, 12, 5)),
        'duracion_min': 95,
        'costo': 3500,
        'ubicacion': const GeoPoint(-33.417, -70.606),
        'estado': 'finalizado',
        'origen_registro': 'ia',
        'confianza_ia': 88,
      }, 'e1');
      expect(e.id, 'e1');
      expect(e.estaActivo, isFalse);
      expect(e.tieneUbicacion, isTrue);
      expect(e.ubicacion, const GeoPoint(-33.417, -70.606));
      expect(e.costo, 3500);
      expect(e.confianzaIa, 88.0);
      expect(e.toJson()['ubicacion'], const GeoPoint(-33.417, -70.606));
    });

    test('un estado desconocido o ausente se lee como finalizado (nunca queda abierto)', () {
      final e = EstacionamientoModel.fromJson({'vehiculo_id': 'v1', 'estado': 'raro'}, 'x');
      expect(e.estado, EstadoEstacionamiento.finalizado);
      expect(e.titulo, 'Estacionamiento');
    });

    test('minutosTranscurridos: activo cuenta hasta ahora; finalizado usa lo guardado', () {
      final activo = EstacionamientoModel(
        id: 'a', vehiculoId: 'v1', fecha: entrada, horaEntrada: entrada,
        estado: EstadoEstacionamiento.activo,
      );
      expect(activo.minutosTranscurridos(ahora: DateTime(2026, 11, 11, 11, 0)), 30);

      final terminado = EstacionamientoModel(
        id: 'f', vehiculoId: 'v1', fecha: entrada, horaEntrada: entrada,
        horaSalida: DateTime(2026, 11, 11, 11, 0),
      );
      expect(terminado.minutosTranscurridos(), 30);
      expect(
        EstacionamientoModel(id: 'g', vehiculoId: 'v1', fecha: entrada, duracionMin: 12)
            .minutosTranscurridos(),
        12,
      );
      expect(EstacionamientoModel(id: 'h', vehiculoId: 'v1', fecha: entrada)
          .minutosTranscurridos(), isNull);
    });
  });

  group('distancia al auto', () {
    test('distanciaEnMetros: mismo punto es 0 y ~111 m por milésima de latitud', () {
      const auto = GeoPoint(-33.4170, -70.6060);
      expect(distanciaEnMetros(auto, auto), 0);
      final d = distanciaEnMetros(auto, const GeoPoint(-33.4180, -70.6060));
      expect(d, closeTo(111, 2));
    });

    test('textoDistancia: metros bajo 1 km y kilómetros con coma', () {
      expect(textoDistancia(230.4), 'a 230 m');
      expect(textoDistancia(999), 'a 999 m');
      expect(textoDistancia(1430), 'a 1,4 km');
    });
  });

  group('errores de ubicación (CU18 E1 y E2)', () {
    test('cada motivo tiene un mensaje distinto para el usuario', () {
      final mensajes = MotivoErrorUbicacion.values.map(mensajeErrorUbicacion).toSet();
      expect(mensajes.length, MotivoErrorUbicacion.values.length);
      expect(mensajeErrorUbicacion(MotivoErrorUbicacion.permisoBloqueado), contains('ajustes'));
      expect(const ErrorUbicacion(MotivoErrorUbicacion.gpsDesactivado).mensaje,
          contains('Activa la ubicación'));
    });
  });
}
