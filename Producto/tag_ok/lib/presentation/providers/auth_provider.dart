import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Proveedor global del Repositorio de Autenticación
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Proveedor para escuchar si el usuario está logueado o no (Stream)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Clase para manejar el estado visual del Login (Cargando, Error, Éxito)
class AuthState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  AuthState({this.isLoading = false, this.error, this.isSuccess = false});

  AuthState copyWith({bool? isLoading, String? error, bool? isSuccess}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Si no se pasa, se vuelve null explícitamente si queremos limpiar, pero aquí dejaremos que reemplace
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// Notificador que la pantalla de Login observará
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState());

  Future<void> signIn(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      await _authRepository.signInWithEmailAndPassword(email, password);
      state = AuthState(isSuccess: true);
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  Future<void> signUp(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      await _authRepository.signUpWithEmailAndPassword(email, password);
      state = AuthState(isSuccess: true);
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
  }
}

// El Proveedor que se usará en el LoginScreen
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});
