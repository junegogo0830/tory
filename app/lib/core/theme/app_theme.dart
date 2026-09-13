import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: brightness,
        primary: AppColors.ink,
        secondary: AppColors.accent,
        surface: AppColors.surface,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.largeTitle,
        titleLarge: AppTypography.title,
        titleMedium: AppTypography.headline,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.subhead,
        bodySmall: AppTypography.footnote,
        labelSmall: AppTypography.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        titleTextStyle: AppTypography.title,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldBg,
        hintStyle: AppTypography.body.copyWith(color: AppColors.inkTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.surface,
          textStyle: AppTypography.headline.copyWith(color: AppColors.surface),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          // elevation 0(완전 평면)이라 버튼이 눌러볼 만한 입체감 없이 밋밋해
          // 보인다는 피드백으로, 은은한 톤온톤 그림자를 살짝 얹었다.
          elevation: 3,
          shadowColor: AppColors.ink.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.inkTertiary,
        selectedLabelStyle: AppTypography.caption,
        unselectedLabelStyle: AppTypography.caption,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
