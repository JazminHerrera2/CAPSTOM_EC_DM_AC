import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color accentColor = const Color(
    0xFF10B981,
  ); // Verde para el presupuesto

  @override
  Widget build(BuildContext context) {
    // Obtenemos el usuario que inició sesión en este momento
    final user = FirebaseAuth.instance.currentUser;

    // Si por alguna razón no hay sesión activa, evitamos errores
    if (user == null) {
      return Center(
        child: Text(
          "No hay un usuario logueado",
          style: TextStyle(color: textMain),
        ),
      );
    }

    // Usamos StreamBuilder para escuchar en tiempo real la base de datos de ESTE usuario
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Mientras carga desde Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error al cargar perfil",
              style: TextStyle(color: textMain),
            ),
          );
        }

        // Datos por defecto (por si acaso el documento está vacío en algunas partes)
        String nombre = 'Usuario Tag OK';
        String email = user.email ?? 'Sin correo';
        int limiteNum = 50000;
        String limitePresupuesto = '\$50.000'; // Default si no tiene límite
        String vehiculoPrincipal = 'Ninguno';
        String miembroDesde = 'Reciente';

        Map<String, dynamic> userData = {};
        // Si Firebase devolvió la data exitosamente, reescribimos los valores
        if (snapshot.hasData && snapshot.data!.exists) {
          userData = snapshot.data!.data() as Map<String, dynamic>;
          final data = userData;

          if (data['nombre_mostrar'] != null &&
              data['nombre_mostrar'].toString().isNotEmpty) {
            nombre = data['nombre_mostrar'];
          }

          if (data['email'] != null) {
            email = data['email'];
          }

          if (data['limite_presupuesto_mensual'] != null) {
            final val = data['limite_presupuesto_mensual'];
            if (val is int) {
              limiteNum = val;
            } else if (val is String) {
              limiteNum = int.tryParse(val) ?? 50000;
            }
            limitePresupuesto = '\$$limiteNum';
          }

          if (data['vehiculo_principal_id'] != null &&
              data['vehiculo_principal_id'].toString().isNotEmpty) {
            vehiculoPrincipal = data['vehiculo_principal_id'];
          }

          if (data['fecha_creacion'] != null) {
            final Timestamp ts = data['fecha_creacion'];
            final DateTime date = ts.toDate();
            // Formatear mes en español
            final meses = [
              'Ene',
              'Feb',
              'Mar',
              'Abr',
              'May',
              'Jun',
              'Jul',
              'Ago',
              'Sep',
              'Oct',
              'Nov',
              'Dic',
            ];
            miembroDesde = '${meses[date.month - 1]} ${date.year}';
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Foto de Perfil con botón de edición flotante
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: navBgColor,
                      child: Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _mostrarDialogoEdicion(
                        context,
                        user.uid,
                        nombre == 'Usuario Tag OK' ? '' : nombre,
                        limiteNum,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: bgColor,
                            width: 3,
                          ), // Borde para que resalte
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nombre y Correo
              Text(
                nombre,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(email, style: TextStyle(fontSize: 14, color: textMuted)),
              const SizedBox(height: 32),

              // 2. Panel de Resumen (Tarjetas)
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Límite Mensual',
                      value: limitePresupuesto,
                      icon: Icons.account_balance_wallet_outlined,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Vehículo Principal',
                      value: vehiculoPrincipal,
                      icon: Icons.directions_car_outlined,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _buildSummaryCard(
                  title: 'Miembro desde',
                  value: miembroDesde,
                  icon: Icons.calendar_month_outlined,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // 3. Opciones del Menú
              _buildProfileOption(
                icon: Icons.notifications_none_outlined,
                title: 'Notificaciones / Alertas',
                onTap: () => _mostrarOpcionesNotificaciones(context, user.uid, userData),
              ),
              const SizedBox(height: 16),
              _buildProfileOption(
                icon: Icons.lock_outline,
                title: 'Seguridad y Contraseña',
                onTap: () {},
              ),
              const SizedBox(height: 32),

              // 4. Botón de Cerrar Sesión
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Cerrar sesión real en Firebase
                    await FirebaseAuth.instance.signOut();

                    // Volver a la pantalla de inicio de sesión eliminando el historial
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarOpcionesNotificaciones(BuildContext context, String uid, Map<String, dynamic> userData) {
    bool cobros = userData['notif_cobros'] ?? true;
    bool presupuesto = userData['notif_presupuesto'] ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: navBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notificaciones y Alertas',
                    style: TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Administra qué alertas quieres recibir en tu dispositivo.',
                    style: TextStyle(color: textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    activeColor: primaryColor,
                    title: Text('Nuevos cobros de TAG', style: TextStyle(color: textMain)),
                    subtitle: Text('Recibe una alerta cada vez que pases por un pórtico.', style: TextStyle(color: textMuted, fontSize: 12)),
                    value: cobros,
                    onChanged: (val) {
                      setModalState(() => cobros = val);
                      FirebaseFirestore.instance.collection('usuarios').doc(uid).set({'notif_cobros': val}, SetOptions(merge: true));
                    },
                  ),
                  SwitchListTile(
                    activeColor: primaryColor,
                    title: Text('Alertas de Presupuesto', style: TextStyle(color: textMain)),
                    subtitle: Text('Te avisaremos cuando te acerques a tu límite mensual.', style: TextStyle(color: textMuted, fontSize: 12)),
                    value: presupuesto,
                    onChanged: (val) {
                      setModalState(() => presupuesto = val);
                      FirebaseFirestore.instance.collection('usuarios').doc(uid).set({'notif_presupuesto': val}, SetOptions(merge: true));
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Listo', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      },
    );
  }

  // --- FUNCIÓN PARA MOSTRAR LA VENTANA EMERGENTE DE EDICIÓN ---
  void _mostrarDialogoEdicion(
    BuildContext context,
    String uid,
    String nombreActual,
    int limiteActual,
  ) {
    final TextEditingController nombreController = TextEditingController(
      text: nombreActual,
    );
    final TextEditingController limiteController = TextEditingController(
      text: limiteActual.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: navBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Editar Perfil',
            style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize
                .min, // Para que el cuadro no ocupe toda la pantalla
            children: [
              TextField(
                controller: nombreController,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(
                  labelText: 'Nombre a mostrar',
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textMuted.withOpacity(0.5)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  prefixIcon: Icon(Icons.person_outline, color: textMuted),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: limiteController,
                style: TextStyle(color: textMain),
                keyboardType:
                    TextInputType.number, // Muestra el teclado numérico
                decoration: InputDecoration(
                  labelText: 'Límite Mensual (\$)',
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textMuted.withOpacity(0.5)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  prefixIcon: Icon(Icons.attach_money, color: textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final nuevoNombre = nombreController.text.trim();
                final nuevoLimite =
                    int.tryParse(limiteController.text.trim()) ?? limiteActual;

                // Actualizar en Firebase la tabla de "usuarios"
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(uid)
                    .update({
                      'nombre_mostrar': nuevoNombre,
                      'limite_presupuesto_mensual': nuevoLimite,
                    });

                if (context.mounted) {
                  Navigator.pop(context); // Cerrar el diálogo cuando termine
                }
              },
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- HELPERS PARA EL DISEÑO ---
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: navBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: navBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}
