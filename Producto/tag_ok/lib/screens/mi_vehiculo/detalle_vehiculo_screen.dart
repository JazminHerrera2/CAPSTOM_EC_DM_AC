import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/documento_vehicular_model.dart';
import '../../data/models/vehiculo_model.dart';
import 'documentos_vehiculo_screen.dart';
import 'registrar_documento_ia_screen.dart';
import 'registrar_editar_vehiculo_screen.dart';

/// Detalle de un vehículo — hub de resumen (CU5) con acceso de página
/// completa (Navigator.push) a las pantallas ya existentes: editar (CU2),
/// documentos/vencimientos (CU3/CU4) y registro con IA (CU6/CU7). No
/// reimplementa esa lógica, solo la enlaza — nada de diálogos ni overlays.
class DetalleVehiculoScreen extends StatelessWidget {
  final VehiculoModel vehiculo;

  const DetalleVehiculoScreen({super.key, required this.vehiculo});

  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Atención requerida':
        return Colors.redAccent;
      case 'Próximo vencimiento':
        return const Color(0xFFF59E0B);
      case 'Todo al día':
        return const Color(0xFF10B981);
      default:
        return _textMuted;
    }
  }

  Widget _infoRow(String etiqueta, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(etiqueta, style: const TextStyle(color: _textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              (valor == null || valor.isEmpty) ? 'Sin datos' : valor,
              style: const TextStyle(color: _textMain, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(
          vehiculo.alias?.isNotEmpty == true ? vehiculo.alias! : vehiculo.patente,
          style: const TextStyle(color: _textMain),
        ),
        iconTheme: const IconThemeData(color: _textMain),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('documentos_vehiculares')
            .where('vehiculo_id', isEqualTo: vehiculo.id)
            .snapshots(),
        builder: (context, snapshot) {
          final documentos = (snapshot.data?.docs ?? [])
              .map((d) => DocumentoVehicularModel.fromJson(d.data(), d.id))
              .toList();
          final estado = VehiculoModel.calcularEstadoGeneral(
            documentos.map((d) => d.fechaVencimiento).toList(),
          );

          DocumentoVehicularModel? proximoDocumento;
          for (final doc in documentos) {
            if (doc.fechaVencimiento == null) continue;
            if (proximoDocumento == null ||
                doc.fechaVencimiento!.isBefore(proximoDocumento.fechaVencimiento!)) {
              proximoDocumento = doc;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // --- Estado general (CU5) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: _colorEstado(estado).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _colorEstado(estado)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _colorEstado(estado)),
                    const SizedBox(width: 10),
                    Text(
                      estado,
                      style: TextStyle(color: _colorEstado(estado), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Información general (CU1/CU2) ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Información general',
                          style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegistrarEditarVehiculoScreen(vehiculo: vehiculo),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18, color: _primaryColor),
                          label: const Text('Editar', style: TextStyle(color: _primaryColor)),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    _infoRow('Patente', vehiculo.patente),
                    _infoRow('Marca', vehiculo.marca),
                    _infoRow('Modelo', vehiculo.modelo),
                    _infoRow('Año', vehiculo.anio?.toString()),
                    _infoRow('Tipo', vehiculo.tipoVehiculo),
                    _infoRow('Combustible', vehiculo.tipoCombustible),
                    _infoRow(
                      'Kilometraje',
                      vehiculo.kilometrajeActual != null ? '${vehiculo.kilometrajeActual} km' : null,
                    ),
                    _infoRow('Alias', vehiculo.alias),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Documentos (CU3/CU4) ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Documentos',
                      style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    if (documentos.isEmpty)
                      const Text('Aún no hay documentos registrados.', style: TextStyle(color: _textMuted))
                    else if (proximoDocumento != null)
                      Text(
                        'Próximo vencimiento: ${proximoDocumento.tipoDocumento.etiqueta} — '
                        '${DateFormat('dd/MM/yyyy').format(proximoDocumento.fechaVencimiento!)}',
                        style: const TextStyle(color: _textMuted),
                      )
                    else
                      Text('${documentos.length} documento(s) registrados.', style: const TextStyle(color: _textMuted)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentosVehiculoScreen(
                            vehiculoId: vehiculo.id,
                            patenteVehiculo: vehiculo.patente,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.description_outlined, color: _textMain),
                      label: const Text('Ver documentos', style: TextStyle(color: _textMain)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Registro con IA (CU6/CU7, con alternativa manual CU40 ya incluida) ---
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RegistrarDocumentoIaScreen(vehiculoId: vehiculo.id),
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
                label: const Text('Registrar documento', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
