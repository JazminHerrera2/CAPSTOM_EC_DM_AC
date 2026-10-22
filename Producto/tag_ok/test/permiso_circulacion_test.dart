import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/documento_vehicular_model.dart';
import 'package:tag_ok/features/registro_inteligente/document_type.dart';
import 'package:tag_ok/features/registro_inteligente/extraction_schema_registry.dart';
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
