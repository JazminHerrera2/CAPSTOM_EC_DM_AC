import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/models/documento_vehicular_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/vehiculo_service.dart';
import 'detalle_vehiculo_screen.dart';
import 'documentos_vehiculo_seccion.dart';
import 'foto_vehiculo.dart';
import 'registrar_editar_vehiculo_screen.dart';

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

  // Filtro de la pestaña Documentos: id del vehículo, o null para todos.
  String? _filtroVehiculoId;

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
          'Mi VehÍculo',
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
                    label: 'Mis Vehículos',
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
        height: 44,
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
              size: 19,
            ),
            const SizedBox(width: 8),
            Flexible(
              // Una sola línea y sin cortar la palabra: si no cabe, se reduce
              // el tamaño del texto en vez de partirlo o truncarlo.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: activo ? Colors.white : textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Text(
              'Consulta la información, documentos y estado de cada vehículo.',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            _buildVehiculoPrincipal(vehiculos, principal),

            const SizedBox(height: 18),

            ...ordenados.map(
              (vehiculo) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _VehiculoCard(
                  vehiculo: vehiculo,
                  esPrincipal: vehiculo.patente == principal,
                  surfaceColor: surfaceColor,
                  surfaceLight: surfaceLight,
                  textMain: textMain,
                  textMuted: textMuted,
                  primaryColor: primaryColor,
                  onTap: () async {
                    final resultado = await Navigator.push<Object>(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetalleVehiculoScreen(vehiculo: vehiculo),
                      ),
                    );

                    // "Ver más detalles" en el detalle del vehículo pide abrir
                    // la pestaña Documentos, filtrada por ese vehículo.
                    if (resultado is VerDocumentosDe && mounted) {
                      setState(() {
                        _activeSubTab = 1;
                        _filtroVehiculoId = resultado.vehiculoId;
                      });
                    }
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
                    'Primero agrega un vehículo',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los documentos registrados para tus vehículos aparecerán aquí.',
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

        // Si el vehículo filtrado ya no existe (p. ej. se eliminó), se vuelve
        // a mostrar todo.
        final filtroActivo =
            idsVehiculos.contains(_filtroVehiculoId) ? _filtroVehiculoId : null;

        return Column(
          children: [
            _buildFiltrosDocumentos(vehiculos, filtroActivo),
            Expanded(
              child: StreamBuilder<
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

            // Documentos agrupados por vehículo, en el orden de la lista de
            // vehículos. Los vehículos sin documentos no aparecen.
            final porVehiculo = <String, List<DocumentoVehicularModel>>{};
            for (final doc in docs) {
              final documento =
                  DocumentoVehicularModel.fromJson(doc.data(), doc.id);
              porVehiculo
                  .putIfAbsent(documento.vehiculoId, () => [])
                  .add(documento);
            }

            // Todos los vehículos aparecen, también los que aún no tienen
            // documentos (con el botón para agregar el primero).
            final secciones = <Widget>[];
            for (final vehiculo in vehiculos) {
              if (filtroActivo != null && vehiculo.id != filtroActivo) {
                continue;
              }

              final lista = porVehiculo[vehiculo.id] ?? [];

              lista.sort(
                (a, b) =>
                    a.tipoDocumento.index.compareTo(b.tipoDocumento.index),
              );

              // Línea que separa un vehículo del siguiente.
              if (secciones.isNotEmpty) {
                secciones.add(const SizedBox(height: 14));
                secciones.add(
                  const Divider(
                    color: Color(0xFF475569),
                    thickness: 1,
                    height: 1,
                  ),
                );
                secciones.add(const SizedBox(height: 26));
              }
              secciones.add(
                DocumentosVehiculoSeccion(
                  vehiculoId: vehiculo.id,
                  patenteVehiculo: vehiculo.patente,
                  documentos: lista,
                  mostrarTitulo: false,
                  mostrarBotonAgregar: true,
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: secciones,
            );
          },
        ),
            ),
          ],
        );
      },
    );
  }

  /// Botones de filtro: "Todos" y uno por cada patente. Salen de la lista de
  /// vehículos, así que al registrar uno nuevo aparece su botón solo.
  Widget _buildFiltrosDocumentos(
    List<VehiculoModel> vehiculos,
    String? filtroActivo,
  ) {
    Widget boton(String texto, bool activo, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: activo ? primaryColor : surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activo ? primaryColor : const Color(0xFF334155),
            ),
          ),
          child: Text(
            texto,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: activo ? Colors.white : textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          boton(
            'Todos',
            filtroActivo == null,
            () => setState(() => _filtroVehiculoId = null),
          ),
          for (final vehiculo in vehiculos) ...[
            const SizedBox(width: 8),
            boton(
              vehiculo.patente,
              filtroActivo == vehiculo.id,
              () => setState(() => _filtroVehiculoId = vehiculo.id),
            ),
          ],
        ],
      ),
    );
  }

  // ================================================================
  // VEHÍCULO PRINCIPAL
  // ================================================================

  Widget _buildVehiculoPrincipal(
    List<VehiculoModel> vehiculos,
    String principal,
  ) {
    final actual = vehiculos
        .where((v) => v.patente == principal)
        .cast<VehiculoModel?>()
        .firstWhere((_) => true, orElse: () => null);

    final detalle = actual == null
        ? null
        : [actual.marca, actual.modelo]
            .where((e) => e != null && e.trim().isNotEmpty)
            .join(' ');

    return InkWell(
      onTap: () => _mostrarSelectorPrincipal(vehiculos, principal),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withOpacity(0.6),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.star_rounded,
              color: Colors.amber,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehículo principal',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    actual == null
                        ? 'Seleccionar'
                        : (detalle != null && detalle.isNotEmpty
                            ? '${actual.patente} · $detalle'
                            : actual.patente),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: textMain,
            ),
          ],
        ),
      ),
    );
  }

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

  void _mostrarSelectorPrincipal(
    List<VehiculoModel> vehiculos,
    String principal,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Seleccionar vehículo principal',
            style: TextStyle(color: textMain),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: vehiculos.length,
              itemBuilder: (context, index) {
                final vehiculo = vehiculos[index];
                final detalle = [vehiculo.alias, vehiculo.marca, vehiculo.modelo]
                    .where((e) => e != null && e.trim().isNotEmpty)
                    .take(2)
                    .join(' · ');

                return ListTile(
                  title: Text(
                    vehiculo.patente,
                    style: TextStyle(color: textMain),
                  ),
                  subtitle: detalle.isEmpty
                      ? null
                      : Text(
                          detalle,
                          style: TextStyle(color: textMuted),
                        ),
                  trailing: vehiculo.patente == principal
                      ? Icon(Icons.check_circle, color: primaryColor)
                      : null,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _setVehiculoPrincipal(vehiculo.patente);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
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
  final Color surfaceColor;
  final Color surfaceLight;
  final Color textMain;
  final Color textMuted;
  final Color primaryColor;
  final VoidCallback onTap;

  const _VehiculoCard({
    required this.vehiculo,
    this.esPrincipal = false,
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
