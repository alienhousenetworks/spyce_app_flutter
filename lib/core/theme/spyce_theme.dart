import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spyce_colors.dart';

abstract final class SpyceTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SpyceColors.dark950,
      colorScheme: const ColorScheme.dark(
        primary: SpyceColors.pink,
        secondary: SpyceColors.teal,
        tertiary: SpyceColors.gold,
        surface: SpyceColors.dark900,
        error: Color(0xFFFF4D6A),
        onPrimary: SpyceColors.white,
        onSecondary: SpyceColors.dark950,
        onSurface: SpyceColors.white,
      ),
    );

    final display = GoogleFonts.syneTextTheme(base.textTheme);
    final body = GoogleFonts.dmSansTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          color: SpyceColors.white,
          fontWeight: FontWeight.w800,
        ),
        displayMedium: display.displayMedium?.copyWith(
          color: SpyceColors.white,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: display.displaySmall?.copyWith(
          color: SpyceColors.white,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: display.headlineLarge?.copyWith(
          color: SpyceColors.white,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: display.headlineMedium?.copyWith(
          color: SpyceColors.white,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: display.headlineSmall?.copyWith(
          color: SpyceColors.white,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: display.titleLarge?.copyWith(
          color: SpyceColors.white,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: body.titleMedium?.copyWith(color: SpyceColors.white),
        titleSmall: body.titleSmall?.copyWith(color: SpyceColors.dark100),
        bodyLarge: body.bodyLarge?.copyWith(color: SpyceColors.white),
        bodyMedium: body.bodyMedium?.copyWith(color: SpyceColors.white),
        bodySmall: body.bodySmall?.copyWith(color: SpyceColors.dark100),
        labelLarge: body.labelLarge?.copyWith(
          color: SpyceColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: SpyceColors.dark950,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.syne(
          color: SpyceColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: SpyceColors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SpyceColors.dark900,
        selectedItemColor: SpyceColors.pink,
        unselectedItemColor: SpyceColors.dark200,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SpyceColors.dark800,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SpyceColors.dark500),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SpyceColors.dark500),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SpyceColors.pink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF4D6A)),
        ),
        hintStyle: const TextStyle(color: SpyceColors.dark200),
        labelStyle: const TextStyle(color: SpyceColors.dark100),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SpyceColors.pink,
          foregroundColor: SpyceColors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpyceColors.white,
          side: const BorderSide(color: SpyceColors.dark400),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SpyceColors.dark700,
        selectedColor: SpyceColors.pinkDim,
        labelStyle: const TextStyle(color: SpyceColors.white),
        side: const BorderSide(color: SpyceColors.dark400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: SpyceColors.dark600,
        thickness: 0.5,
      ),
      cardTheme: CardThemeData(
        color: SpyceColors.dark800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SpyceColors.dark600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SpyceColors.dark600,
        contentTextStyle: const TextStyle(color: SpyceColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SpyceColors.dark800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
