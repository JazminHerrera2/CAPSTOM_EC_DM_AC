import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/documento_vehicular_model.dart';
import 'package:tag_ok/utils/orden_documentos.dart';

DocumentoVehicularModel _doc(
  String id,
  DateTime? vence, {
  TipoDocumentoVehicular tipo = TipoDocumentoVehicular.soap,
}) =>
    DocumentoVehicularModel(
      id: id,
      vehiculoId: 'v1',
      tipoDocumento: tipo,
      fechaVencimiento: vence,
      origenRegistro: 'manual',
      fechaRegistro: DateTime(2026, 1, 1),
    );

void main() {
  test('el que vence primero va primero; sin fecha, al final', () {
    final r = ordenarPorVencimiento([
      _doc('lejos', DateTime(2027, 6, 1)),
      _doc('sinFecha', null),
      _doc('pronto', DateTime(2026, 11, 3)),
      _doc('medio', DateTime(2027, 1, 15)),
    ]);
    expect(r.map((d) => d.id), ['pronto', 'medio', 'lejos', 'sinFecha']);
  });

  test('los ya vencidos van antes que los vigentes', () {
    final r = ordenarPorVencimiento([
      _doc('vigente', DateTime(2027, 1, 1)),
      _doc('vencido', DateTime(2025, 12, 1)),
    ]);
    expect(r.first.id, 'vencido');
  });

  test('misma fecha: por tipo de documento; la lista original no cambia', () {
    final original = [
      _doc('seguro', DateTime(2027, 1, 1), tipo: TipoDocumentoVehicular.seguro),
      _doc('permiso', DateTime(2027, 1, 1), tipo: TipoDocumentoVehicular.permisoCirculacion),
    ];
    final r = ordenarPorVencimiento(original);
    expect(r.map((d) => d.id), ['permiso', 'seguro']);
    expect(original.first.id, 'seguro');
  });

  test('lista vacía', () {
    expect(ordenarPorVencimiento(const []), isEmpty);
  });
}
