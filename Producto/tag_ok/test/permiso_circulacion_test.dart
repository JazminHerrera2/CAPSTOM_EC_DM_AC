import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/documento_vehicular_model.dart';
import 'package:tag_ok/features/registro_inteligente/document_type.dart';
import 'package:tag_ok/features/registro_inteligente/extraction_schema_registry.dart';
import 'package:tag_ok/features/registro_inteligente/validacion_campos.dart';
import 'package:tag_ok/utils/permiso_circulacion.dart';

void main() {
  final hoy = DateTime(2026, 10, 22, 15, 30);

  group('resolverFechaEmision', () {
    test('solo el año: usa la fecha de ingreso (22/10/2026) y queda estimada', () {
      final r = resolverFechaEmision(anioLeido: 2026, fechaIngreso: hoy);
      expect(r!.fecha, DateTime(2026, 10, 22));
      expect(r.estimada, isTrue);
    });

    test('fecha completa en el documento: se usa tal cual, no estimada', () {
      final r = resolverFechaEmision(
        fechaLeida: DateTime(2026, 3, 5),
        anioLeido: 2026,
        fechaIngreso: hoy,
      );
      expect(r!.fecha, DateTime(2026, 3, 5));
      expect(r.estimada, isFalse);
    });

    test('sin fecha ni año: no inventa nada', () {
      expect(resolverFechaEmision(fechaIngreso: hoy), isNull);
    });
  });

  test('la IA recibe el año del permiso como campo auxiliar, solo para el permiso', () {
    final esquema = buildCombinedSchema([DocumentType.permisoCirculacion]);
    expect((esquema['properties'] as Map).containsKey(claveAnioPermiso), isTrue);
    expect(buildExtractionPrompt([DocumentType.permisoCirculacion]),
        contains('Año del permiso'));

    final sinPermiso = buildCombinedSchema([DocumentType.soap]);
    expect((sinPermiso['properties'] as Map).containsKey(claveAnioPermiso),
        isFalse);
    // No es un campo del formulario de revisión.
    expect(
      extractionSchemas[DocumentType.permisoCirculacion]!.campos
          .any((c) => c.clave == claveAnioPermiso),
      isFalse,
    );
  });

  test('documento antiguo sin el campo nuevo: no estimada y no se escribe', () {
    final antiguo = DocumentoVehicularModel(
      id: '',
      vehiculoId: 'v1',
      tipoDocumento: TipoDocumentoVehicular.permisoCirculacion,
      origenRegistro: 'ia',
      fechaRegistro: DateTime(2026, 10, 22),
    );
    expect(antiguo.fechaEmisionEstimada, isFalse);
    expect(antiguo.toJson().containsKey('fecha_emision_estimada'), isFalse);

    final estimado = DocumentoVehicularModel(
      id: '',
      vehiculoId: 'v1',
      tipoDocumento: TipoDocumentoVehicular.permisoCirculacion,
      fechaEmision: DateTime(2026, 10, 22),
      fechaEmisionEstimada: true,
      origenRegistro: 'ia',
      fechaRegistro: DateTime(2026, 10, 22),
    );
    expect(estimado.toJson()['fecha_emision_estimada'], isTrue);
  });
}

void mainFormatoFecha() {
  test('las fechas se muestran como día/mes/año y se guardan como año-mes-día', () {
    expect(formatoFechaCl(DateTime(2026, 10, 22)), '22/10/2026');
    expect(formatoFechaCl(DateTime(2027, 3, 5)), '05/03/2027');
    expect(formatoIsoFecha(DateTime(2027, 3, 5)), '2027-03-05');
    // Lo que se muestra se vuelve a interpretar sin cambiar el día ni el mes.
    expect(interpretarFecha('05/03/2027'), DateTime(2027, 3, 5));
  });
}

void mainVencimiento() {
  group('fechaVencimientoPermiso', () {
    test('casilla Total: 31/03 del año siguiente a la emisión', () {
      expect(
        fechaVencimientoPermiso(
          formaPago: FormaPagoPermiso.total,
          fechaEmision: DateTime(2026, 6, 5), // permiso de Ñuñoa
        ),
        DateTime(2027, 3, 31),
      );
      expect(
        fechaVencimientoPermiso(
          formaPago: FormaPagoPermiso.total,
          fechaEmision: DateTime(2026, 10, 22), // solo el año: emisión estimada
        ),
        DateTime(2027, 3, 31),
      );
    });

    test('casilla Cuota 1: 31/08 del mismo año de la emisión', () {
      expect(
        fechaVencimientoPermiso(
          formaPago: FormaPagoPermiso.cuota1,
          fechaEmision: DateTime(2026, 3, 15),
        ),
        DateTime(2026, 8, 31),
      );
    });

    test('casilla Cuota 2 (ya pagó ambas): 31/03 del año siguiente', () {
      expect(
        fechaVencimientoPermiso(
          formaPago: FormaPagoPermiso.cuota2,
          fechaEmision: DateTime(2026, 8, 20),
        ),
        DateTime(2027, 3, 31),
      );
    });

    test('la casilla se lee y se guarda con valores fijos', () {
      expect(FormaPagoPermiso.fromFirestore('total'), FormaPagoPermiso.total);
      expect(FormaPagoPermiso.fromFirestore('cuota_1'), FormaPagoPermiso.cuota1);
      expect(FormaPagoPermiso.fromFirestore('cuota_2'), FormaPagoPermiso.cuota2);
      expect(FormaPagoPermiso.fromFirestore('una_cuota'), isNull);
      expect(FormaPagoPermiso.fromFirestore(null), isNull);
    });

    test('la IA recibe la casilla de pago como campo auxiliar del permiso', () {
      final esquema = buildCombinedSchema([DocumentType.permisoCirculacion]);
      expect((esquema['properties'] as Map).containsKey(claveFormaPago), isTrue);
      expect(
        extractionSchemas[DocumentType.permisoCirculacion]!.campos
            .any((c) => c.clave == claveFormaPago),
        isFalse,
      );
    });

    test('el modelo guarda la forma de pago solo cuando existe', () {
      final sin = DocumentoVehicularModel(
        id: '',
        vehiculoId: 'v1',
        tipoDocumento: TipoDocumentoVehicular.permisoCirculacion,
        origenRegistro: 'manual',
        fechaRegistro: DateTime(2026, 10, 22),
      );
      expect(sin.formaPago, isNull);
      expect(sin.toJson().containsKey('forma_pago'), isFalse);

      final con = DocumentoVehicularModel(
        id: '',
        vehiculoId: 'v1',
        tipoDocumento: TipoDocumentoVehicular.permisoCirculacion,
        formaPago: FormaPagoPermiso.cuota1,
        origenRegistro: 'manual',
        fechaRegistro: DateTime(2026, 10, 22),
      );
      expect(con.toJson()['forma_pago'], 'cuota_1');
    });
  });
}
