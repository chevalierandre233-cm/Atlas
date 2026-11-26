import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette Atlas : noir graphite, anthracite et violet électrique.
class AtlasColors {
  final Color bg, panel, fg, mute, line;

  const AtlasColors({
    required this.bg,
    required this.panel,
    required this.fg,
    required this.mute,
    required this.line,
  });

  static const dark = AtlasColors(
    bg: Color(0xFF101116),
    panel: Color(0xFF191A23),
    fg: Color(0xFFF5F5FA),
    mute: Color(0xFF92929F),
    line: Color(0x14FFFFFF),
  );

  static const light = AtlasColors(
    bg: Color(0xFFF5F5FA),
    panel: Colors.white,
    fg: Color(0xFF101116),
    mute: Color(0xFF5C5C6B),
    line: Color(0x1A101116),
  );

  static const violet = Color(0xFF8B5CF6);
  static const violetLight = Color(0xFFA78BFA);
  static const indigo = Color(0xFF4338CA);
  // Correction : cyan doit être une vraie Color, jamais null.
  static const cyan = Color(0xFF22D3EE);

  static const gradient = LinearGradient(
    colors: [violet, indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static AtlasColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AtlasTheme {
  static ThemeData build(Brightness brightness) {
    final c = brightness == Brightness.dark ? AtlasColors.dark : AtlasColors.light;
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AtlasColors.violet,
        brightness: brightness,
      ).copyWith(
        surface: c.panel,
        primary: AtlasColors.violet,
        secondary: AtlasColors.cyan,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: c.fg,
        displayColor: c.fg,
        fontFamily: GoogleFonts.figtree().fontFamily,
      ),
      dividerColor: c.line,
    );
  }

  static TextStyle display(double size, Color color,
          {FontWeight w = FontWeight.w600}) =>
      GoogleFonts.sora(fontSize: size, fontWeight: w, color: color);
}
