import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/documento_vehicular_model.dart';
import '../../data/services/documento_vehicular_service.dart';
import '../../utils/orden_documentos.dart';
import 'detalle_documento_screen.dart';
import 'registrar_documento_ia_screen.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

/// Documentos de UN vehículo: tarjeta con la patente, y las
/// tarjetas de sus documentos con estado y vencimiento (o el estado vacío con
/// el botón para agregar el primero).
///
/// Se usa tanto en la pantalla "Documentos" de un vehículo como en la pestaña
/// Documentos de Mi Vehículo (una sección por patente), para que ambas tengan
/// exactamente la misma interfaz.
class DocumentosVehiculoSeccion extends StatelessWidget {

  final String vehiculoId;
  final String patenteVehiculo;
  final List<DocumentoVehicularModel> documentos;

  /// Muestra el bloque "Tus documentos / Revisa el estado y vencimiento…"
  /// entre la tarjeta de la patente y los documentos.
  final bool mostrarTitulo;

  /// Muestra el botón "Agregar documento" debajo de la tarjeta del vehículo y
  /// arriba de los documentos ya registrados (cada sección lleva el suyo).
  final bool mostrarBotonAgregar;

  /// Muestra la tarjeta del vehículo (patente) arriba. En el detalle del
  /// vehículo se oculta, porque esa pantalla ya muestra la patente.
  final bool mostrarVehiculo;

  const DocumentosVehiculoSeccion({
    super.key,
    required this.vehiculoId,
    required this.patenteVehiculo,
    required this.documentos,
    this.mostrarTitulo = true,
    this.mostrarBotonAgregar = false,
    this.mostrarVehiculo = true,
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
          backgroundColor: AppColors.exito,
        ),
      );
    } catch (e) {
      debugPrint('No se pudo actualizar el vencimiento: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el vencimiento. Intenta nuevamente.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Abre el registro del mismo tipo de documento: al guardar el nuevo se
  /// reemplaza el anterior.
  void _actualizarDocumento(
    BuildContext context,
    DocumentoVehicularModel documento,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrarDocumentoIaScreen(
          vehiculoId: documento.vehiculoId,
          tipoInicial: documentTypeDe(documento.tipoDocumento),
        ),
      ),
    );
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
        return AppColors.error;

      case 'Próximo a vencer':
        return AppColors.alerta;

      case 'Vigente':
        return AppColors.exito;

      default:
        return AppColors.textoSecundario;
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
      borderRadius: BorderRadius.circular(AppRadios.tarjeta),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          boxShadow: AppSombras.tarjeta,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila del título (ej. "Permiso de Circulación"): sobre fondo blanco,
            // con el ícono en azul y sin recuadro de color detrás.
            Row(
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.description_outlined,
                    color: AppColors.textoSecundario,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documento.tipoDocumento.etiqueta,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
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
                              size: 13,
                            ),
                            const SizedBox(width: 4),
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
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _configurarVencimiento(context, documento);
                  },
                  icon: const Icon(
                    Icons.edit_calendar_outlined,
                    color: AppColors.primario,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const SizedBox(width: 4),

                const Icon(
                  Icons.event_outlined,
                  color: AppColors.textoSecundario,
                  size: 18,
                ),

                const SizedBox(width: 8),

                const Text(
                  'Vencimiento',
                  style: TextStyle(
                    color: AppColors.textoSecundario,
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
                        ? AppColors.texto
                        : AppColors.textoSecundario,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(width: 4),
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _actualizarDocumento(context, documento),
                icon: const Icon(
                  Icons.autorenew_rounded,
                  color: AppColors.primario,
                  size: 19,
                ),
                label: const Text(
                  'Actualizar',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.primario.withOpacity(0.10),
                  side: BorderSide(color: AppColors.primario.withOpacity(0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadios.control),
                  ),
                ),
              ),
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
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primario.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.primario,
              size: 34,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Aún no hay documentos',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Agrega los documentos de tu vehículo para controlar sus vencimientos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textoSecundario,
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
              backgroundColor: AppColors.primario,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadios.control),
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

        if (mostrarVehiculo)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Más claro y con acento (violeta) para distinguir al vehículo de
            // las tarjetas de documentos, que son oscuras.
            color: AppColors.sobreLavanda,
            borderRadius: BorderRadius.circular(AppRadios.tarjeta),
            border: Border.all(
              color: AppColors.primario.withOpacity(0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primario.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(AppRadios.icono),
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
                      color: AppColors.barraInactiva,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patenteVehiculo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),

        // Debajo del vehículo y arriba de los documentos ya registrados. Sin
        // documentos ya se ofrece "Agregar primer documento".
        if (mostrarBotonAgregar && documentos.isNotEmpty) ...[
          if (mostrarVehiculo) const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _agregarDocumento(context),
              icon: const Icon(Icons.add),
              label: const Text(
                'Agregar documento',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primario,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadios.control),
                ),
              ),
            ),
          ),
        ],

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
                        color: AppColors.texto,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Revisa el estado y vencimiento de cada documento.',
                      style: TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        if (mostrarVehiculo || mostrarTitulo || mostrarBotonAgregar)
          const SizedBox(height: 16),

        // --------------------------------------------------
        // SIN DOCUMENTOS / LISTADO
        // --------------------------------------------------

        if (documentos.isEmpty)
          _sinDocumentos(context)
        else
          // Del que vence primero al que vence último.
          ...ordenarPorVencimiento(documentos).map(
            (documento) => _tarjetaDocumento(context, documento),
          ),

      ],
    );
  }
}
