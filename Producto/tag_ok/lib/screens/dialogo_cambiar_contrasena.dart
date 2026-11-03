import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Diálogo "Cambiar contraseña": pide la actual (Firebase exige volver a
/// autenticar para una operación sensible), la nueva y su confirmación.
///
/// Es un widget propio (y no un `StatefulBuilder` dentro de un método) para que
/// los controladores de texto se creen y se liberen con el propio diálogo: así
/// no se destruyen mientras el diálogo todavía se está cerrando en pantalla.
class DialogoCambiarContrasena extends StatefulWidget {
  final User user;
  final String email;

  const DialogoCambiarContrasena({
    super.key,
    required this.user,
    required this.email,
  });

  @override
  State<DialogoCambiarContrasena> createState() =>
      _DialogoCambiarContrasenaState();
}

class _DialogoCambiarContrasenaState extends State<DialogoCambiarContrasena> {
  static const Color _primary = Color(0xFF1E3A8A);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _textMain = Color(0xFF0F172A);

  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  String? _error;
  bool _guardando = false;
  bool _verActual = false;
  bool _verNueva = false;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  InputDecoration _campo(String etiqueta, {bool? visible, VoidCallback? alternar}) {
    return InputDecoration(
      labelText: etiqueta,
      labelStyle: const TextStyle(color: _textMuted),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _primary),
      ),
      suffixIcon: alternar == null
          ? null
          : IconButton(
              icon: Icon(
                visible == true ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: _textMuted,
                size: 20,
              ),
              onPressed: alternar,
            ),
    );
  }

  Future<void> _guardar() async {
    final actual = _actualCtrl.text;
    final nueva = _nuevaCtrl.text;

    String? problema;
    if (actual.isEmpty || nueva.isEmpty || _confirmarCtrl.text.isEmpty) {
      problema = 'Completa los tres campos.';
    } else if (nueva.length < 6) {
      problema = 'La nueva contraseña debe tener al menos 6 caracteres.';
    } else if (nueva != _confirmarCtrl.text) {
      problema = 'La confirmación no coincide con la nueva contraseña.';
    } else if (nueva == actual) {
      problema = 'La nueva contraseña debe ser distinta de la actual.';
    }
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }

    setState(() {
      _error = null;
      _guardando = true;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: widget.email, password: actual),
      );
      await widget.user.updatePassword(nueva);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada correctamente.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } on FirebaseAuthException catch (e) {
      final mensaje = switch (e.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          'La contraseña actual no es correcta.',
        'weak-password' => 'La nueva contraseña es muy débil.',
        'too-many-requests' =>
          'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
        'network-request-failed' =>
          'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
        'requires-recent-login' =>
          'Por seguridad, cierra sesión, vuelve a entrar e inténtalo de nuevo.',
        _ => 'No se pudo cambiar la contraseña. Inténtalo de nuevo.',
      };
      if (!mounted) return;
      setState(() {
        _error = mensaje;
        _guardando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cambiar la contraseña. Inténtalo de nuevo.';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Cambiar contraseña',
        style: TextStyle(color: _textMain, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _actualCtrl,
              obscureText: !_verActual,
              enabled: !_guardando,
              style: const TextStyle(color: _textMain),
              decoration: _campo(
                'Contraseña actual',
                visible: _verActual,
                alternar: () => setState(() => _verActual = !_verActual),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nuevaCtrl,
              obscureText: !_verNueva,
              enabled: !_guardando,
              style: const TextStyle(color: _textMain),
              decoration: _campo(
                'Nueva contraseña',
                visible: _verNueva,
                alternar: () => setState(() => _verNueva = !_verNueva),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmarCtrl,
              obscureText: !_verNueva,
              enabled: !_guardando,
              style: const TextStyle(color: _textMain),
              decoration: _campo('Confirmar nueva contraseña'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: _textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
