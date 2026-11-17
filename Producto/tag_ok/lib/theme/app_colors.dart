import 'package:flutter/material.dart';

/// Paleta corporativa de TAG OK ("Paleta morada"), en modo claro y oscuro.
///
/// Es la única fuente de colores de la app: ninguna pantalla debe declarar
/// sus propios `Color(0x...)`. Si hace falta un color nuevo, se agrega acá con
/// un nombre según su función (no según su tono), con su versión clara y
/// oscura.
///
/// Cada color depende de [oscuro], que solo cambia `ModoTema`
/// (theme/modo_tema.dart). Por eso son getters y no constantes: las pantallas
/// no pueden usarlos dentro de un `const`.
///
/// Todas las combinaciones de texto sobre [fondo], [superficie] y
/// [contenedorSuave] cumplen contraste AA en ambos modos.
abstract final class AppColors {
  /// true = modo oscuro. Lo cambia solo `ModoTema`; por defecto, modo claro.
  static bool oscuro = false;

  static Color _segun(int claro, int enOscuro) =>
      Color(oscuro ? enOscuro : claro);

  // --- Marca --------------------------------------------------------------

  /// Fondo de pantalla.
  static Color get fondo => _segun(0xFFF6F4FE, 0xFF13111C);

  /// Tarjetas, hojas y barra inferior.
  static Color get superficie => _segun(0xFFFFFFFF, 0xFF1E1B2B);

  /// Íconos, enlaces ("Ver todo"), pestaña activa y botones principales.
  /// En modo oscuro es lavanda.
  static Color get primario => _segun(0xFF5B4CDB, 0xFFAB9FF2);

  /// Color del texto e íconos que van sobre [primario].
  static Color get sobrePrimario => _segun(0xFFFFFFFF, 0xFF2A2350);

  /// Tarjeta de gastos: violeta en ambos modos.
  static Color get violeta => const Color(0xFF5B4CDB);

  /// Texto e íconos sobre [violeta].
  static Color get sobreVioleta => const Color(0xFFFFFFFF);

  /// Botón central del mapa (FAB).
  static Color get lavanda => const Color(0xFFAB9FF2);

  /// Ícono y texto sobre [lavanda].
  static Color get sobreLavanda => const Color(0xFF2A2350);

  /// Fondo de íconos, avatar, píldoras y campos.
  static Color get contenedorSuave => _segun(0xFFEEEAFE, 0xFF2A2540);

  /// Fondo de los botones circulares con flecha ">" de las tarjetas.
  static Color get fondoFlecha => _segun(0xFFF6F4FE, 0xFF2A2540);

  /// Barras del gráfico sin gasto y elementos inactivos.
  static Color get barraInactiva => _segun(0xFFDCD6FB, 0xFF3A3455);

  // --- Texto --------------------------------------------------------------

  /// Títulos y valores.
  static Color get texto => _segun(0xFF1E1B2E, 0xFFF4F2FF);

  /// Subtítulos, etiquetas e íconos secundarios.
  static Color get textoSecundario => _segun(0xFF6E6A85, 0xFF9C97B5);

  /// Elementos deshabilitados (flechas sin destino, íconos apagados).
  static Color get deshabilitado => _segun(0xFFA9A5BD, 0xFF5E5A75);

  // --- Bordes y sombras ---------------------------------------------------

  /// Bordes de tarjetas, divisores y campos de formulario.
  static Color get borde => _segun(0xFFE2DEF3, 0xFF2E2A40);

  /// Sombra suave de la barra inferior y tarjetas elevadas.
  static Color get sombra => _segun(0x1A2A2350, 0x66000000);

  // --- Estado -------------------------------------------------------------

  /// Al día / correcto (chip "Todo al día", confirmaciones).
  static Color get exito => _segun(0xFF1C7A4A, 0xFF5FD394);

  /// Fondo de los chips de [exito].
  static Color get exitoFondo => _segun(0xFFE3F6EC, 0xFF1E3A2C);

  /// Por vencer / advertencia.
  static Color get advertencia => _segun(0xFFF59E0B, 0xFFFBBF24);

  /// Fondo de los chips de [advertencia].
  static Color get advertenciaFondo => _segun(0xFFFEF3C7, 0xFF3D3015);

  /// Alerta intermedia (más urgente que [advertencia]).
  static Color get alerta => _segun(0xFFF97316, 0xFFFB923C);

  /// Vencido / error / acciones destructivas.
  static Color get error => _segun(0xFFE11D48, 0xFFFB7185);

  /// Fondo de los chips de [error].
  static Color get errorFondo => _segun(0xFFFFE4E6, 0xFF3F1D27);
}
