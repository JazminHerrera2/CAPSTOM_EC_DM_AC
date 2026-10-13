import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/recordatorio_local_service.dart';

void main() {
  group('idNotificacionLocal', () {
    test('es estable y positivo de 31 bits', () {
      final a = idNotificacionLocal('doc123_30dias');
      expect(a, idNotificacionLocal('doc123_30dias'));
      expect(a, inInclusiveRange(0, 0x7FFFFFFF));
    });

    test('distingue los tres avisos de un mismo documento', () {
      final ids = {
        idNotificacionLocal('doc123_30dias'),
        idNotificacionLocal('doc123_15dias'),
        idNotificacionLocal('doc123_7dias'),
      };
      expect(ids.length, 3);
    });
  });

  group('momentoDeAviso', () {
    final ahora = DateTime(2026, 10, 12, 14, 30);

    test('día futuro: ese día a las 9:00', () {
      expect(
        momentoDeAviso(DateTime(2026, 10, 20), ahora),
        DateTime(2026, 10, 20, horaAvisoVencimiento),
      );
    });

    test('hoy antes de las 9:00: hoy a las 9:00', () {
      expect(
        momentoDeAviso(DateTime(2026, 10, 12), DateTime(2026, 10, 12, 7)),
        DateTime(2026, 10, 12, horaAvisoVencimiento),
      );
    });

    test('hoy pasadas las 9:00: casi inmediato', () {
      final m = momentoDeAviso(DateTime(2026, 10, 12), ahora)!;
      expect(m.isAfter(ahora), isTrue);
      expect(m.difference(ahora).inMinutes, lessThan(1));
    });

    test('día pasado: no se avisa', () {
      expect(momentoDeAviso(DateTime(2026, 10, 11), ahora), isNull);
    });
  });
}
