import 'package:flutter/material.dart';
import 'package:tag_ok/theme/app_colors.dart';

/// Aviso previo a abrir la cámara: una foto nítida y bien iluminada mejora
/// bastante la lectura de la IA. Devuelve `true` si el usuario quiere seguir
/// y tomar la foto, `false` si cancela.
Future<bool> mostrarConsejosCaptura(BuildContext context) async {

  Widget consejo(IconData icono, String texto) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(color: AppColors.textoSecundario, height: 1.3),
              ),
            ),
          ],
        ),
      );

  final seguir = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.light_mode_outlined, color: Colors.amber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Antes de tomar la foto',
              style: TextStyle(color: AppColors.texto, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Con una buena imagen la IA lee tus datos con mayor precisión.',
            style: TextStyle(color: AppColors.texto),
          ),
          consejo(Icons.wb_sunny_outlined,
              'Busca un lugar con buena iluminación, de preferencia luz natural.'),
          consejo(Icons.flash_off,
              'Evita sombras y reflejos o brillos sobre el documento.'),
          consejo(Icons.crop_free,
              'Encuadra el documento completo, sobre una superficie plana.'),
          consejo(Icons.center_focus_strong_outlined,
              'Mantén el teléfono firme para que la foto no salga borrosa.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.textoSecundario)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primario,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Entendido, tomar foto',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  return seguir ?? false;
}
