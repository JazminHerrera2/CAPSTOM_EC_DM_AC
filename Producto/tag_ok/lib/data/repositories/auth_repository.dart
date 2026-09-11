import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream para escuchar cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Iniciar Sesión
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Registrarse (Crear cuenta en Auth y Documento en Firestore)
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Crear el modelo de usuario para Firestore
        final nuevoUsuario = UsuarioModel(
          uid: user.uid,
          email: email,
          fechaCreacion: DateTime.now(),
          limitePresupuestoMensual: 50000.0, // Un límite por defecto razonable
        );

        // Guardar en la colección 'usuarios'
        await _firestore
            .collection('usuarios')
            .doc(user.uid)
            .set(nuevoUsuario.toJson());
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Cerrar Sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Manejador de errores amigable
  String _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No se encontró ningún usuario con ese correo.';
        case 'wrong-password':
          return 'La contraseña es incorrecta.';
        case 'email-already-in-use':
          return 'El correo ya está registrado.';
        case 'invalid-email':
          return 'El formato del correo es inválido.';
        case 'weak-password':
          return 'La contraseña es muy débil (mínimo 6 caracteres).';
        default:
          return 'Ocurrió un error de autenticación: ${e.message}';
      }
    }
    return 'Ocurrió un error inesperado.';
  }
}
