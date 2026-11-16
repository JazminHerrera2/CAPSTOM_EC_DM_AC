import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Radios de esquina estándar de la app. Usar estos en vez de números sueltos
/// para que todas las pantallas se vean iguales.
abstract final class AppRadios {
  /// Tarjetas y contenedores grandes.
  static const double tarjeta = 20;

  /// Campos de texto, botones y elementos medianos dentro de una tarjeta.
  static const double control = 14;

  /// Contenedores de íconos y fotos pequeñas.
  static const double icono = 12;

  /// Chips y etiquetas.
  static const double chip = 20;

  /// Botones o selectores completamente redondeados en los extremos.
  static const double pildora = 999;
}

/// Sombras estándar de la app.
abstract final class AppSombras {
  /// Sombra suave de las tarjetas blancas sobre el fondo lavanda.
  static const List<BoxShadow> tarjeta = [
    BoxShadow(color: AppColors.sombra, blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Resplandor de una tarjeta de color primario (p. ej. la de gastos).
  static final List<BoxShadow> primaria = [
    BoxShadow(
      color: AppColors.primario.withValues(alpha: 0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Tarjeta estándar: superficie blanca, esquinas de [AppRadios.tarjeta] y
/// sombra suave. Si recibe [onTap], toda la tarjeta es presionable.
class TarjetaApp extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final List<BoxShadow>? sombra;

  const TarjetaApp({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = AppColors.superficie,
    this.sombra = AppSombras.tarjeta,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppRadios.tarjeta);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radio,
        boxShadow: sombra,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radio,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
