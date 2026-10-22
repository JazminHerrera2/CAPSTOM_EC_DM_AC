import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'odometro_extraction.dart';

/// Botón "Fotografiar velocímetro con IA": abre la cámara, la IA lee el
/// kilometraje total del odómetro y se lo entrega a [onKilometraje] para que
/// el formulario lo escriba en su campo (el usuario puede corregirlo). La foto
/// no se guarda. Lo usan el formulario de vehículo y el de mantenciones.
class BotonFotoVelocimetro extends StatefulWidget {
  final ValueChanged<int> onKilometraje;

  const BotonFotoVelocimetro({super.key, required this.onKilometraje});

  @override
  State<BotonFotoVelocimetro> createState() => _BotonFotoVelocimetroState();
}

class _BotonFotoVelocimetroState extends State<BotonFotoVelocimetro> {
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color primaryColor = Color(0xFF4F46E5);

  // La IA está leyendo la foto.
  bool _leyendo = false;

  void _aviso(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _fotografiar() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (foto == null || !mounted) return;

    setState(() => _leyendo = true);
    try {
      final km = await extraerKilometraje(
        bytes: await foto.readAsBytes(),
        mimeType: 'image/jpeg',
      );
      if (!mounted) return;

      if (km == null) {
        _aviso('No se pudo leer el kilometraje. Toma otra foto o escríbelo.');
        return;
      }

      widget.onKilometraje(km);
      _aviso('Kilometraje leído: $km km. Revísalo antes de guardar.');
    } catch (e) {
      debugPrint('No se pudo leer el velocímetro: $e');
      if (!mounted) return;
      _aviso(
        'No se pudo analizar la foto. Intenta de nuevo o escribe el kilometraje.',
      );
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _leyendo ? null : _fotografiar,
            icon: _leyendo
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  )
                : const Icon(
                    Icons.photo_camera_outlined,
                    color: primaryColor,
                    size: 22,
                  ),
            label: Text(
              _leyendo
                  ? 'Leyendo el velocímetro...'
                  : 'Fotografiar velocímetro con IA',
              style: const TextStyle(
                color: textMain,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: primaryColor.withOpacity(0.10),
              side: BorderSide(color: primaryColor.withOpacity(0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Con el vehículo encendido, toma una foto donde se vea el '
          'kilometraje total (no el parcial "TRIP").',
          style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}
