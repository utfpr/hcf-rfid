import 'package:flutter/material.dart';

/// Paleta central do app. Altere aqui para mudar o design de todas as telas.
class AppColors {
  AppColors._();

  // Marca / primária
  static const Color primary = Color(0xFF007A33);
  static const Color primaryDark = Color(0xFF00592B);
  static const Color primaryLight = Color(0xFF1E9E52);
  static const Color primaryMedium = Color(0xFFC8E6D5);
  static const Color primarySoft = Color(0xFFE3F2E9);
  static const Color primarySofter = Color(0xFFEAF5EE);

  /// Neutro escuro usado como contraste (itens não lidos/inativos).
  static const Color secondary = Color(0xFF1A1A2E);

  // Estado
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFD32F2F);

  // Superfícies
  static const Color background = Color(0xFFF0F2F5);
  static const Color surface = Colors.white;
  static const Color inputFill = Color(0xFFF5F5F5);

  // Texto
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textHeading = Color(0xFF424242);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color textMutedAlt = Color(0xFF616161);

  // Bordas
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderInactive = Color(0xFFBDBDBD);

  // Aviso (banner padrão)
  static const Color warningBackground = Color(0xFFFFF3CD);
  static const Color warningBorder = Color(0xFFFFCC00);
  static const Color warningText = Color(0xFF856404);

  // Aviso (variante usada no perfil)
  static const Color warningBackgroundAlt = Color(0xFFFFF8E1);
  static const Color warningBorderAlt = Color(0xFFFFD54F);
  static const Color warningIconAlt = Color(0xFFF9A825);
  static const Color warningTextAlt = Color(0xFF5D4037);

  static const Color shadow = Color(0x26000000);
}
