import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/auth_provider.dart';
import 'dashboard/logo_tag_ok.dart';
import 'home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Colores extraídos del CSS del mockup
  final Color bgColor = const Color(0xFFF1F5F9);
  final Color primaryColor = const Color(0xFF1E3A8A);
  final Color textMain = const Color(0xFF0F172A);
  final Color textMuted = const Color(0xFF64748B);
  final Color inputBg = const Color(0xFFFFFFFF);
  final Color surfaceBorder = const Color(0xFFCBD5E1);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLogin = true; // Para alternar entre Iniciar Sesión y Registrarse
  bool _verPassword = false;
  bool _verConfirmacion = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }

    if (!_isLogin) {
      final confirmPassword = _confirmPasswordController.text.trim();
      if (confirmPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, confirma tu contraseña.')),
        );
        return;
      }
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contraseñas no coinciden.')),
        );
        return;
      }
    }

    final authNotifier = ref.read(authNotifierProvider.notifier);
    if (_isLogin) {
      authNotifier.signIn(email, password);
    } else {
      authNotifier.signUp(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el estado de autenticación (Cargando, Éxito, Error)
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (next.isSuccess) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });

    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFFDBEAFE), Color(0xFFF1F5F9)],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LogoTagOk(alto: 64)),
                    const SizedBox(height: 16),

                    Text(
                      _isLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLogin
                          ? 'Accede a tu cuenta de TAG OK'
                          : 'Únete a TAG OK',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Correo electrónico',
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _passwordController,
                      hintText: 'Contraseña',
                      icon: Icons.lock_outline,
                      obscureText: !_verPassword,
                      esPassword: true,
                      verPassword: _verPassword,
                      alAlternarVer: () =>
                          setState(() => _verPassword = !_verPassword),
                    ),
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text(
                            'Olvidé mi contraseña',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirmar contraseña',
                        icon: Icons.lock_outline,
                        obscureText: !_verConfirmacion,
                        esPassword: true,
                        verPassword: _verConfirmacion,
                        alAlternarVer: () => setState(
                          () => _verConfirmacion = !_verConfirmacion,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Botón principal
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          // Mismo azul sólido que los demás botones de la app.
                          backgroundColor: primaryColor,
                          disabledBackgroundColor: primaryColor.withValues(
                            alpha: 0.6,
                          ),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isLogin ? 'Iniciar sesión' : 'Registrarse',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Separador:  ------ o ------
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: surfaceBorder, height: 1),
                        ),
                        // Un solo círculo: la letra "o" es el círculo.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: surfaceBorder, height: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Continuar con Google
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: authState.isLoading
                            ? null
                            : () => ref
                                  .read(authNotifierProvider.notifier)
                                  .signInWithGoogle(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: surfaceBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Continuar con Google',
                              style: TextStyle(
                                color: textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Alternar entre Login y Registro: solo la acción va en azul.
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(color: textMuted, fontSize: 13),
                          children: [
                            TextSpan(
                              text: _isLogin
                                  ? '¿No tienes cuenta? '
                                  : '¿Ya tienes cuenta? ',
                            ),
                            TextSpan(
                              text: _isLogin
                                  ? 'Regístrate aquí'
                                  : 'Inicia sesión',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    bool esPassword = false,
    bool verPassword = false,
    VoidCallback? alAlternarVer,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: textMain, fontSize: 14),
        keyboardType: esPassword
            ? TextInputType.text
            : TextInputType.emailAddress,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: textMuted.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: textMuted),
          suffixIcon: esPassword
              ? IconButton(
                  tooltip: verPassword
                      ? 'Ocultar contraseña'
                      : 'Ver contraseña',
                  icon: Icon(
                    verPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: textMuted,
                  ),
                  onPressed: alAlternarVer,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController(
      text: _emailController.text,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Recuperar contraseña',
          style: TextStyle(color: Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu correo electrónico y te enviaremos un enlace seguro para restablecer tu contraseña.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Correo electrónico',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) return;

              Navigator.pop(dialogContext); // Cerrar el diálogo

              // No se consulta Firestore para saber si el correo existe: eso
              // revelaría qué cuentas están registradas. Éxito y
              // user-not-found muestran el mismo mensaje.
              const mensajeNeutro =
                  'Si el correo está registrado, te enviamos un enlace de recuperación.';
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(mensajeNeutro),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  if (e is FirebaseAuthException &&
                      e.code == 'user-not-found') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(mensajeNeutro),
                        backgroundColor: Colors.green,
                      ),
                    );
                    return;
                  }
                  String errorMessage =
                      'No se pudo enviar el correo de recuperación. Inténtalo más tarde.';
                  if (e is FirebaseAuthException && e.code == 'invalid-email') {
                    errorMessage =
                        'El correo electrónico ingresado no es válido.';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $errorMessage'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Enviar Enlace',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
