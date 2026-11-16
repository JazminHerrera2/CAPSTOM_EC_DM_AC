import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/registro_auditoria.dart';

void main() {
  group('registro del panel admin', () {
    final registro = RegistroAuditoria.desde({
      'fecha': 'f',
      'adminEmail': 'admin@tagok.cl',
      'action': 'DELETE_PORTICO',
      'target': 'Pórtico P1',
      'details': 'Eliminado por error de ubicación',
    });

    test('se muestra igual que antes', () {
      expect(registro.esDeLaApp, isFalse);
      expect(registro.responsable, 'admin@tagok.cl');
      expect(registro.accion, 'DELETE_PORTICO');
      expect(registro.objetivo, 'Pórtico P1');
      expect(registro.detalle, 'Eliminado por error de ubicación');
      expect(registro.fuente, 'Panel admin');
      expect(registro.fecha, 'f');
    });

    test('sin correo de admin aparece como Sistema', () {
      expect(RegistroAuditoria.desde({'action': 'X'}).responsable, 'Sistema');
    });
  });

  group('registro de la app', () {
    final datos = {
      'usuario_id': 'uid123',
      'accion': 'CREAR',
      'tipo_entidad': 'MANTENCION',
      'entidad_id': 'man1',
      'detalle': 'Mantención realizada registrada: Frenos',
      'origen': 'ia',
    };

    test('se traduce al formato de la bitácora', () {
      final r = RegistroAuditoria.desde(
        datos,
        correosUsuarios: {'uid123': 'conductor@correo.cl'},
      );
      expect(r.esDeLaApp, isTrue);
      expect(r.responsable, 'conductor@correo.cl');
      expect(r.accion, 'CREAR');
      expect(r.objetivo, 'Mantención');
      expect(r.detalle, 'Mantención realizada registrada: Frenos');
      expect(r.fuente, 'App · IA');
    });

    test('si no se conoce el correo, muestra el uid', () {
      expect(RegistroAuditoria.desde(datos).responsable, 'Usuario uid123');
    });

    test('nombres de entidades y orígenes', () {
      expect(etiquetaEntidadAuditoria('ABASTECIMIENTO'), 'Carga de combustible');
      expect(etiquetaEntidadAuditoria('DOCUMENTO_VEHICULAR'),
          'Documento vehicular');
      expect(etiquetaEntidadAuditoria('VEHICULO'), 'Vehículo');
      expect(etiquetaEntidadAuditoria('OTRA'), 'OTRA');
      expect(etiquetaOrigenAuditoria('manual'), 'Manual');
      expect(etiquetaOrigenAuditoria('sistema'), 'Sistema');
    });
  });

  test('la búsqueda revisa responsable, objetivo, detalle y fuente', () {
    final r = RegistroAuditoria.desde({
      'usuario_id': 'u',
      'accion': 'CREAR',
      'tipo_entidad': 'ABASTECIMIENTO',
      'detalle': 'Carga de combustible registrada',
      'origen': 'manual',
    });
    expect(r.coincideCon(''), isTrue);
    expect(r.coincideCon('carga'), isTrue);
    expect(r.coincideCon('app'), isTrue);
    expect(r.coincideCon('pórtico'), isFalse);
  });
}
