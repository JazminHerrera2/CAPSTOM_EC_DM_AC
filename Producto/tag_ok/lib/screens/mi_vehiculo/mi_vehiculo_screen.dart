import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/documento_vehicular_model.dart';
import '../../data/models/vehiculo_model.dart';
import '../../data/services/vehiculo_service.dart';
import 'detalle_vehiculo_screen.dart';
import 'registrar_editar_vehiculo_screen.dart';

/// Entry point de Mi Vehículo (EP-01). Sub-tabs: "Mis Vehículos" (CU1/CU2/CU5)
/// y "Documentos" (vista agregada de todos los vehículos, acceso rápido a
/// CU3/CU4).
class MiVehiculoScreen extends StatefulWidget {
  const MiVehiculoScreen({super.key});

  @override
  State<MiVehiculoScreen> createState() => _MiVehiculoScreenState();
}

class _MiVehiculoScreenState extends State<MiVehiculoScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color surfaceColor = const Color(0xFF1E293B);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF4F46E5);

  final VehiculoService _vehiculoService = VehiculoService();

  int _activeSubTab = 0;

  String get _usuarioId => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Atención requerida':
        return Colors.redAccent;
      case 'Próximo vencimiento':
        return const Color(0xFFF59E0B);
      case 'Todo al día':
        return const Color(0xFF10B981);
      default:
        return textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('Mi Vehículo', style: TextStyle(color: textMain)),
        iconTheme: IconThemeData(color: textMain),
      ),
      floatingActionButton: _activeSubTab == 0
          ? FloatingActionButton(
              backgroundColor: primaryColor,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegistrarEditarVehiculoScreen(),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('Mis Vehículos', 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton('Documentos', 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _activeSubTab == 0 ? _buildListaVehiculos() : _buildDocumentosAgregados(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final activo = _activeSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: activo ? primaryColor : surfaceColor,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: activo ? Colors.white : textMuted, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildListaVehiculos() {
    return StreamBuilder<List<VehiculoModel>>(
      stream: _vehiculoService.streamVehiculosUsuario(_usuarioId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final vehiculos = snapshot.data ?? [];
        if (vehiculos.isEmpty) {
          return Center(
            child: Text(
              'Aún no tienes vehículos registrados.\nPresiona + para agregar uno.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehiculos.length,
          itemBuilder: (context, index) {
            final v = vehiculos[index];
            return _VehiculoCard(
              vehiculo: v,
              surfaceColor: surfaceColor,
              textMain: textMain,
              textMuted: textMuted,
              primaryColor: primaryColor,
              colorEstado: _colorEstado,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetalleVehiculoScreen(vehiculo: v),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentosAgregados() {
    return StreamBuilder<List<VehiculoModel>>(
      stream: _vehiculoService.streamVehiculosUsuario(_usuarioId),
      builder: (context, snapshotVehiculos) {
        final vehiculos = snapshotVehiculos.data ?? [];
        if (vehiculos.isEmpty) {
          return Center(
            child: Text('Registra un vehículo primero.', style: TextStyle(color: textMuted)),
          );
        }
        final idsVehiculos = vehiculos.map((v) => v.id).toList();
        final patentesPorId = {for (final v in vehiculos) v.id: v.patente};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('documentos_vehiculares')
              .where('vehiculo_id', whereIn: idsVehiculos)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Text('Aún no hay documentos registrados.', style: TextStyle(color: textMuted)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = DocumentoVehicularModel.fromJson(docs[index].data(), docs[index].id);
                final patente = patentesPorId[doc.vehiculoId] ?? 'Vehículo';
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
                    title: Text('${doc.tipoDocumento.etiqueta} — $patente', style: TextStyle(color: textMain)),
                    subtitle: Text(
                      doc.fechaVencimiento != null
                          ? 'Vence: ${DateFormat('dd/MM/yyyy').format(doc.fechaVencimiento!)}'
                          : 'Sin fecha de vencimiento configurada',
                      style: TextStyle(color: vencido ? Colors.redAccent : textMuted),
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
}

class _VehiculoCard extends StatelessWidget {
  final VehiculoModel vehiculo;
  final Color surfaceColor;
  final Color textMain;
  final Color textMuted;
  final Color primaryColor;
  final Color Function(String estado) colorEstado;
  final VoidCallback onTap;

  const _VehiculoCard({
    required this.vehiculo,
    required this.surfaceColor,
    required this.textMain,
    required this.textMuted,
    required this.primaryColor,
    required this.colorEstado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('documentos_vehiculares')
          .where('vehiculo_id', isEqualTo: vehiculo.id)
          .snapshots(),
      builder: (context, snapshot) {
        final fechas = (snapshot.data?.docs ?? [])
            .map((d) => (d.data()['fecha_vencimiento'] as Timestamp?)?.toDate())
            .toList();
        final estado = VehiculoModel.calcularEstadoGeneral(fechas);

        return Card(
          color: surfaceColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            onTap: onTap,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.directions_car, color: primaryColor),
            ),
            title: Text(
              vehiculo.alias?.isNotEmpty == true ? vehiculo.alias! : vehiculo.patente,
              style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''}'.trim(),
                  style: TextStyle(color: textMuted),
                ),
                const SizedBox(height: 4),
                Text(estado, style: TextStyle(color: colorEstado(estado), fontWeight: FontWeight.w600)),
              ],
            ),
            trailing: Icon(Icons.chevron_right, color: textMuted),
          ),
        );
      },
    );
  }
}
