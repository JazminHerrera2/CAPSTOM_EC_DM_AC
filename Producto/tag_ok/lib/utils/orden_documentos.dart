import '../data/models/documento_vehicular_model.dart';

/// Documentos ordenados del que vence primero al que vence último. Los ya
/// vencidos van antes que todos (son los más urgentes) y los que no tienen
/// fecha de vencimiento, al final. A igual fecha, por tipo de documento. No
/// modifica la lista original.
List<DocumentoVehicularModel> ordenarPorVencimiento(
  Iterable<DocumentoVehicularModel> documentos,
) {
  DateTime? soloFecha(DateTime? f) =>
      f == null ? null : DateTime(f.year, f.month, f.day);

  final lista = documentos.toList();
  lista.sort((a, b) {
    final fa = soloFecha(a.fechaVencimiento);
    final fb = soloFecha(b.fechaVencimiento);
    if (fa == null && fb == null) {
      return a.tipoDocumento.index.compareTo(b.tipoDocumento.index);
    }
    if (fa == null) return 1;
    if (fb == null) return -1;
    final porFecha = fa.compareTo(fb);
    return porFecha != 0
        ? porFecha
        : a.tipoDocumento.index.compareTo(b.tipoDocumento.index);
  });
  return lista;
}
