import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({super.key});

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {

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
            backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.superficie,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
          title: Text('Información del Vehículo', style: TextStyle(color: AppColors.texto)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patente: ${data['patente']}', style: TextStyle(color: AppColors.texto, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Tipo: ${data['categoria']}', style: TextStyle(color: AppColors.textoSecundario, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Marca: ${data['marca'] ?? 'No especificada'}', style: TextStyle(color: AppColors.textoSecundario, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Ingresado: ${data['fecha_ingreso'] ?? 'No registrada'}', style: TextStyle(color: AppColors.textoSecundario, fontSize: 14)),
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
              backgroundColor: AppColors.superficie,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
              title: Text('Editar Vehículo', style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: patenteCtrl,
                      style: TextStyle(color: AppColors.texto),
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
                        labelStyle: TextStyle(color: AppColors.textoSecundario),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textoSecundario.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primario)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: marcaCtrl,
                      style: TextStyle(color: AppColors.texto),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Marca (ej: Toyota, Kia)',
                        labelStyle: TextStyle(color: AppColors.textoSecundario),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textoSecundario.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primario)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categoriaSel,
                      dropdownColor: AppColors.superficie,
                      style: TextStyle(color: AppColors.texto),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Vehículo',
                        labelStyle: TextStyle(color: AppColors.textoSecundario),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textoSecundario.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primario)),
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
                  child: Text('Cancelar', style: TextStyle(color: AppColors.textoSecundario)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primario,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.control)),
                  ),
                  onPressed: () async {
                    final p = patenteCtrl.text.trim().toUpperCase();
                    final m = marcaCtrl.text.trim();
                    final patenteRegex = RegExp(r'^[A-Z]{4}\d{2}$');
                    if (!patenteRegex.hasMatch(p)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Formato inválido (ej: ABCD12)'),
                          backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.superficie,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
          title: Text('Seleccionar Vehículo Principal', style: TextStyle(color: AppColors.texto)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patentes.length,
              itemBuilder: (context, index) {
                final pat = patentes[index];
                return ListTile(
                  title: Text(pat, style: TextStyle(color: AppColors.texto)),
                  trailing: _vehiculoPrincipalActual == pat
                      ? Icon(Icons.check_circle, color: AppColors.exito)
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
              backgroundColor: AppColors.superficie,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
              title: Text('Agregar Nuevo Vehículo', style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _patenteController,
                      style: TextStyle(color: AppColors.texto),
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
                        labelStyle: TextStyle(color: AppColors.textoSecundario),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textoSecundario.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primario)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _marcaController,
                      style: TextStyle(color: AppColors.texto),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Marca (ej: Toyota, Kia)',
                        labelStyle: TextStyle(color: AppColors.textoSecundario),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textoSecundario.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primario)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      dropdownColor: AppColors.superficie,
                      style: TextStyle(color: AppColors.texto),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Vehículo',
                        labelStyle: TextStyle(color: AppColors.textoSecundario),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textoSecundario.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primario)),
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
                  child: Text('Cancelar', style: TextStyle(color: AppColors.textoSecundario)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primario,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.control)),
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
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        title: const Text('Mis Vehículos', style: TextStyle(color: AppColors.texto)),
        iconTheme: const IconThemeData(color: AppColors.texto),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioAgregarVehiculo,
        backgroundColor: AppColors.primario,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TÍTULO LISTA ---
            Text('Tus Autos Registrados', style: TextStyle(color: AppColors.texto, fontSize: 18, fontWeight: FontWeight.bold)),
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
          Icon(Icons.directions_car_filled_outlined, size: 80, color: AppColors.contenedorSuave),
          const SizedBox(height: 16),
          Text(
            'Aún no hay vehículos',
            style: TextStyle(color: AppColors.texto, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el botón + para agregar uno',
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 16),
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
            borderRadius: BorderRadius.circular(AppRadios.icono),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primario.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppRadios.icono),
                border: Border.all(color: AppColors.primario),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vehículo Principal', style: TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
                        Text(
                          _vehiculoPrincipalActual.isNotEmpty ? _vehiculoPrincipalActual : 'Seleccionar',
                          style: TextStyle(color: AppColors.texto, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: AppColors.texto),
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
                color: AppColors.superficie,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.tarjeta)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.fondo,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.directions_car, color: AppColors.primario),
                  ),
                  title: Text(patente, style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold)),
                  subtitle: Text('${data['marca'] ?? 'Sin marca'} • $categoria', style: TextStyle(color: AppColors.textoSecundario)),
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
