import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // Importamos para poder navegar al AdminShell
import 'screens/admin_login_screen.dart';

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha en tiempo real si hay una sesión iniciada en Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // Si no hay usuario logueado, mostrar pantalla de Login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }
        // Si está logueado, pasar al validador de Rol Administrador
        return AdminCheck(user: snapshot.data!);
      },
    );
  }
}

class AdminCheck extends StatefulWidget {
  final User user;
  const AdminCheck({super.key, required this.user});

  @override
  State<AdminCheck> createState() => _AdminCheckState();
}

class _AdminCheckState extends State<AdminCheck> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String _role = 'super_admin';

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      // 1. Buscar por UID del documento
      final docByUid = await FirebaseFirestore.instance.collection('administradores').doc(widget.user.uid).get();
      if (docByUid.exists) {
        final data = docByUid.data() ?? {};
        final String role = (data['rol'] ?? data['role'] ?? 'super_admin').toString();
        setState(() {
          _role = role;
          _isAdmin = true;
          _isLoading = false;
        });
        return;
      }

      // 2. Buscar por email en la colección administradores
      if (widget.user.email != null) {
        final queryByEmail = await FirebaseFirestore.instance
            .collection('administradores')
            .where('email', isEqualTo: widget.user.email)
            .limit(1)
            .get();

        if (queryByEmail.docs.isNotEmpty) {
          final data = queryByEmail.docs.first.data();
          final String role = (data['rol'] ?? data['role'] ?? 'super_admin').toString();
          setState(() {
            _role = role;
            _isAdmin = true;
            _isLoading = false;
          });
          return;
        }
      }

      // Si no existe en la tabla de admins, lo expulsa.
      await FirebaseAuth.instance.signOut();
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isAdmin) {
      // Todo perfecto, lo dejamos entrar al panel de administración con su rol
      return AdminShell(role: _role);
    }
    // Fue expulsado, mostrar mensaje
    return const LoginScreen(errorMessage: 'Acceso denegado. Tu cuenta no tiene permisos de administrador.');
  }
}

/// Conecta el diseño nuevo (`AdminLoginScreen`, solo presentación) con el
/// ingreso de Firebase. El diseño llama a [_login] con el correo y la
/// contraseña; devuelve `null` si salió bien o el mensaje de error.
class LoginScreen extends StatelessWidget {
  final String? errorMessage;
  const LoginScreen({super.key, this.errorMessage});

  Future<String?> _login(String email, String password) async {
    try {
      // Intentar ingresar. Si es correcto, el AdminAuthGate detectará el cambio y hará el resto.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Error al iniciar sesión.';
    } catch (e) {
      return 'Ocurrió un error inesperado.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLoginScreen(onLogin: _login, errorMessage: errorMessage);
  }
}
