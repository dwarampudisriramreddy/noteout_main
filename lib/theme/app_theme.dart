import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;

  const lightScheme = ColorScheme.light(
    primary: Colors.black,
    secondary: Colors.black,
    surface: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.black,
    surfaceContainerLow: Color(0xFFF7F7F7),
    surfaceContainerHighest: Color(0xFFECECEC),
    outlineVariant: Color(0xFFE0E0E0),
  );

  const darkScheme = ColorScheme.dark(
    primary: Colors.white,
    secondary: Colors.white,
    surface: Color(0xFF0E0E12),
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onSurface: Color(0xFFE8E8EC),
    onSurfaceVariant: Color(0xFFA6A6AD),
    surfaceContainerLow: Color(0xFF16161C),
    surfaceContainerHighest: Color(0xFF1E1E26),
    outlineVariant: Color(0xFF2A2A32),
  );

  final scheme = isDark ? darkScheme : lightScheme;

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.5,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? const Color(0xFF2A2A32) : Colors.black,
      contentTextStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: isDark ? scheme.onSurface : Colors.white,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.onSurface,
      selectionColor: scheme.onSurface.withValues(alpha: 0.2),
      selectionHandleColor: scheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF16161C) : const Color(0xFFF7F7F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

extension NoteoutColors on BuildContext {
  ColorScheme get nScheme => Theme.of(this).colorScheme;

  /// primary text color (near-black in light, near-white in dark)
  Color get nText => nScheme.onSurface;

  /// muted text color (~55% opacity)
  Color get nMuted => nScheme.onSurface.withValues(alpha: 0.55);

  /// faint text color (~38% opacity)
  Color get nFaint => nScheme.onSurface.withValues(alpha: 0.38);

  /// very faint text color (~12% opacity, for hints)
  Color get nSubtle => nScheme.onSurface.withValues(alpha: 0.12);

  /// subtle panel/card fill
  Color get nPanel2 => nScheme.surfaceContainerLow;

  /// chip / tag fill
  Color get nPanel => nScheme.surfaceContainerHighest;

  /// hairline divider color
  Color get nLine => nScheme.outlineVariant;

  /// background surface
  Color get nSurface => nScheme.surface;

  /// is app running in dark mode
  bool get nDark => Theme.of(this).brightness == Brightness.dark;
}