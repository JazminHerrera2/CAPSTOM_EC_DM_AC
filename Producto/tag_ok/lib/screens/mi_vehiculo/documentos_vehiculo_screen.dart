import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/documento_vehicular_model.dart';
import '../../data/services/documento_vehicular_service.dart';
import 'registrar_documento_ia_screen.dart';
import 'detalle_documento_screen.dart';

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
  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF27364D);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color primaryColor = Color(0xFF4F46E5);

  final DocumentoVehicularService _documentoService =
      DocumentoVehicularService();

  // ------------------------------------------------------------
  // CONFIGURAR VENCIMIENTO
  // ------------------------------------------------------------

  Future<void> _configurarVencimiento(
    DocumentoVehicularModel documento,
  ) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate:
          documento.fechaVencimiento ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Seleccionar vencimiento',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
    );

    if (fecha == null) return;

    await _documentoService.actualizarVencimiento(
      documento.id,
      fecha,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vencimiento actualizado'),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // ESTADO DOCUMENTO
  // ------------------------------------------------------------

  String _estadoDocumento(
    DocumentoVehicularModel documento,
  ) {
    final fecha = documento.fechaVencimiento;

    if (fecha == null) {
      return 'Sin vencimiento';
    }

    final ahora = DateTime.now();

    final hoy = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
    );

    final vencimiento = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
    );

    final dias = vencimiento.difference(hoy).inDays;

    if (dias < 0) {
      return 'Vencido';
    }

    if (dias <= 30) {
      return 'Próximo a vencer';
    }

    return 'Vigente';
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Vencido':
        return Colors.redAccent;

      case 'Próximo a vencer':
        return const Color(0xFFF59E0B);

      case 'Vigente':
        return const Color(0xFF10B981);

      default:
        return textMuted;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'Vencido':
        return Icons.error_outline;

      case 'Próximo a vencer':
        return Icons.schedule_outlined;

      case 'Vigente':
        return Icons.check_circle_outline;

      default:
        return Icons.info_outline;
    }
  }

  // ------------------------------------------------------------
  // TARJETA DOCUMENTO
  // ------------------------------------------------------------

  Widget _tarjetaDocumento(
  DocumentoVehicularModel documento,
) {
  final estado = _estadoDocumento(documento);
  final color = _colorEstado(estado);

  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetalleDocumentoScreen(
            documento: documento,
            patenteVehiculo: widget.patenteVehiculo,
          ),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: primaryColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      documento.tipoDocumento.etiqueta,
                      style: const TextStyle(
                        color: textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconoEstado(estado),
                            color: color,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            estado,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Cambiar vencimiento',
                onPressed: () {
                  _configurarVencimiento(documento);
                },
                icon: const Icon(
                  Icons.edit_calendar_outlined,
                  color: textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(
            color: Color(0xFF334155),
            height: 1,
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                color: textMuted,
                size: 18,
              ),

              const SizedBox(width: 8),

              const Text(
                'Vencimiento',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 12,
                ),
              ),

              const Spacer(),

              Text(
                documento.fechaVencimiento != null
                    ? DateFormat('dd/MM/yyyy').format(
                        documento.fechaVencimiento!,
                      )
                    : 'Sin configurar',
                style: TextStyle(
                  color: documento.fechaVencimiento != null
                      ? textMain
                      : textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
  // ------------------------------------------------------------
  // PANTALLA
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,

      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: textMain,
        ),
        title: const Text(
          'Documentos',
          style: TextStyle(
            color: textMain,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RegistrarDocumentoIaScreen(
                vehiculoId: widget.vehiculoId,
              ),
            ),
          );
        },
        icon: const Icon(
          Icons.add,
          color: Colors.white,
        ),
        label: const Text(
          'Agregar',
          style: TextStyle(
            color: Colors.white,
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
                color: primaryColor,
              ),
            );
          }

          final documentos = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              100,
            ),
            children: [
              // --------------------------------------------------
              // VEHÍCULO
              // --------------------------------------------------

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car_outlined,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vehículo',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.patenteVehiculo,
                          style: const TextStyle(
                            color: textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${documentos.length} documento${documentos.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tus documentos',
                          style: TextStyle(
                            color: textMain,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Revisa el estado y vencimiento de cada documento.',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (documentos.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${documentos.length}',
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // SIN DOCUMENTOS
              // --------------------------------------------------

              if (documentos.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 45,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF334155),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color:
                              primaryColor.withOpacity(0.10),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: primaryColor,
                          size: 34,
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Aún no hay documentos',
                        style: TextStyle(
                          color: textMain,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 7),

                      const Text(
                        'Agrega los documentos de tu vehículo para controlar sus vencimientos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RegistrarDocumentoIaScreen(
                                vehiculoId:
                                    widget.vehiculoId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.add,
                        ),
                        label: const Text(
                          'Agregar primer documento',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textMain,
                          side: const BorderSide(
                            color: Color(0xFF475569),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                )

              // --------------------------------------------------
              // LISTADO
              // --------------------------------------------------

              else
                ...documentos.map(
                  (documento) =>
                      _tarjetaDocumento(documento),
                ),
            ],
          );
        },
      ),
    );
  }
}