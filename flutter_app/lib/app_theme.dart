import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color bg = Color(0xFF000000);
  static const Color bg2 = Color(0xFF16161D);
  static const Color bg3 = Color(0xFF1E1E28);
  static const Color border = Color(0xFF2A2A38);
  static const Color accent = Color(0xFF7C6EF7); // General Accent
  static const Color accent2 = Color(0xFF60A5FA); // CapCut Blue
  static const Color videoAccent = Color(0xFF60A5FA); // CapCut Blue for Video
  static const Color audioAccent = Color(0xFF4ADE80); // CapCut Green for Audio
  static const Color textAccent = Color(0xFFFACC15);  // CapCut Yellow for Text/Effect
  static const Color overlayAccent = Color(0xFFF472B6); // CapCut Pink for Overlay
  static const Color aiAccent = Color(0xFF2DD4BF);      // Cyan for AI Features
  static const Color captionAccent = Color(0xFFFB923C); // Orange for Auto Captions
  static const Color accent3 = Color(0xFFFACC15);      // Gold for Premium/Pro
  static const Color adjustmentAccent = Color(0xFFA855F7); // Purple for Adjustment Layers
  static const Color beatMarker = Color(0xFFFF4D4D); // Bright Red for Beats
  static const Color success = Color(0xFF22C55E);    // Green for Export Success
  static const Color warning = Color(0xFFF59E0B);    // Amber for Warnings
  static const Color accent4 = Color(0xFFF76E6E);    // Red for Errors
  static const Color textPrimary = Color(0xFFE8E6FF);
  static const Color textSecondary = Color(0xFF9D9BB8);
  static const Color textTertiary = Color(0xFF5C5A78);
  static const Color green = Color(0xFF4ADE80);
  static const Color blue = Color(0xFF60A5FA);
  static const Color orange = Color(0xFFFB923C);
  static const Color pink = Color(0xFFF472B6);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent2,
        surface: bg2,
        error: accent4,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: bg2,
        foregroundColor: textPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        displayMedium:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: TextStyle(
            color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        labelSmall: TextStyle(color: textTertiary, fontSize: 11),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textTertiary),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      dividerColor: border,
      iconTheme: const IconThemeData(color: textSecondary),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter'),
        contentTextStyle: const TextStyle(
            color: textSecondary, fontSize: 14, fontFamily: 'Inter'),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: bg3,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : textTertiary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? accent.withValues(alpha: 0.4)
                : border),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: Color(0x337C6EF7),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: textTertiary,
        indicatorColor: accent,
      ),
    );
  }
}
