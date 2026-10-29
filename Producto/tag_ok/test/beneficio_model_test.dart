import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/beneficio_model.dart';

BeneficioModel _b(
  String id, {
  String? titulo,
  CategoriaBeneficio? categoria = CategoriaBeneficio.talleres,
  String? ubicacion,
  DateTime? inicio,
  DateTime? fin,
  bool destacado = false,
  bool activo = true,
}) =>
    BeneficioModel(
      id: id,
      titulo: titulo ?? id,
      categoria: categoria,
      ubicacion: ubicacion,
      fechaInicio: inicio,
      fechaFin: fin,
      destacado: destacado,
      activo: activo,
    );

void main() {
  final hoy = DateTime(2026, 10, 28, 15, 30);

  group('CategoriaBeneficio', () {
    test('tiene las 8 categorías de RF-034 más "Otros"', () {
      expect(CategoriaBeneficio.values.map((c) => c.etiqueta), [
        'Combustible',
        'Talleres',
        'Mantenciones',
        'Estacionamientos',
        'Lavado',
        'Neumáticos',
        'Seguros',
        'Accesorios',
        'Otros',
      ]);
    });

    test('"Otros" muestra el texto libre; sin texto, "Otros"', () {
      final conTexto = BeneficioModel.fromJson(
        {'titulo': 'X', 'categoria': 'Otros', 'categoria_otra': ' Lavado a domicilio '},
        'a',
      );
      expect(conTexto.categoria, CategoriaBeneficio.otros);
      expect(conTexto.etiquetaCategoria, 'Lavado a domicilio');
      expect(conTexto.toJson()['categoria_otra'], 'Lavado a domicilio');

      final sinTexto = BeneficioModel.fromJson({'titulo': 'X', 'categoria': 'Otros'}, 'b');
      expect(sinTexto.etiquetaCategoria, 'Otros');
      expect(sinTexto.toJson().containsKey('categoria_otra'), isFalse);
    });

    test('categoria_otra se ignora si la categoría no es "Otros"', () {
      final b = BeneficioModel.fromJson(
        {'titulo': 'X', 'categoria': 'Talleres', 'categoria_otra': 'algo'},
        'c',
      );
      expect(b.etiquetaCategoria, 'Talleres');
      expect(b.toJson().containsKey('categoria_otra'), isFalse);
    });

    test('desdeEtiqueta ignora mayúsculas/espacios y devuelve null si no existe', () {
      expect(CategoriaBeneficio.desdeEtiqueta(' neumáticos '),
          CategoriaBeneficio.neumaticos);
      expect(CategoriaBeneficio.desdeEtiqueta('Otra'), isNull);
      expect(CategoriaBeneficio.desdeEtiqueta(null), isNull);
      expect(CategoriaBeneficio.desdeEtiqueta(5), isNull);
    });
  });

  group('fromJson / toJson', () {
    test('defaults: destacado=false y activo=true cuando faltan', () {
      final b = BeneficioModel.fromJson({'titulo': 'X'}, 'id1');
      expect(b.id, 'id1');
      expect(b.destacado, isFalse);
      expect(b.activo, isTrue);
    });

    test('es tolerante con campos ausentes o de tipo inesperado', () {
      final b = BeneficioModel.fromJson({
        'titulo': 42,
        'categoria': 'Inexistente',
        'fecha_fin': 'no-es-timestamp',
        'descripcion': '   ',
      }, 'id2');
      expect(b.titulo, 'Beneficio');
      expect(b.categoria, isNull);
      expect(b.fechaFin, isNull);
      expect(b.descripcion, isNull);
    });

    test('ida y vuelta conserva los datos y no escribe opcionales vacíos', () {
      final original = BeneficioModel(
        id: 'a',
        titulo: 'Descuento',
        categoria: CategoriaBeneficio.lavado,
        empresa: 'Lavaútil',
        urlExterna: 'https://ejemplo.cl',
        fechaFin: DateTime(2026, 12, 31),
        destacado: true,
      );
      final json = original.toJson();
      expect(json.containsKey('descripcion'), isFalse);
      expect(json['categoria'], 'Lavado');
      expect(json['fecha_fin'], isA<Timestamp>());

      final copia = BeneficioModel.fromJson(json, 'a');
      expect(copia.titulo, 'Descuento');
      expect(copia.categoria, CategoriaBeneficio.lavado);
      expect(copia.destacado, isTrue);
      expect(copia.fechaFin, DateTime(2026, 12, 31));
    });
  });

  group('vigencia', () {
    test('sin fechas siempre es vigente', () {
      expect(_b('a').estaVigente(hoy), isTrue);
    });

    test('el día de inicio y el de fin cuentan como vigentes', () {
      expect(_b('a', inicio: DateTime(2026, 10, 28)).estaVigente(hoy), isTrue);
      expect(_b('a', fin: DateTime(2026, 10, 28)).estaVigente(hoy), isTrue);
    });

    test('futuro (aún no parte) y vencido no son vigentes', () {
      expect(_b('a', inicio: DateTime(2026, 10, 29)).estaVigente(hoy), isFalse);
      expect(_b('a', fin: DateTime(2026, 10, 27)).estaVigente(hoy), isFalse);
    });

    test('inactivo no es visible aunque esté vigente', () {
      expect(_b('a', activo: false).visibleParaConductor(hoy), isFalse);
      expect(_b('a').visibleParaConductor(hoy), isTrue);
    });

    test('vencePronto: dentro de 30 días sí, después o sin fin no', () {
      expect(_b('a', fin: DateTime(2026, 11, 27)).vencePronto(hoy), isTrue);
      expect(_b('a', fin: DateTime(2026, 11, 28)).vencePronto(hoy), isFalse);
      expect(_b('a').vencePronto(hoy), isFalse);
      expect(_b('a', fin: DateTime(2026, 10, 1)).vencePronto(hoy), isFalse);
    });
  });

  group('catalogoParaConductor', () {
    test('excluye inactivos, vencidos y futuros', () {
      final r = catalogoParaConductor([
        _b('ok'),
        _b('inactivo', activo: false),
        _b('vencido', fin: DateTime(2026, 1, 1)),
        _b('futuro', inicio: DateTime(2027, 1, 1)),
      ], ahora: hoy);
      expect(r.map((b) => b.id), ['ok']);
    });

    test('destacados primero; luego fin más cercano; sin fin al final; luego título', () {
      final r = catalogoParaConductor([
        _b('sinFin', titulo: 'A sin fin'),
        _b('lejos', fin: DateTime(2026, 12, 31)),
        _b('cerca', fin: DateTime(2026, 11, 5)),
        _b('dest', titulo: 'Z destacado', destacado: true),
      ], ahora: hoy);
      expect(r.map((b) => b.id), ['dest', 'cerca', 'lejos', 'sinFin']);
    });

    test('filtra por categoría', () {
      final r = catalogoParaConductor([
        _b('t', categoria: CategoriaBeneficio.talleres),
        _b('s', categoria: CategoriaBeneficio.seguros),
      ],
          filtro: const FiltroBeneficios(categoria: CategoriaBeneficio.seguros),
          ahora: hoy);
      expect(r.map((b) => b.id), ['s']);
    });

    test('filtra por ubicación sin distinguir tildes ni mayúsculas', () {
      final r = catalogoParaConductor([
        _b('stgo', ubicacion: 'Santiago, Región Metropolitana'),
        _b('conce', ubicacion: 'Concepción'),
        _b('nada'),
      ],
          filtro: const FiltroBeneficios(ubicacion: 'CONCEPCION'),
          ahora: hoy);
      expect(r.map((b) => b.id), ['conce']);
    });

    test('filtro porVencer deja solo los que terminan pronto', () {
      final r = catalogoParaConductor([
        _b('pronto', fin: DateTime(2026, 11, 10)),
        _b('lejos', fin: DateTime(2027, 6, 1)),
        _b('sinFin'),
      ],
          filtro: const FiltroBeneficios(vigencia: FiltroVigencia.porVencer),
          ahora: hoy);
      expect(r.map((b) => b.id), ['pronto']);
    });

    test('catálogo vacío devuelve lista vacía y no muta la entrada', () {
      expect(catalogoParaConductor(const [], ahora: hoy), isEmpty);
      final entrada = [_b('b'), _b('a', destacado: true)];
      catalogoParaConductor(entrada, ahora: hoy);
      expect(entrada.map((b) => b.id), ['b', 'a']);
    });
  });
}
