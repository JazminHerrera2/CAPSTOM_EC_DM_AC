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

  test('tipos y títulos de aviso', () {
    expect(tiposAvisoEntregables,
        containsAll([tipoAvisoVencimientoDocumento, tipoAvisoMantencion]));
    expect(tituloAviso(tipoAvisoMantencion), 'Mantención programada');
    expect(tituloAviso(tipoAvisoVencimientoDocumento), 'Documento por vencer');
  });
}
