import 'package:flutter/material.dart';
import 'package:tag_ok/theme/app_colors.dart';

/// Logotipo de TAG OK del encabezado de las pestañas principales: "TAG" en el
/// color de texto y "OK" en cursiva con el color primario de la marca.
///
/// Se dibuja con texto (no con imagen) para que siga la paleta de
/// [AppColors] y se vea nítido en cualquier densidad de pantalla.
class LogoTagOk extends StatelessWidget {
  /// Alto aproximado del logotipo.
  final double alto;

  const LogoTagOk({super.key, this.alto = 36});

  @override
  Widget build(BuildContext context) {
    final tamano = alto * 0.78;
    return Semantics(
      label: 'TAG OK',
      excludeSemantics: true,
      child: SizedBox(
        height: alto,
        child: Center(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: tamano,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1,
              ),
              children: const [
                TextSpan(
                  text: 'TAG',
                  style: TextStyle(color: AppColors.texto),
                ),
                TextSpan(
                  text: 'OK',
                  style: TextStyle(
                    color: AppColors.primario,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
