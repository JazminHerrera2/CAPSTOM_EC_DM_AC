import 'package:flutter/material.dart';

import '../../data/models/documento_vehicular_model.dart';
import '../../data/services/documento_vehicular_service.dart';
import 'documentos_vehiculo_seccion.dart';
import 'package:tag_ok/theme/app_colors.dart';

class DocumentosVehiculoScreen extends StatefulWidget {
  final String vehiculoId;
  final String patenteVehiculo;

  const DocumentosVehiculoScreen({
    super.key,
    required this.vehiculoId,
    required this.patenteVehiculo,
  });

  @override
  State<DocumentosVehiculoScreen> createState() =>
      _DocumentosVehiculoScreenState();
}

class _DocumentosVehiculoScreenState
    extends State<DocumentosVehiculoScreen> {

  final DocumentoVehicularService _documentoService =
      DocumentoVehicularService();

  // ------------------------------------------------------------
  // PANTALLA
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,

      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: AppColors.texto,
        ),
        title: const Text(
          'Documentos',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: StreamBuilder<List<DocumentoVehicularModel>>(
        stream: _documentoService
            .streamDocumentosPorVehiculo(
          widget.vehiculoId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primario,
              ),
            );
          }

          final documentos = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              30,
            ),
            children: [
              DocumentosVehiculoSeccion(
                vehiculoId: widget.vehiculoId,
                patenteVehiculo: widget.patenteVehiculo,
                documentos: documentos,
                mostrarBotonAgregar: true,
              ),
            ],
          );
        },
      ),
    );
  }
}
