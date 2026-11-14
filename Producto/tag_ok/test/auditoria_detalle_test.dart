import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/abastecimiento_model.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/data/services/auditoria_service.dart';

/// Textos que la app deja en `auditoria` (RF-054) y que ve el panel admin.
void main() {
  group('mantenciones', () {
    test('realizada manual', () {
      expect(
        detalleAuditoriaMantencionCreada(
          estado: EstadoMantencion.realizada,
          nombre: 'Cambio de aceite',
          origen: 'manual',
        ),
        'Mantención realizada registrada: Cambio de aceite',
      );
    });

    test('realizada con IA indica que el usuario la revisó', () {
      expect(
        detalleAuditoriaMantencionCreada(
          estado: EstadoMantencion.realizada,
          nombre: 'Frenos',
          origen: 'ia',
        ),
        'Mantención realizada registrada con IA (revisada y confirmada por '
        'el usuario): Frenos',
      );
    });

    test('programada y eliminada', () {
      expect(
        detalleAuditoriaMantencionCreada(
          estado: EstadoMantencion.programada,
          nombre: 'Frenos',
          origen: 'manual',
        ),
        'Mantención programada registrada: Frenos',
      );
      expect(
        detalleAuditoriaMantencionEliminada(
          estado: EstadoMantencion.programada,
          nombre: 'Frenos',
        ),
        'Mantención programada eliminada: Frenos',
      );
    });
  });

  group('cargas', () {
    test('combustible manual y carga eléctrica con IA', () {
      expect(
        detalleAuditoriaAbastecimientoCreado(
          tipo: TipoAbastecimiento.combustible,
          origen: 'manual',
        ),
        'Carga de combustible registrada',
      );
      expect(
        detalleAuditoriaAbastecimientoCreado(
          tipo: TipoAbastecimiento.cargaElectrica,
          origen: 'ia',
        ),
        'Carga eléctrica registrada con IA (revisada y confirmada por el '
        'usuario)',
      );
    });
  });

  test('las entidades caben en la regla de Firestore (máx. 60)', () {
    expect(entidadAuditoriaMantencion.length, lessThanOrEqualTo(60));
    expect(entidadAuditoriaAbastecimiento.length, lessThanOrEqualTo(60));
  });
}
