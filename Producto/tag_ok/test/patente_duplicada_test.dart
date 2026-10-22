import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/vehiculo_service.dart';

void main() {
  test('la misma patente se detecta aunque cambien mayúsculas o separadores', () {
    final existentes = ['KZZZ60', 'AB-1234'];
    expect(patenteYaRegistrada(existentes, 'KZZZ60'), isTrue);
    expect(patenteYaRegistrada(existentes, 'kzzz60'), isTrue);
    expect(patenteYaRegistrada(existentes, ' KZZZ 60 '), isTrue);
    expect(patenteYaRegistrada(existentes, 'ab1234'), isTrue);
    expect(patenteYaRegistrada(existentes, 'AB 12-34'), isTrue);
  });

  test('una patente distinta se permite', () {
    expect(patenteYaRegistrada(['KZZZ60'], 'BFWH37'), isFalse);
    expect(patenteYaRegistrada(const [], 'BFWH37'), isFalse);
  });

  test('una patente vacía no cuenta como duplicada', () {
    expect(patenteYaRegistrada(['', 'KZZZ60'], ''), isFalse);
    expect(patenteYaRegistrada(['', 'KZZZ60'], '--'), isFalse);
  });
}
