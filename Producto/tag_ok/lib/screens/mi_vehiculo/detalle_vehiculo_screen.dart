import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/documento_vehicular_model.dart';
import '../../data/models/vehiculo_model.dart';
import 'documentos_vehiculo_screen.dart';
import 'registrar_documento_ia_screen.dart';
import 'registrar_editar_vehiculo_screen.dart';

class DetalleVehiculoScreen extends StatelessWidget {
  final VehiculoModel vehiculo;

  const DetalleVehiculoScreen({
    super.key,
    required this.vehiculo,
  });

  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _surfaceLight = Color(0xFF27364D);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

  // ------------------------------------------------------------
  // IMAGEN SEGÚN TIPO DE VEHÍCULO
  // ------------------------------------------------------------

  String _imagenVehiculo() {
    final tipo =
        (vehiculo.tipoVehiculo ?? '').toUpperCase().trim();

    if (tipo == 'MOTO') {
      return 'assets/imagenes/vehiculos/moto.png';
    }

    if (tipo == 'CAMIONETA' ||
        tipo == 'CAMION' ||
        tipo == 'CAMIÓN') {
      return 'assets/imagenes/vehiculos/camion.png';
    }

    return 'assets/imagenes/vehiculos/auto.png';
  }

  String _nombreTipo() {
    final tipo =
        (vehiculo.tipoVehiculo ?? '').toUpperCase().trim();

    if (tipo == 'MOTO') return 'Moto';

    if (tipo == 'CAMIONETA' ||
        tipo == 'CAMION' ||
        tipo == 'CAMIÓN') {
      return 'Camión';
    }

    return 'Auto';
  }

  // ------------------------------------------------------------
  // ESTADOS
  // ------------------------------------------------------------

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

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'Atención requerida':
        return Icons.error_outline;

      case 'Próximo vencimiento':
        return Icons.schedule_outlined;

      case 'Todo al día':
        return Icons.check_circle_outline;

      default:
        return Icons.info_outline;
    }
  }

  // ------------------------------------------------------------
  // TARJETA DE DATO
  // ------------------------------------------------------------

  Widget _datoTecnico({
    required IconData icono,
    required String titulo,
    required String? valor,
  }) {
    final valorFinal =
        valor == null || valor.trim().isEmpty ? 'Sin datos' : valor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icono,
              color: _primaryColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valorFinal,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ACCIÓN RÁPIDA
  // ------------------------------------------------------------

  Widget _accionRapida({
    required IconData icono,
    required String titulo,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 105,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF334155),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icono,
                  color: _primaryColor,
                  size: 21,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alias =
        vehiculo.alias?.trim().isNotEmpty == true
            ? vehiculo.alias!.trim()
            : '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''}'.trim();

    final nombrePrincipal =
        alias.isEmpty ? vehiculo.patente : alias;

    final marcaModelo =
        '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''}'.trim();

    return Scaffold(
      backgroundColor: _bgColor,

      // ----------------------------------------------------------
      // APP BAR
      // ----------------------------------------------------------

      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: _textMain,
        ),
        title: const Text(
          'Información del vehículo',
          style: TextStyle(
            color: _textMain,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Editar vehículo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      RegistrarEditarVehiculoScreen(
                    vehiculo: vehiculo,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.edit_outlined,
              color: _textMain,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ----------------------------------------------------------
      // DOCUMENTOS
      // ----------------------------------------------------------

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('documentos_vehiculares')
            .where(
              'vehiculo_id',
              isEqualTo: vehiculo.id,
            )
            .snapshots(),
        builder: (context, snapshot) {
          final documentos =
              (snapshot.data?.docs ?? [])
                  .map(
                    (d) =>
                        DocumentoVehicularModel.fromJson(
                      d.data(),
                      d.id,
                    ),
                  )
                  .toList();

          final estado =
              VehiculoModel.calcularEstadoGeneral(
            documentos
                .map((d) => d.fechaVencimiento)
                .toList(),
          );

          DocumentoVehicularModel? proximoDocumento;

          final documentosConFecha = documentos
              .where(
                (doc) =>
                    doc.fechaVencimiento != null,
              )
              .toList();

          if (documentosConFecha.isNotEmpty) {
            documentosConFecha.sort(
              (a, b) => a.fechaVencimiento!
                  .compareTo(b.fechaVencimiento!),
            );

            proximoDocumento =
                documentosConFecha.first;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              35,
            ),
            children: [
              // --------------------------------------------------
              // HERO VEHÍCULO
              // --------------------------------------------------

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF334155),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 220,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF172033),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: Image.asset(
                        _imagenVehiculo(),
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stackTrace) {
                          return const Icon(
                            Icons.directions_car_outlined,
                            color: _primaryColor,
                            size: 90,
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            nombrePrincipal,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          if (marcaModelo.isNotEmpty &&
                              marcaModelo != nombrePrincipal) ...[
                            const SizedBox(height: 5),
                            Text(
                              marcaModelo,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(
                                Icons.badge_outlined,
                                vehiculo.patente,
                              ),
                              _chip(
                                Icons.directions_car_outlined,
                                _nombreTipo(),
                              ),
                              if (vehiculo.anio != null)
                                _chip(
                                  Icons.calendar_today_outlined,
                                  vehiculo.anio.toString(),
                                ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _colorEstado(estado)
                                  .withOpacity(0.10),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                color: _colorEstado(estado)
                                    .withOpacity(0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _iconoEstado(estado),
                                  color:
                                      _colorEstado(estado),
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  estado,
                                  style: TextStyle(
                                    color:
                                        _colorEstado(estado),
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // --------------------------------------------------
              // FICHA TÉCNICA
              // --------------------------------------------------

              const Text(
                'Ficha técnica',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Información principal de tu vehículo.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final dosColumnas =
                      constraints.maxWidth >= 550;

                  final ancho = dosColumnas
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: ancho,
                        child: _datoTecnico(
                          icono:
                              Icons.directions_car_outlined,
                          titulo: 'Marca',
                          valor: vehiculo.marca,
                        ),
                      ),
                      SizedBox(
                        width: ancho,
                        child: _datoTecnico(
                          icono:
                              Icons.car_repair_outlined,
                          titulo: 'Modelo',
                          valor: vehiculo.modelo,
                        ),
                      ),
                      SizedBox(
                        width: ancho,
                        child: _datoTecnico(
                          icono:
                              Icons.calendar_today_outlined,
                          titulo: 'Año',
                          valor:
                              vehiculo.anio?.toString(),
                        ),
                      ),
                      SizedBox(
                        width: ancho,
                        child: _datoTecnico(
                          icono:
                              Icons.local_gas_station_outlined,
                          titulo: 'Combustible',
                          valor:
                              vehiculo.tipoCombustible,
                        ),
                      ),
                      SizedBox(
                        width: ancho,
                        child: _datoTecnico(
                          icono: Icons.speed_outlined,
                          titulo: 'Kilometraje',
                          valor: vehiculo
                                      .kilometrajeActual !=
                                  null
                              ? '${vehiculo.kilometrajeActual} km'
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: ancho,
                        child: _datoTecnico(
                          icono:
                              Icons.category_outlined,
                          titulo: 'Tipo',
                          valor: _nombreTipo(),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // --------------------------------------------------
              // DOCUMENTOS
              // --------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Documentos',
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${documentos.length}',
                      style: const TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF334155),
                  ),
                ),
                child: documentos.isEmpty
                    ? Column(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: _textMuted,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Aún no hay documentos',
                            style: TextStyle(
                              color: _textMain,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Agrega los documentos de tu vehículo para controlar sus vencimientos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _primaryColor
                                  .withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.event_outlined,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  proximoDocumento != null
                                      ? 'Próximo vencimiento'
                                      : 'Documentos registrados',
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  proximoDocumento != null
                                      ? '${proximoDocumento.tipoDocumento.etiqueta} · '
                                          '${DateFormat('dd/MM/yyyy').format(proximoDocumento.fechaVencimiento!)}'
                                      : '${documentos.length} documento(s)',
                                  style: const TextStyle(
                                    color: _textMain,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DocumentosVehiculoScreen(
                          vehiculoId: vehiculo.id,
                          patenteVehiculo:
                              vehiculo.patente,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.description_outlined,
                  ),
                  label: const Text(
                    'Ver documentos',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textMain,
                    side: const BorderSide(
                      color: Color(0xFF475569),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // --------------------------------------------------
              // ACCIONES RÁPIDAS
              // --------------------------------------------------

              const Text(
                'Acciones rápidas',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  _accionRapida(
                    icono: Icons.edit_outlined,
                    titulo: 'Editar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RegistrarEditarVehiculoScreen(
                            vehiculo: vehiculo,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 12),

                  _accionRapida(
                    icono: Icons.add_a_photo_outlined,
                    titulo: 'Agregar documento',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RegistrarDocumentoIaScreen(
                            vehiculoId: vehiculo.id,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // CHIP
  // ------------------------------------------------------------

  Widget _chip(
    IconData icono,
    String texto,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icono,
            color: _textMuted,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              color: _textMain,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}