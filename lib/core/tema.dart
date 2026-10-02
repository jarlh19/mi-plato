import 'package:flutter/material.dart';

/// Tema único de la app. Material 3 con una semilla verde vegetal.
class Tema {
  static const _semilla = Color(0xFF5B8C3E);

  /// Colores de los veredictos. No salen del `ColorScheme` porque su
  /// significado es fijo: verde = a favor, ámbar = ojo, rojo = en contra.
  static const bueno = Color(0xFF2E7D32);
  static const aviso = Color(0xFFB26A00);
  static const malo = Color(0xFFC62828);

  static ThemeData claro() => _construir(Brightness.light);
  static ThemeData oscuro() => _construir(Brightness.dark);

  /// Versión legible de [bueno]/[aviso]/[malo] sobre el fondo actual: los
  /// tonos oscuros no contrastan en modo noche.
  static Color severidad(BuildContext context, Color base) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    if (!oscuro) return base;
    return Color.lerp(base, Colors.white, 0.45)!;
  }

  static ThemeData _construir(Brightness brillo) {
    final esquema = ColorScheme.fromSeed(
      seedColor: _semilla,
      brightness: brillo,
    );
    return ThemeData(
      colorScheme: esquema,
      useMaterial3: true,
      scaffoldBackgroundColor: esquema.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.surface,
        foregroundColor: esquema.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esquema.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: esquema.outlineVariant),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
