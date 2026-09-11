import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({super.key});

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color accentColor = const Color(0xFF10B981);

  final TextEditingController _patenteController = TextEditingController();
  final TextEditingController _marcaController = TextEditingController();
  String _categoriaSeleccionada = 'AUTO';

  String _vehiculoPrincipalActual = '';

  @override
  void initState() {
    super.initState();
    _cargarVehiculoPrincipal();
  }

  Future<void> _cargarVehiculoPrincipal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('vehiculo_principal_id')) {
        setState(() {
          _vehiculoPrincipalActual = doc.data()!['vehiculo_principal_id'] ?? '';
        });
      }
    }
  }

  Future<void> _setVehiculoPrincipal(String patente) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
        'vehiculo_principal_id': patente,
      });
      setState(() {
        _vehiculoPrincipalActual = patente;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vehículo principal actualizado a $patente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _agregarVehiculo() async {
    final patente = _patenteController.text.trim().toUpperCase();
    final categoria = _categoriaSeleccionada;
    final marca = _marcaController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (patente.isEmpty || user == null) return false;

    // Validación de patente (4 letras y 2 números)
    final patenteRegex = RegExp(r'^[A-Z]{4}\d{2}$');
    if (!patenteRegex.hasMatch(patente)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formato inválido (ej: ABCD12)'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    try {
      // Intentamos guardarlo usando Reference. En la imagen de Firestore
      // se nota que el id_usuario es una referencia al documento (no string).
      final userRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);

      final now = DateTime.now();
      final fechaIngreso = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      await FirebaseFirestore.instance.collection('vehiculos').add({
        'patente': patente,
        'categoria': categoria,
        'marca': marca.isNotEmpty ? marca : 'No especificada',
        'fecha_ingreso': fechaIngreso,
        'id_usuario': userRef, 
      });

      _patenteController.clear();
      _marcaController.clear();
      setState(() {
        _categoriaSeleccionada = 'AUTO';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehículo agregado exitosamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar vehículo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _editarVehiculo(String docId, String patente, String marca, String categoria) async {
    try {
      await FirebaseFirestore.instance.collection('vehiculos').doc(docId).update({
        'patente': patente,
        'categoria': categoria,
        'marca': marca.isNotEmpty ? marca : 'No especificada',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehículo actualizado exitosamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  void _mostrarInfoVehiculo(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: navBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Información del Vehículo', style: TextStyle(color: textMain)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patente: ${data['patente']}', style: TextStyle(color: textMain, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Tipo: ${data['categoria']}', style: TextStyle(color: textMuted, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Marca: ${data['marca'] ?? 'No especificada'}', style: TextStyle(color: textMuted, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Ingresado: ${data['fecha_ingreso'] ?? 'No registrada'}', style: TextStyle(color: textMuted, fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _mostrarFormularioEditarVehiculo(doc);
              },
              child: const Text('Editar', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarFormularioEditarVehiculo(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final TextEditingController patenteCtrl = TextEditingController(text: data['patente']);
    final TextEditingController marcaCtrl = TextEditingController(text: data['marca'] == 'No especificada' ? '' : data['marca']);
    String categoriaSel = data['categoria'] ?? 'AUTO';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: navBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Editar Vehículo', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: patenteCtrl,
                      style: TextStyle(color: textMain),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return TextEditingValue(
                            text: newValue.text.toUpperCase(),
                            selection: newValue.selection,
                          );
                        }),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Patente (ej: ABCD55)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: marcaCtrl,
                      style: TextStyle(color: textMain),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Marca (ej: Toyota, Kia)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categoriaSel,
                      dropdownColor: navBgColor,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Vehículo',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'AUTO', child: Text('AUTO')),
                        DropdownMenuItem(value: 'CAMIONETA', child: Text('CAMIONETA')),
                        DropdownMenuItem(value: 'MOTO', child: Text('MOTO')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            categoriaSel = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final p = patenteCtrl.text.trim().toUpperCase();
                    final m = marcaCtrl.text.trim();
                    final patenteRegex = RegExp(r'^[A-Z]{4}\d{2}$');
                    if (!patenteRegex.hasMatch(p)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Formato inválido (ej: ABCD12)'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    bool success = await _editarVehiculo(doc.id, p, m, categoriaSel);
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _mostrarSelectorVehiculoPrincipal(List<String> patentes) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: navBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Seleccionar Vehículo Principal', style: TextStyle(color: textMain)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patentes.length,
              itemBuilder: (context, index) {
                final pat = patentes[index];
                return ListTile(
                  title: Text(pat, style: TextStyle(color: textMain)),
                  trailing: _vehiculoPrincipalActual == pat
                      ? Icon(Icons.check_circle, color: accentColor)
                      : null,
                  onTap: () {
                    _setVehiculoPrincipal(pat);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarFormularioAgregarVehiculo() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: navBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Agregar Nuevo Vehículo', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _patenteController,
                      style: TextStyle(color: textMain),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return TextEditingValue(
                            text: newValue.text.toUpperCase(),
                            selection: newValue.selection,
                          );
                        }),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Patente (ej: ABCD55)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _marcaController,
                      style: TextStyle(color: textMain),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Marca (ej: Toyota, Kia)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      dropdownColor: navBgColor,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Vehículo',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'AUTO', child: Text('AUTO')),
                        DropdownMenuItem(value: 'CAMIONETA', child: Text('CAMIONETA')),
                        DropdownMenuItem(value: 'MOTO', child: Text('MOTO')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            _categoriaSeleccionada = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    bool success = await _agregarVehiculo();
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Agregar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("No autenticado")));
    }

    final userRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text('Mis Vehículos', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioAgregarVehiculo,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TÍTULO LISTA ---
            Text('Tus Autos Registrados', style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // --- LISTA DE VEHÍCULOS ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('vehiculos')
                    .where('id_usuario', isEqualTo: userRef)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Fallback en caso de que guardaran el id como string
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('vehiculos')
                          .where('id_usuario', isEqualTo: '/usuarios/${user.uid}')
                          .snapshots(),
                      builder: (context, snapshotStr) {
                        if (snapshotStr.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshotStr.hasData || snapshotStr.data!.docs.isEmpty) {
                          return _buildEmptyState();
                        }
                        return _buildListaVehiculos(snapshotStr.data!.docs);
                      }
                    );
                  }

                  return _buildListaVehiculos(snapshot.data!.docs);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_filled_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'Aún no hay vehículos',
            style: TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el botón + para agregar uno',
            style: TextStyle(color: textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildListaVehiculos(List<QueryDocumentSnapshot> docs) {
    // Extraemos las patentes para el selector
    List<String> patentes = docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['patente']?.toString() ?? 'Sin patente';
    }).toList();

    return Column(
      children: [
        // --- BOTÓN PARA ELEGIR VEHÍCULO PRINCIPAL ---
        if (patentes.isNotEmpty)
          InkWell(
            onTap: () => _mostrarSelectorVehiculoPrincipal(patentes),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vehículo Principal', style: TextStyle(color: textMuted, fontSize: 12)),
                        Text(
                          _vehiculoPrincipalActual.isNotEmpty ? _vehiculoPrincipalActual : 'Seleccionar',
                          style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: textMain),
                ],
              ),
            ),
          ),
          
        Expanded(
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final patente = data['patente'] ?? 'Desconocida';
              final categoria = data['categoria'] ?? 'Auto';

              return Card(
                color: navBgColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.directions_car, color: primaryColor),
                  ),
                  title: Text(patente, style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
                  subtitle: Text('${data['marca'] ?? 'Sin marca'} • $categoria', style: TextStyle(color: textMuted)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _mostrarInfoVehiculo(docs[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
