import 'package:flutter/material.dart';
import 'package:tag_ok/theme/app_colors.dart';
import 'package:tag_ok/theme/app_estilos.dart';

/// Pregunta al usuario si realmente quiere cerrar sesión. Devuelve `true` solo
/// si confirma; al cancelar o cerrar el diálogo devuelve `false`.
Future<bool> confirmarCerrarSesion(BuildContext context) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¿Cerrar sesión?',
                style: TextStyle(color: AppColors.texto),
              ),
            ),
          ],
        ),
        content: const Text(
          'Tendrás que volver a iniciar sesión para usar la aplicación.',
          style: TextStyle(color: AppColors.textoSecundario, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      );
    },
  );

  return confirmado == true;
}
