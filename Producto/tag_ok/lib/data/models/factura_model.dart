class FacturaModel {
  final String id;
  final String usuarioId;
  final String periodoFacturacion;
  final double montoTotalCobrado;
  final String estado; // Ej: 'procesando', 'auditada', 'discrepancia'
  final String? pdfUrl;

  FacturaModel({
    required this.id,
    required this.usuarioId,
    required this.periodoFacturacion,
    required this.montoTotalCobrado,
    this.estado = 'procesando',
    this.pdfUrl,
  });

  factory FacturaModel.fromJson(Map<String, dynamic> json, String id) {
    return FacturaModel(
      id: id,
      usuarioId: json['usuario_id'] ?? '',
      periodoFacturacion: json['periodo_facturacion'] ?? '',
      montoTotalCobrado: (json['monto_total_cobrado'] ?? 0.0).toDouble(),
      estado: json['estado'] ?? 'procesando',
      pdfUrl: json['pdf_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario_id': usuarioId,
      'periodo_facturacion': periodoFacturacion,
      'monto_total_cobrado': montoTotalCobrado,
      'estado': estado,
      'pdf_url': pdfUrl,
    };
  }
}
