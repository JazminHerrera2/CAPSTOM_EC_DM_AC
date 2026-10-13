import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_ok/data/models/notificacion_config_model.dart';
import 'package:tag_ok/data/services/aviso_navegador_service.dart';

NotificacionConfigModel aviso(
  String id,
  DateTime? fecha, {
  bool leida = false,
  String estado = 'pendiente',
  String tipo = 'vencimiento_documento',
}) =>
    NotificacionConfigModel(
      id: id,
      usuarioId: 'u1',
      tipo: tipo,
      mensaje: 'Recordatorio: $id',
      fechaProgramada: fecha,
      fechaGeneracion: DateTime(2026, 1, 1),
      leida: leida,
      estado: estado,
    );

void main() {
  final tarde = DateTime(2026, 10, 12, 14);
  final temprano = DateTime(2026, 10, 12, 7);

  group('avisoListoParaNavegador', () {
    test('hoy: solo después de las 9:00', () {
      final a = aviso('a', DateTime(2026, 10, 12));
      expect(avisoListoParaNavegador(a, tarde), isTrue);
      expect(avisoListoParaNavegador(a, temprano), isFalse);
    });

    test('día pasado sin leer: listo a cualquier hora', () {
      expect(
        avisoListoParaNavegador(aviso('a', DateTime(2026, 10, 10)), temprano),
        isTrue,
      );
    });

    test('día futuro, leído o no pendiente: no', () {
      expect(avisoListoParaNavegador(aviso('a', DateTime(2026, 10, 13)), tarde), isFalse);
      expect(avisoListoParaNavegador(aviso('a', DateTime(2026, 10, 12), leida: true), tarde), isFalse);
      expect(avisoListoParaNavegador(aviso('a', DateTime(2026, 10, 12), estado: 'leida'), tarde), isFalse);
    });
  });

  group('mostrarPendientes', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('muestra cada aviso una sola vez', () async {
      final avisos = [
        aviso('d_7dias', DateTime(2026, 10, 12)),
        aviso('d_15dias', DateTime(2026, 10, 20)),
        aviso('x', DateTime(2026, 10, 12), tipo: 'otro'),
      ];
      final svc = AvisoNavegadorService.instance;
      expect(await svc.mostrarPendientes(avisos, tarde), 1);
      expect(await svc.mostrarPendientes(avisos, tarde), 0);
    });

    test('si cambia la fecha programada, vuelve a avisar', () async {
      final svc = AvisoNavegadorService.instance;
      expect(await svc.mostrarPendientes([aviso('d_7dias', DateTime(2026, 10, 12))], tarde), 1);
      expect(await svc.mostrarPendientes([aviso('d_7dias', DateTime(2026, 10, 11))], tarde), 1);
    });
  });
}
