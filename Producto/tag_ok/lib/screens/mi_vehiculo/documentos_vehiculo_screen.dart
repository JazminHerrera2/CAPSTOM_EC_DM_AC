import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/documento_vehicular_model.dart';
import '../../data/services/documento_vehicular_service.dart';
import 'registrar_documento_ia_screen.dart';

/// CU3 (gestionar documentos) y CU4 (configurar vencimientos) de un
/// vehículo puntual.
class DocumentosVehiculoScreen extends StatefulWidget {
  final String vehiculoId;
  final String patenteVehiculo;

  const DocumentosVehiculoScreen({
    super.key,
    required this.vehiculoId,
    required this.patenteVehiculo,
  });

  @override
  State<DocumentosVehiculoScreen> createState() => _DocumentosVehiculoScreenState();
}

class _DocumentosVehiculoScreenState extends State<DocumentosVehiculoScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color surfaceColor = const Color(0xFF1E293B);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF4F46E5);

  final DocumentoVehicularService _documentoService = DocumentoVehicularService();

  Future<void> _configurarVencimiento(DocumentoVehicularModel documento) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: documento.fechaVencimiento ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha == null) return;

    await _documentoService.actualizarVencimiento(documento.id, fecha);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vencimiento actualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('Documentos — ${widget.patenteVehiculo}', style: TextStyle(color: textMain)),
        iconTheme: IconThemeData(color: textMain),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrarDocumentoIaScreen(vehiculoId: widget.vehiculoId),
          ),
        ),
        child: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
      ),
      body: StreamBuilder<List<DocumentoVehicularModel>>(
        stream: _documentoService.streamDocumentosPorVehiculo(widget.vehiculoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final documentos = snapshot.data ?? [];
          if (documentos.isEmpty) {
            return Center(
              child: Text(
                'Aún no hay documentos registrados.\nPresiona + para agregar uno con IA.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final doc = documentos[index];
              final vencido = doc.fechaVencimiento != null &&
                  doc.fechaVencimiento!.isBefore(DateTime.now());

              return Card(
                color: surfaceColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: Icon(
                    Icons.description_outlined,
                    color: vencido ? Colors.redAccent : primaryColor,
                  ),
                  title: Text(doc.tipoDocumento.etiqueta, style: TextStyle(color: textMain)),
                  subtitle: Text(
                    doc.fechaVencimiento != null
                        ? 'Vence: ${DateFormat('dd/MM/yyyy').format(doc.fechaVencimiento!)}'
                        : 'Sin fecha de vencimiento configurada',
                    style: TextStyle(color: vencido ? Colors.redAccent : textMuted),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit_calendar_outlined, color: textMuted),
                    onPressed: () => _configurarVencimiento(doc),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
