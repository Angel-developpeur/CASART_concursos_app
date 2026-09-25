import 'package:flutter/material.dart';

class AppTheme {
  // ==========================================
  // PALETA INSTITUCIONAL CASART (Bugambilia / Magenta / Vino)
  // ==========================================
  static const Color casart50 = Color(0xFFFCF3F9);
  static const Color casart100 = Color(0xFFFAE9F5);
  static const Color casart200 = Color(0xFFF7D3EB);
  static const Color casart300 = Color(0xFFF1B0DA);
  static const Color casart400 = Color(0xFFE87EC0);
  static const Color casart500 = Color(0xFFDD57A7);
  static const Color casart600 = Color(0xFFCA3888);
  static const Color casart700 = Color(0xFFAE286E);
  static const Color casart800 = Color(0xFF90245A); // Color Principal CASART
  static const Color casart900 = Color(0xFF79224E);
  static const Color casart950 = Color(0xFF4A0E2C);
  static const Color casart1000 = Color(0xFF3B0B23);
  static const Color casart2000 = Color(0xFF2B081A);

  // ==========================================
  // COLORES BASE PROPORCIONADOS
  // ==========================================
  static const Color ocre10 = Color(0xFF4A4A0E);
  static const Color verde10 = Color(0xFF0E4A2C);
  static const Color azul10 = Color(0xFF0E0E4A);

  // ==========================================
  // VARIANTES COMPLEMENTARIAS
  // ==========================================
  // 1. Variantes de Amarillo / Ocre / Dorado (Acentos, Premios, Distintivos)
  static const Color ocreAccent = Color(0xFFC89319);
  static const Color ocreAccentLight = Color(0xFFFDF8EA);
  static const Color ocreAccentBorder = Color(0xFFECCB7A);
  static const Color ocreText = Color(0xFF6E5608);

  // 2. Variantes de Verde (Precios de venta, Éxito, Validación)
  static const Color verdeSuccess = Color(0xFF1B7A4B);
  static const Color verdeLight = Color(0xFFEBF7F0);
  static const Color verdeBorder = Color(0xFFA7E0BF);

  // 3. Variantes de Azul (Red local, Terminales, Sincronización Web)
  static const Color azulAccent = Color(0xFF1D5CA9);
  static const Color azulLight = Color(0xFFEEF4FC);
  static const Color azulBorder = Color(0xFFB3D1F5);

  // ==========================================
  // SEMÁNTICOS Y NEUTROS
  // ==========================================
  static const Color folioRed = Color(0xFFD00000);
  static const Color surfaceLight = Color(0xFFFCF9FB);
  static const Color cardDark = Color(0xFF20111A);

  // Atajos semánticos principales
  static const Color primary = casart800; // #90245A
  static const Color primaryLight = casart600; // #CA3888
  static const Color secondary = ocreAccent; // #C89319

  // Colores para modales y diálogos
  static const Color dialogBodyBg = Color(0xFFF5F7FA); // Gris suave
  static const Color dialogHeaderBg = Colors.white;

  // Estilo reutilizable para botones de Cancelar (texto rojo sin borde)
  static final ButtonStyle cancelButtonStyle = TextButton.styleFrom(
    foregroundColor: const Color(0xFFD32F2F),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  // Estilo reutilizable para botones de Aceptar / Guardar (fondo verde, texto blanco)
  static final ButtonStyle acceptButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: verdeSuccess,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  // Aliases de retrocompatibilidad
  static const Color primaryCasart = casart800;
  static const Color primaryGreen = casart800;
  static const Color primaryGreenLight = casart600;
  static const Color goldAccent = ocreAccent;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: folioRed,
        surface: surfaceLight,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F2F5),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBodyBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEEDFE7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDFC9D7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDFC9D7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: casart950,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        primary: primaryLight,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: folioRed,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF160911),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF38182B)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4E213C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4E213C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryLight, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
