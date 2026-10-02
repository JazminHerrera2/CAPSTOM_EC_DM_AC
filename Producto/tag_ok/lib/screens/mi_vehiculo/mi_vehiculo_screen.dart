import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/documento_vehicular_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/vehiculo_service.dart';
import 'detalle_vehiculo_screen.dart';
import 'registrar_editar_vehiculo_screen.dart';
import 'detalle_documento_screen.dart';

class MiVehiculoScreen extends StatefulWidget {
  const MiVehiculoScreen({super.key});

  @override
  State<MiVehiculoScreen> createState() => _MiVehiculoScreenState();
}

class _MiVehiculoScreenState extends State<MiVehiculoScreen> {
  // Colores principales de TAG OK
  final Color bgColor = const Color(0xFF0F172A);
  final Color surfaceColor = const Color(0xFF1E293B);
  final Color surfaceLight = const Color(0xFF263449);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF4F46E5);

  final VehiculoService _vehiculoService = VehiculoService();

  int _activeSubTab = 0;

  String get _usuarioId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,

      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Mi VehÍ­culo',
          style: TextStyle(
            color: textMain,
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // El + siempre significa AGREGAR VEHíCULO.
      floatingActionButton: _activeSubTab == 0
          ? FloatingActionButton(
              heroTag: 'agregarVehiculo',
              backgroundColor: primaryColor,
              tooltip: 'Agregar vehículo',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RegistrarEditarVehiculoScreen(),
                  ),
                );
              },
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 30,
              ),
            )
          : null,

      body: Column(
        children: [
          // ---------------------------------------------------------
          // TABS
          // ---------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Mis Vehí­culos',
                    icon: Icons.directions_car_outlined,
                    index: 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton(
                    label: 'Documentos',
                    icon: Icons.description_outlined,
                    index: 1,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _activeSubTab == 0
                ? _buildListaVehiculos()
                : _buildDocumentosAgregados(),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // BOTONES SUPERIORES
  // ================================================================

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required int index,
  }) {
    final activo = _activeSubTab == index;

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        setState(() {
          _activeSubTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          color: activo ? primaryColor : surfaceColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: activo ? Colors.white : textMuted,
              size: 21,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: activo ? Colors.white : textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // MIS VEHíCULOS
  // ================================================================

  Widget _buildListaVehiculos() {
    return StreamBuilder<List<VehiculoModel>>(
      stream: _vehiculoService.streamVehiculosUsuario(_usuarioId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEstadoError(
            'No fue posible cargar tus vehículos.',
          );
        }

        final vehiculos = snapshot.data ?? [];

        // ----------------------------------------------------------
        // USUARIO SIN VEHíCULOS
        // ----------------------------------------------------------

        if (vehiculos.isEmpty) {
          return _buildEstadoSinVehiculos();
        }

        // ----------------------------------------------------------
        // UNO O MáS VEHíCULOS
        // ----------------------------------------------------------

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehiculos.length == 1
                        ? 'Tu vehí­culo'
                        : 'Tus vehí­culos',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                    '${vehiculos.length} ${vehiculos.length == 1 ? 'registrado' : 'registrados'}',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Consulta la información, documentos y estado de cada vehí­culo.',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            ...vehiculos.map(
              (vehiculo) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _VehiculoCard(
                  vehiculo: vehiculo,
                  surfaceColor: surfaceColor,
                  surfaceLight: surfaceLight,
                  textMain: textMain,
                  textMuted: textMuted,
                  primaryColor: primaryColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetalleVehiculoScreen(vehiculo: vehiculo),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // ESTADO VACíO
  // ================================================================

  Widget _buildEstadoSinVehiculos() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(35, 20, 35, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tres tipos de vehí­culos disponibles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniVehiculo(
                  'assets/imagenes/vehiculos/auto.png',
                ),
                const SizedBox(width: 8),
                _buildMiniVehiculo(
                  'assets/imagenes/vehiculos/camion.png',
                ),
                const SizedBox(width: 8),
                _buildMiniVehiculo(
                  'assets/imagenes/vehiculos/moto.png',
                ),
              ],
            ),

            const SizedBox(height: 26),

            Text(
              'Aún no tienes vehí­culos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMain,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Agrega tu primer vehículo para gestionar su información, documentos y vencimientos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Presiona + para agregar un vehículo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniVehiculo(String asset) {
    return Expanded(
      child: Container(
        height: 75,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('ERROR IMAGEN VEHICULO: $asset');
            debugPrint('DETALLE ERROR: $error');

            return Icon(
              Icons.directions_car_outlined,
              color: textMuted,
            );
          },
        ),
      ),
    );
  }

  // ================================================================
  // DOCUMENTOS DE TODOS LOS VEHiCULOS
  // ================================================================

  Widget _buildDocumentosAgregados() {
    return StreamBuilder<List<VehiculoModel>>(
      stream: _vehiculoService.streamVehiculosUsuario(_usuarioId),
      builder: (context, snapshotVehiculos) {
        if (snapshotVehiculos.connectionState ==
            ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          );
        }

        final vehiculos = snapshotVehiculos.data ?? [];

        if (vehiculos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 58,
                    color: textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Primero agrega un vehí­culo',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los documentos registrados para tus vehí­culos aparecerán aquí­.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final idsVehiculos =
            vehiculos.map((vehiculo) => vehiculo.id).toList();

        final patentesPorId = {
          for (final vehiculo in vehiculos)
            vehiculo.id: vehiculo.patente,
        };

        return StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('documentos_vehiculares')
              .where(
                'vehiculo_id',
                whereIn: idsVehiculos,
              )
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildEstadoError(
                'No fue posible cargar los documentos.',
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          size: 38,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sin documentos',
                        style: TextStyle(
                          color: textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aun no hay documentos registrados para tus vehÍculos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                100,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final documento =
                    DocumentoVehicularModel.fromJson(
                  docs[index].data(),
                  docs[index].id,
                );

                final patente =
                    patentesPorId[documento.vehiculoId] ??
                        'VehÍ­culo';

                final vencido =
                    documento.fechaVencimiento != null &&
                        documento.fechaVencimiento!
                            .isBefore(DateTime.now());

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetalleDocumentoScreen(
                            documento: documento,
                            patenteVehiculo: patente,
                          ),
                        ),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: (vencido
                                ? Colors.redAccent
                                : primaryColor)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: vencido
                            ? Colors.redAccent
                            : primaryColor,
                      ),
                    ),
                    title: Text(
                      documento.tipoDocumento.etiqueta,
                      style: TextStyle(
                        color: textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            patente,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            documento.fechaVencimiento != null
                                ? 'Vence: ${DateFormat('dd/MM/yyyy').format(documento.fechaVencimiento!)}'
                                : 'Sin fecha de vencimiento',
                            style: TextStyle(
                              color: vencido
                                  ? Colors.redAccent
                                  : textMuted,
                              fontSize: 12,
                              fontWeight: vencido
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEstadoError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// TARJETA INDIVIDUAL DE VEHiCULO
// ===================================================================

class _VehiculoCard extends StatelessWidget {
  final VehiculoModel vehiculo;
  final Color surfaceColor;
  final Color surfaceLight;
  final Color textMain;
  final Color textMuted;
  final Color primaryColor;
  final VoidCallback onTap;

  const _VehiculoCard({
    required this.vehiculo,
    required this.surfaceColor,
    required this.surfaceLight,
    required this.textMain,
    required this.textMuted,
    required this.primaryColor,
    required this.onTap,
  });

  // Selecciona automaticamente la imagen segun la categoría.
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

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Atención requerida':
        return Colors.redAccent;

      case 'Próximo vencimiento':
        return const Color(0xFFF59E0B);

      case 'Todo al dÍ­a':
        return const Color(0xFF10B981);

      default:
        return textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('documentos_vehiculares')
          .where(
            'vehiculo_id',
            isEqualTo: vehiculo.id,
          )
          .snapshots(),
      builder: (context, snapshot) {
        final fechas = (snapshot.data?.docs ?? [])
            .map(
              (documento) =>
                  (documento.data()['fecha_vencimiento']
                          as Timestamp?)
                      ?.toDate(),
            )
            .toList();

        final estado =
            VehiculoModel.calcularEstadoGeneral(fechas);

        final colorEstado = _colorEstado(estado);

        final marcaModelo =
            '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''}'
                .trim();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -------------------------------------------------
                  // IMAGEN
                  // -------------------------------------------------

                  Container(
                    width: double.infinity,
                    height: 155,
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      14,
                      24,
                      4,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceLight,
                    ),
                    child: Image.asset(
                      _imagenVehiculo(),
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) {
                        return Icon(
                          Icons.directions_car,
                          color: primaryColor,
                          size: 70,
                        );
                      },
                    ),
                  ),

                  // -------------------------------------------------
                  // DATOS
                  // -------------------------------------------------

                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehiculo.alias
                                                ?.isNotEmpty ==
                                            true
                                        ? vehiculo.alias!
                                        : marcaModelo.isNotEmpty
                                            ? marcaModelo
                                            : vehiculo.patente,
                                    style: TextStyle(
                                      color: textMain,
                                      fontSize: 19,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    marcaModelo.isNotEmpty
                                        ? marcaModelo
                                        : 'VehÍ­culo registrado',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            Icon(
                              Icons.chevron_right_rounded,
                              color: textMuted,
                              size: 27,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              icon: Icons.badge_outlined,
                              texto: vehiculo.patente,
                              color: primaryColor,
                              textMain: textMain,
                            ),

                            if (vehiculo.anio != null)
                              _InfoChip(
                                icon:
                                    Icons.calendar_today_outlined,
                                texto:
                                    vehiculo.anio.toString(),
                                color: primaryColor,
                                textMain: textMain,
                              ),

                            if (vehiculo.categoria != null &&
                                vehiculo
                                    .categoria!.isNotEmpty)
                              _InfoChip(
                                icon:
                                    Icons.category_outlined,
                                texto: vehiculo.categoria!,
                                color: primaryColor,
                                textMain: textMain,
                              ),
                          ],
                        ),

                        const SizedBox(height: 17),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color:
                                colorEstado.withOpacity(0.10),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colorEstado,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  estado,
                                  style: TextStyle(
                                    color: colorEstado,
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                'Ver detalles',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
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
          ),
        );
      },
    );
  }
}

// ===================================================================
// CHIP PEQUEÑO DE INFORMACIÓN
// ===================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color color;
  final Color textMain;

  const _InfoChip({
    required this.icon,
    required this.texto,
    required this.color,
    required this.textMain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: textMain,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
