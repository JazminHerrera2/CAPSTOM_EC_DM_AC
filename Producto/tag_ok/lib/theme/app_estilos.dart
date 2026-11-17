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
  static List<BoxShadow> get tarjeta => [
    BoxShadow(color: AppColors.sombra, blurRadius: 16, offset: const Offset(0, 4)),
  ];

  /// Resplandor de la tarjeta violeta de gastos.
  static List<BoxShadow> get primaria => [
    BoxShadow(
      color: AppColors.violeta.withValues(alpha: AppColors.oscuro ? 0.25 : 0.35),
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
  /// Fondo; por defecto [AppColors.superficie].
  final Color? color;

  /// Sombra; por defecto [AppSombras.tarjeta].
  final List<BoxShadow>? sombra;

  const TarjetaApp({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.sombra,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppRadios.tarjeta);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.superficie,
        borderRadius: radio,
        boxShadow: sombra ?? AppSombras.tarjeta,
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
