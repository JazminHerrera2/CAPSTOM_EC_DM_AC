import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/vehiculo_model.dart';
import '../../data/services/vehiculo_service.dart';
import '../dashboard/encabezado_tag_ok.dart';
import 'detalle_vehiculo_screen.dart';
import 'foto_vehiculo.dart';
import 'registrar_editar_vehiculo_screen.dart';

class MiVehiculoScreen extends StatefulWidget {
  const MiVehiculoScreen({super.key});

  @override
  State<MiVehiculoScreen> createState() => _MiVehiculoScreenState();
}

class _MiVehiculoScreenState extends State<MiVehiculoScreen> {
  // Colores principales de TAG OK
  final Color bgColor = const Color(0xFFF1F5F9);
  final Color surfaceColor = const Color(0xFFFFFFFF);
  final Color surfaceLight = const Color(0xFFE2E8F0);
  final Color textMain = const Color(0xFF0F172A);
  final Color textMuted = const Color(0xFF64748B);
  final Color primaryColor = const Color(0xFF1E3A8A);

  final VehiculoService _vehiculoService = VehiculoService();

  String get _usuarioId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,

      // El + siempre significa AGREGAR VEHíCULO.
      floatingActionButton: FloatingActionButton(
        heroTag: 'agregarVehiculo',
        backgroundColor: primaryColor,
        tooltip: 'Agregar vehículo',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RegistrarEditarVehiculoScreen(),
            ),
          );
        },
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 30,
        ),
      ),

      body: Column(
        children: [
          const EncabezadoTagOk(),
          Expanded(child: _buildListaVehiculos()),
        ],
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

        // El vehículo principal vive en el usuario (por patente), el mismo
        // dato que usa la pantalla de Fase 1, el mapa y el perfil.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_usuarioId)
              .snapshots(),
          builder: (context, userSnapshot) {
            final principal =
                (userSnapshot.data?.data()?['vehiculo_principal_id'] ?? '')
                    .toString();

            // Los documentos de todos los vehículos permiten ordenar por
            // urgencia. Firestore limita `whereIn` a 10 valores; con más
            // vehículos se omite ese criterio y el resto del orden se mantiene.
            final ids = vehiculos.map((v) => v.id).toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ids.length <= 10
                  ? FirebaseFirestore.instance
                      .collection('documentos_vehiculares')
                      .where('uid', isEqualTo: _usuarioId)
                      .where('vehiculo_id', whereIn: ids)
                      .snapshots()
                  : null,
              builder: (context, docsSnapshot) {
                final ordenados = _ordenarVehiculos(
                  vehiculos,
                  principal,
                  docsSnapshot.data?.docs,
                );

                return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
          children: [
            // Título de la página: se desplaza con el contenido.
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              child: Text(
                'Mi Vehículo',
                style: TextStyle(
                  color: textMain,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              'Consulta la información, documentos y estado de cada vehículo.',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            ...ordenados.map(
              (vehiculo) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _VehiculoCard(
                  vehiculo: vehiculo,
                  esPrincipal: vehiculo.patente == principal,
                  onMarcarPrincipal: () => _setVehiculoPrincipal(vehiculo.patente),
                  surfaceColor: surfaceColor,
                  surfaceLight: surfaceLight,
                  textMain: textMain,
                  textMuted: textMuted,
                  primaryColor: primaryColor,
                  onTap: () async {
                    await Navigator.push<void>(
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
          },
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
            Text(
              'Mi Vehículo',
              style: TextStyle(
                color: textMain,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Tres tipos de vehículos disponibles
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
              'Aún no tienes vehículos',
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
  // VEHÍCULO PRINCIPAL
  // ================================================================
  // Se elige con la estrella de cada tarjeta de vehículo.

  Future<void> _setVehiculoPrincipal(String patente) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_usuarioId)
          .set(
        {'vehiculo_principal_id': patente},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehículo principal actualizado a $patente'),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo guardar el vehículo principal: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el vehículo principal. Intenta nuevamente.',
          ),
        ),
      );
    }
  }

  /// Orden de la lista de vehículos:
  ///   1. el vehículo principal;
  ///   2. por urgencia de sus documentos (Atención requerida, Próximo
  ///      vencimiento, Todo al día y, al final, Sin información);
  ///   3. por antigüedad de registro (los más antiguos primero; los que no
  ///      guardan fecha son anteriores a este campo, así que van antes);
  ///   4. por patente, para que el orden sea siempre el mismo.
  List<VehiculoModel> _ordenarVehiculos(
    List<VehiculoModel> vehiculos,
    String principal,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs,
  ) {
    final fechas = <String, List<DateTime?>>{};
    for (final doc in docs ?? const []) {
      final data = doc.data();
      final vehiculoId = data['vehiculo_id'];
      if (vehiculoId is! String) continue;

      final vencimiento = data['fecha_vencimiento'];
      fechas
          .putIfAbsent(vehiculoId, () => [])
          .add(vencimiento is Timestamp ? vencimiento.toDate() : null);
    }

    int urgencia(VehiculoModel v) {
      switch (VehiculoModel.calcularEstadoGeneral(fechas[v.id] ?? [])) {
        case 'Atención requerida':
          return 0;
        case 'Próximo vencimiento':
          return 1;
        case 'Todo al día':
          return 2;
        default:
          return 3;
      }
    }

    final ordenados = [...vehiculos];
    ordenados.sort((a, b) {
      final esPrincipalA = a.patente == principal;
      final esPrincipalB = b.patente == principal;
      if (esPrincipalA != esPrincipalB) return esPrincipalA ? -1 : 1;

      final porUrgencia = urgencia(a).compareTo(urgencia(b));
      if (porUrgencia != 0) return porUrgencia;

      final registroA = a.fechaRegistro;
      final registroB = b.fechaRegistro;
      if (registroA != registroB) {
        if (registroA == null) return -1;
        if (registroB == null) return 1;
        final porAntiguedad = registroA.compareTo(registroB);
        if (porAntiguedad != 0) return porAntiguedad;
      }

      return a.patente.compareTo(b.patente);
    });

    return ordenados;
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
  final bool esPrincipal;

  /// Se llama al tocar la estrella: este vehículo pasa a ser el principal.
  final VoidCallback onMarcarPrincipal;
  final Color surfaceColor;
  final Color surfaceLight;
  final Color textMain;
  final Color textMuted;
  final Color primaryColor;
  final VoidCallback onTap;

  const _VehiculoCard({
    required this.vehiculo,
    this.esPrincipal = false,
    required this.onMarcarPrincipal,
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
        return const Color(0xFFF97316);

      case 'Todo al día':
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
            'uid',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '',
          )
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
          child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.transparent,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Todo lo que está por encima del estado abre el detalle.
                  InkWell(
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // -------------------------------------------------
                  // IMAGEN
                  // -------------------------------------------------

                  Container(
                    width: double.infinity,
                    height: 155,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: surfaceLight,
                    ),
                    child: FotoVehiculo(
                      fotoPath: vehiculo.fotoPath,
                      assetPredeterminado: _imagenVehiculo(),
                      paddingPredeterminado:
                          const EdgeInsets.fromLTRB(
                        24,
                        14,
                        24,
                        4,
                      ),
                    ),
                  ),

                  // -------------------------------------------------
                  // DATOS
                  // -------------------------------------------------

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
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
                                        : 'VehÍculo registrado',
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
                            if (esPrincipal)
                              _InfoChip(
                                icon: Icons.star_rounded,
                                texto: 'Principal',
                                color: Colors.amber,
                                textMain: textMain,
                              ),

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

                      ],
                    ),
                  ),
                      ],
                    ),
                  ),

                  // -------------------------------------------------
                  // ESTADO Y ESTRELLA: separados, y no abren el detalle
                  // -------------------------------------------------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: colorEstado.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
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
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Estrella: dorada si es el vehículo principal; si no,
                        // vacía. Al tocarla, este pasa a ser el principal.
                        Tooltip(
                          message: esPrincipal
                              ? 'Vehículo principal'
                              : 'Marcar como vehículo principal',
                          child: InkResponse(
                            onTap: esPrincipal ? null : onMarcarPrincipal,
                            radius: 24,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                esPrincipal
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: esPrincipal ? Colors.amber : textMuted,
                                size: 30,
                              ),
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
