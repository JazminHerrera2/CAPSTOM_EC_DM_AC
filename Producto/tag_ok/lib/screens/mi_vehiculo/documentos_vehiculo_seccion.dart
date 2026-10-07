import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/documento_vehicular_model.dart';
import '../../data/services/documento_vehicular_service.dart';
import 'detalle_documento_screen.dart';
import 'registrar_documento_ia_screen.dart';

/// Documentos de UN vehículo: tarjeta con la patente y el avance (N/4), y las
/// tarjetas de sus documentos con estado y vencimiento (o el estado vacío con
/// el botón para agregar el primero).
///
/// Se usa tanto en la pantalla "Documentos" de un vehículo como en la pestaña
/// Documentos de Mi Vehículo (una sección por patente), para que ambas tengan
/// exactamente la misma interfaz.
class DocumentosVehiculoSeccion extends StatelessWidget {
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF27364D);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color primaryColor = Color(0xFF4F46E5);

  final String vehiculoId;
  final String patenteVehiculo;
  final List<DocumentoVehicularModel> documentos;

  /// Muestra el bloque "Tus documentos / Revisa el estado y vencimiento…"
  /// entre la tarjeta de la patente y los documentos.
  final bool mostrarTitulo;

  /// Muestra el botón "Agregar documento" bajo las tarjetas. La pantalla de un
  /// solo vehículo ya tiene su botón flotante, así que ahí va en false; en la
  /// pestaña con varios vehículos cada sección lleva el suyo.
  final bool mostrarBotonAgregar;

  const DocumentosVehiculoSeccion({
    super.key,
    required this.vehiculoId,
    required this.patenteVehiculo,
    required this.documentos,
    this.mostrarTitulo = true,
    this.mostrarBotonAgregar = false,
  });

  // ------------------------------------------------------------
  // CONFIGURAR VENCIMIENTO
  // ------------------------------------------------------------

  Future<void> _configurarVencimiento(
    BuildContext context,
    DocumentoVehicularModel documento,
  ) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: documento.fechaVencimiento ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Seleccionar vencimiento',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
    );

    if (fecha == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await DocumentoVehicularService().actualizarVencimiento(
        documento.id,
        fecha,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Vencimiento actualizado exitosamente.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo actualizar el vencimiento: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el vencimiento. Intenta nuevamente.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _agregarDocumento(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrarDocumentoIaScreen(
          vehiculoId: vehiculoId,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ESTADO DOCUMENTO
  // ------------------------------------------------------------

  String _estadoDocumento(DocumentoVehicularModel documento) {
    final fecha = documento.fechaVencimiento;

    if (fecha == null) {
      return 'Sin vencimiento';
    }

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final vencimiento = DateTime(fecha.year, fecha.month, fecha.day);
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
        return const Color(0xFFF97316);

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
    BuildContext context,
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
              patenteVehiculo: patenteVehiculo,
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
                    _configurarVencimiento(context, documento);
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
  // SIN DOCUMENTOS
  // ------------------------------------------------------------

  Widget _sinDocumentos(BuildContext context) {
    return Container(
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
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
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

          ElevatedButton.icon(
            onPressed: () => _agregarDocumento(context),
            icon: const Icon(Icons.add),
            label: const Text(
              'Agregar primer documento',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECCIÓN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --------------------------------------------------
        // VEHÍCULO
        // --------------------------------------------------

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Más claro y con acento (violeta) para distinguir al vehículo de
            // las tarjetas de documentos, que son oscuras.
            color: const Color(0xFF312E81),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  color: Colors.white,
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
                      color: Color(0xFFC7D2FE),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patenteVehiculo,
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
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${documentos.length}/${TipoDocumentoVehicular.values.length} documentos',
                  style: const TextStyle(
                    color: Color(0xFFE0E7FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (mostrarTitulo) ...[
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
                    '${documentos.length}/${TipoDocumentoVehicular.values.length}',
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // --------------------------------------------------
        // SIN DOCUMENTOS / LISTADO
        // --------------------------------------------------

        if (documentos.isEmpty)
          _sinDocumentos(context)
        else
          ...documentos.map(
            (documento) => _tarjetaDocumento(context, documento),
          ),

        // Sin documentos ya se ofrece "Agregar primer documento".
        if (mostrarBotonAgregar && documentos.isNotEmpty)
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _agregarDocumento(context),
              icon: const Icon(Icons.add),
              label: const Text(
                'Agregar documento',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
