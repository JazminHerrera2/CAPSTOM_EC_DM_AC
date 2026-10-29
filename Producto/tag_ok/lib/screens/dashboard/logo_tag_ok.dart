import 'package:flutter/material.dart';

/// Logo de TAG OK del header del dashboard. Provisional (texto + ícono):
/// cuando se agregue el archivo del logo a `assets/`, solo hay que cambiar
/// este widget por un `Image.asset`.
class LogoTagOk extends StatelessWidget {
  const LogoTagOk({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.directions_car, color: Color(0xFF4F46E5), size: 28),
        SizedBox(width: 6),
        Text(
          'TAG OK',
          style: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
