import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/data/models/tipo_mantencion.dart';
import 'package:tag_ok/screens/mantenimiento/tarjeta_mantencion.dart';

void main() {
  test('toJson/fromJson conserva los datos y no incluye archivo_path', () {
    final original = MantencionModel(
      id: '',
      uid: 'u1',
      vehiculoId: 'v1',
      estado: EstadoMantencion.realizada,
      fecha: DateTime(2026, 10, 1),
      kilometraje: 72450,
      tipo: TipoMantencion.otra,
      tipoOtro: 'Lavado de motor',
      taller: 'Taller X',
      costo: 45000,
    );

    final json = original.toJson();
    expect(json.containsKey('archivo_path'), isFalse);
    expect(json['tipo'], 'otra');
    expect(json['estado'], 'realizada');

    final copia = MantencionModel.fromJson(json, 'id1');
    expect(copia.uid, 'u1');
    expect(copia.vehiculoId, 'v1');
    expect(copia.tipo, TipoMantencion.otra);
    expect(copia.nombreTipo, 'Lavado de motor');
    expect(copia.kilometraje, 72450);
    expect(copia.costo, 45000);
    expect(copia.fecha, DateTime(2026, 10, 1));
  });

  test('comprobante: se guarda tipo y número, y se arma la referencia', () {
    final conBoleta = MantencionModel(
      id: '',
      vehiculoId: 'v1',
      estado: EstadoMantencion.realizada,
      tipo: TipoMantencion.cambioAceite,
      tipoComprobante: TipoComprobante.boleta,
      numeroComprobante: '458123',
    );
    final json = conBoleta.toJson();
    expect(json['tipo_comprobante'], 'boleta');
    expect(json['numero_comprobante'], '458123');

    final copia = MantencionModel.fromJson(json, 'id1');
    expect(copia.tipoComprobante, TipoComprobante.boleta);
    expect(copia.referenciaComprobante, 'Boleta N° 458123');

    // Documentos anteriores a estos campos: sin comprobante.
    final antigua = MantencionModel.fromJson({
      'vehiculo_id': 'v1',
      'estado': 'realizada',
      'tipo': 'frenos',
    }, 'id2');
    expect(antigua.tipoComprobante, isNull);
    expect(antigua.referenciaComprobante, isNull);

    final otroSinNumero = MantencionModel.fromJson({
      'tipo': 'bateria',
      'tipo_comprobante': 'otro',
    }, 'id3');
    expect(otroSinNumero.referenciaComprobante, 'Otro');
  });

  test('los 11 tipos son únicos y se resuelven por etiqueta y por valor', () {
    expect(TipoMantencion.values.length, 11);
    expect(TipoMantencion.etiquetas.toSet().length, 11);
    for (final t in TipoMantencion.values) {
      expect(TipoMantencion.fromEtiqueta(t.etiqueta), t);
      expect(TipoMantencion.fromFirestore(t.valorFirestore), t);
    }
  });

  test('formatoMiles', () {
    expect(formatoMiles(0), '0');
    expect(formatoMiles(999), '999');
    expect(formatoMiles(72450), '72.450');
    expect(formatoMiles(1234567), '1.234.567');
  });
}
