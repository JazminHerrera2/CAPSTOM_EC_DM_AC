import 'package:flutter/material.dart';

/// Logo de TAG OK del encabezado de las pestañas principales.
///
/// El archivo es `assets/imagenes/logo/logo_tagok.png`: el logo original
/// recortado, con fondo transparente, así que se ve directo sobre el fondo de
/// la app. Si el archivo no se puede cargar, se ve el texto "TAG OK".
class LogoTagOk extends StatelessWidget {
  static const String asset = 'assets/imagenes/logo/logo_tagok.png';

  /// Alto del logo.
  final double alto;

  const LogoTagOk({super.key, this.alto = 36});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: alto,
      fit: BoxFit.contain,
      semanticLabel: 'TAG OK',
      errorBuilder: (_, _, _) => SizedBox(
        height: alto,
        child: const Center(
          child: Text(
            'TAG OK',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
