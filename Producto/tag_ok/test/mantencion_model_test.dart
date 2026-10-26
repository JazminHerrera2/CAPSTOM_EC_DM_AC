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
      tipo: 'Lavado de motor',
      taller: 'Taller X',
      costo: 45000,
    );

    final json = original.toJson();
    expect(json.containsKey('archivo_path'), isFalse);
    expect(json['tipo'], 'Lavado de motor');
    expect(json['estado'], 'realizada');

    final copia = MantencionModel.fromJson(json, 'id1');
    expect(copia.uid, 'u1');
    expect(copia.vehiculoId, 'v1');
    expect(copia.tipo, 'Lavado de motor');
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
      tipo: 'Cambio de aceite',
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

  test('mantenciones antiguas: el valor de la lista anterior se ve como título',
      () {
    for (final t in TipoMantencion.values) {
      if (t == TipoMantencion.otra) continue;
      final m = MantencionModel.fromJson({'tipo': t.valorFirestore}, 'x');
      expect(m.nombreTipo, t.etiqueta);
    }
    // "otra" con su texto, y sin texto nunca queda vacío.
    expect(
        MantencionModel.fromJson({'tipo': 'otra', 'tipo_otro': 'Pulido'}, 'x')
            .nombreTipo,
        'Pulido');
    expect(MantencionModel.fromJson({'tipo': 'otra'}, 'x').nombreTipo, 'Otra');
    expect(MantencionModel.fromJson({}, 'x').nombreTipo, 'Otra');
    // Título libre: se muestra tal cual.
    expect(
        MantencionModel.fromJson({'tipo': 'Revisión de 20.000 km'}, 'x')
            .nombreTipo,
        'Revisión de 20.000 km');
  });

  test('formatoMiles', () {
    expect(formatoMiles(0), '0');
    expect(formatoMiles(999), '999');
    expect(formatoMiles(72450), '72.450');
    expect(formatoMiles(1234567), '1.234.567');
  });
}
