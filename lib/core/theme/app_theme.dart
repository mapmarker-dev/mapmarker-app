import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// 3단계 컴포넌트 테마. 1단계 기본 값과 2단계 의미 토큰으로 Material 위젯의 모양을 정한다.
abstract final class AppTheme {
  static ThemeData light() {
    // tonalSpot(기본)은 코랄을 갈색으로 바꾼다. fidelity는 씨앗 색을 그대로 강조 면에 쓴다.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.coral,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final appColors = AppColors.light(scheme);
    final base = ThemeData(colorScheme: scheme, fontFamily: AppFont.family);
    final text = base.textTheme;
    final textTheme = text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: AppFont.extraBold,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: AppFont.extraBold),
      titleMedium: text.titleMedium?.copyWith(fontWeight: AppFont.bold),
      titleSmall: text.titleSmall?.copyWith(fontWeight: AppFont.bold),
      labelLarge: text.labelLarge?.copyWith(fontWeight: AppFont.bold),
      labelMedium: text.labelMedium?.copyWith(fontWeight: AppFont.bold),
    );
    const stadium = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpace.xl,
      vertical: AppSpace.md,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: appColors.cardBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: stadium,
          padding: buttonPadding,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: stadium,
          padding: buttonPadding,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      ),
      chipTheme: const ChipThemeData(shape: stadium),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      extensions: [appColors],
    );
  }
}
