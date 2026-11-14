import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/notificacion_config_model.dart';
import 'package:tag_ok/data/services/notificacion_service.dart';
import 'package:tag_ok/data/services/recordatorio_local_service.dart';

void main() {
  group('avisosMantencion (RF-012)', () {
    final avisos = avisosMantencion(
      mantencionId: 'man1',
      nombreMantencion: 'Cambio de aceite',
      proximaFecha: DateTime(2026, 10, 30),
      patente: 'PRUE01',
    );

    test('7 días antes y el mismo día', () {
      expect(avisos.length, 2);
      expect(avisos[0].id, 'man1_7dias');
      expect(avisos[0].fechaProgramada, DateTime(2026, 10, 23));
      expect(avisos[1].id, 'man1_dia');
      expect(avisos[1].fechaProgramada, DateTime(2026, 10, 30));
    });

    test('el mensaje nombra la mantención y la patente', () {
      expect(avisos[0].mensaje,
          'Mantención programada en 7 días: Cambio de aceite (PRUE01).');
      expect(avisos[1].mensaje,
          'Hoy tienes una mantención programada: Cambio de aceite (PRUE01).');
    });

    test('sin patente, el mensaje no muestra paréntesis vacíos', () {
      final sinPatente = avisosMantencion(
        mantencionId: 'man2',
        nombreMantencion: 'Batería',
        proximaFecha: DateTime(2026, 11, 5),
      );
      expect(sinPatente[0].mensaje, 'Mantención programada en 7 días: Batería.');
    });

    test('los ids coinciden con los sufijos que se borran', () {
      expect(
        avisos.map((a) => a.id).toList(),
        sufijosAvisoMantencion.map((s) => 'man1_$s').toList(),
      );
    });

    test('los dos avisos tienen id local distinto', () {
      expect(
        idNotificacionLocal(avisos[0].id),
        isNot(idNotificacionLocal(avisos[1].id)),
      );
    });
  });

  group('avisoMantencionKm (HU-11/HU-48)', () {
    final ahora = DateTime(2026, 11, 8, 15, 30);
    AvisoProgramado? aviso(int kmActual, {String? patente = 'PRUE01'}) =>
        avisoMantencionKm(
          mantencionId: 'man1',
          nombreMantencion: 'Cambio de aceite',
          proximoKilometraje: 75000,
          kilometrajeActual: kmActual,
          ahora: ahora,
          patente: patente,
        );

    test('con más de 1.000 km por delante todavía no se avisa', () {
      expect(margenAvisoKilometraje, 1000);
      expect(aviso(60000), isNull);
      expect(aviso(73999), isNull);
    });

    test('a 1.000 km o menos avisa que se acerca', () {
      final a = aviso(74000)!;
      expect(a.id, 'man1_km_cerca');
      expect(a.mensaje,
          'Faltan 1.000 km para la mantención Cambio de aceite (PRUE01) '
          '(a los 75.000 km).');
      expect(aviso(74900)!.mensaje, startsWith('Faltan 100 km'));
    });

    test('al llegar o pasar el km programado avisa que toca', () {
      final a = aviso(75000)!;
      expect(a.id, 'man1_km_alcanzado');
      expect(a.mensaje,
          'Tu vehículo llegó a los 75.000 km: toca la mantención '
          'Cambio de aceite (PRUE01).');
      expect(aviso(80500)!.id, 'man1_km_alcanzado');
    });

    test('el aviso queda para el momento en que sube el km', () {
      expect(aviso(74500)!.fechaProgramada, ahora);
    });

    test('sin patente, el mensaje no muestra paréntesis vacíos', () {
      expect(aviso(75000, patente: null)!.mensaje,
          'Tu vehículo llegó a los 75.000 km: toca la mantención '
          'Cambio de aceite.');
    });

    test('los ids coinciden con los sufijos que se borran', () {
      expect(
        [aviso(74500)!.id, aviso(75000)!.id],
        sufijosAvisoMantencionKm.map((s) => 'man1_$s').toList(),
      );
    });
  });

  test('tipos y títulos de aviso', () {
    expect(
        tiposAvisoEntregables,
        containsAll([
          tipoAvisoVencimientoDocumento,
          tipoAvisoMantencion,
          tipoAvisoMantencionKm,
        ]));
    expect(tituloAviso(tipoAvisoMantencion), 'Mantención programada');
    expect(tituloAviso(tipoAvisoMantencionKm), 'Mantención por kilometraje');
    expect(tituloAviso(tipoAvisoVencimientoDocumento), 'Documento por vencer');
    expect(esAvisoDeMantencion(tipoAvisoMantencion), isTrue);
    expect(esAvisoDeMantencion(tipoAvisoMantencionKm), isTrue);
    expect(esAvisoDeMantencion(tipoAvisoVencimientoDocumento), isFalse);
  });
}
