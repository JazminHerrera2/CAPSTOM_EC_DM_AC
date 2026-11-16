import 'package:flutter/material.dart';

/// Paleta corporativa de TAG OK ("Paleta morada", modo claro).
///
/// Es la única fuente de colores de la app: ninguna pantalla debe declarar
/// sus propios `Color(0x...)`. Si hace falta un color nuevo, se agrega acá con
/// un nombre según su función (no según su tono).
///
/// Todas las combinaciones de texto sobre [fondo], [superficie] y
/// [contenedorSuave] cumplen contraste AA.
abstract final class AppColors {
  // --- Marca --------------------------------------------------------------

  /// Fondo de pantalla.
  static const Color fondo = Color(0xFFF6F4FE);

  /// Tarjetas, hojas y barra inferior.
  static const Color superficie = Color(0xFFFFFFFF);

  /// Íconos, enlaces ("Ver todo"), pestaña activa y botones principales.
  static const Color primario = Color(0xFF5B4CDB);

  /// Color del texto e íconos que van sobre [primario].
  static const Color sobrePrimario = Color(0xFFFFFFFF);

  /// Botón central del mapa (FAB).
  static const Color lavanda = Color(0xFFAB9FF2);

  /// Ícono y texto sobre [lavanda].
  static const Color sobreLavanda = Color(0xFF2A2350);

  /// Fondo de íconos, avatar, píldoras y campos.
  static const Color contenedorSuave = Color(0xFFEEEAFE);

  /// Barras del gráfico sin gasto y elementos inactivos.
  static const Color barraInactiva = Color(0xFFDCD6FB);

  // --- Texto --------------------------------------------------------------

  /// Títulos y valores.
  static const Color texto = Color(0xFF1E1B2E);

  /// Subtítulos, etiquetas e íconos secundarios.
  static const Color textoSecundario = Color(0xFF6E6A85);

  /// Elementos deshabilitados (flechas sin destino, íconos apagados).
  static const Color deshabilitado = Color(0xFFA9A5BD);

  // --- Bordes y sombras ---------------------------------------------------

  /// Bordes de tarjetas y campos de formulario.
  static const Color borde = Color(0xFFE2DEF3);

  /// Sombra suave de la barra inferior y tarjetas elevadas.
  static const Color sombra = Color(0x1A2A2350);

  // --- Estado -------------------------------------------------------------

  /// Al día / correcto (chip "Todo al día", confirmaciones).
  static const Color exito = Color(0xFF1C7A4A);

  /// Fondo de los chips de [exito].
  static const Color exitoFondo = Color(0xFFE3F6EC);

  /// Por vencer / advertencia.
  static const Color advertencia = Color(0xFFF59E0B);

  /// Fondo de los chips de [advertencia].
  static const Color advertenciaFondo = Color(0xFFFEF3C7);

  /// Alerta intermedia (más urgente que [advertencia]).
  static const Color alerta = Color(0xFFF97316);

  /// Vencido / error / acciones destructivas.
  static const Color error = Color(0xFFE11D48);

  /// Fondo de los chips de [error].
  static const Color errorFondo = Color(0xFFFFE4E6);
}
