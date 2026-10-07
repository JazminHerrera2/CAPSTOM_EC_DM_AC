import 'package:flutter/material.dart';

/// Pregunta al usuario si realmente quiere cerrar sesión. Devuelve `true` solo
/// si confirma; al cancelar o cerrar el diálogo devuelve `false`.
Future<bool> confirmarCerrarSesion(BuildContext context) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFE11D48)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¿Cerrar sesión?',
                style: TextStyle(color: Color(0xFFF8FAFC)),
              ),
            ),
          ],
        ),
        content: const Text(
          'Tendrás que volver a iniciar sesión para usar la aplicación.',
          style: TextStyle(color: Color(0xFF94A3B8), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE11D48),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      );
    },
  );

  return confirmado == true;
}
