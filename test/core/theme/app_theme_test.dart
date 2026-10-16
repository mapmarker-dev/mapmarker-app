import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/theme/app_colors.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/core/theme/app_tokens.dart';

/// WCAG 대비. 글자는 4.5:1 이상이어야 읽기 쉽다.
double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  final theme = AppTheme.light();
  final scheme = theme.colorScheme;
  final appColors = theme.extension<AppColors>()!;

  test('keeps coral as it is for highlighted surfaces', () {
    expect(scheme.primaryContainer, AppPalette.coral);
  });

  test('uses the bundled rounded font', () {
    expect(theme.textTheme.bodyMedium?.fontFamily, AppFont.family);
    expect(theme.textTheme.titleMedium?.fontWeight, AppFont.bold);
  });

  test('keeps text readable on every background', () {
    final pairs = {
      'primary': (scheme.primary, scheme.onPrimary),
      'primaryContainer': (scheme.primaryContainer, scheme.onPrimaryContainer),
      'surface': (scheme.surface, scheme.onSurface),
      'surface secondary text': (scheme.surface, scheme.onSurfaceVariant),
      'card secondary text': (
        scheme.surfaceContainerLowest,
        scheme.onSurfaceVariant,
      ),
      'phase before': (
        appColors.phaseBefore.background,
        appColors.phaseBefore.foreground,
      ),
      'phase during': (
        appColors.phaseDuring.background,
        appColors.phaseDuring.foreground,
      ),
      'phase after': (
        appColors.phaseAfter.background,
        appColors.phaseAfter.foreground,
      ),
      for (final (i, day) in appColors.routeDays.indexed)
        'route day ${i + 1} number': (day.background, day.foreground),
      for (final (i, day) in appColors.routeDays.indexed)
        'route day ${i + 1} badge': (appColors.routeHalo, day.foreground),
      'route lodging icon': (
        appColors.routeLodging.background,
        appColors.routeLodging.foreground,
      ),
    };

    for (final MapEntry(key: name, value: (background, foreground))
        in pairs.entries) {
      expect(
        _contrast(background, foreground),
        greaterThanOrEqualTo(4.5),
        reason: name,
      );
    }
  });

  test('starts the route with coral and cycles the day colors', () {
    final days = appColors.routeDays;

    expect(appColors.routeDay(1).background, AppPalette.coral);
    expect(appColors.routeDay(days.length + 1), same(days.first));
    expect(appColors.routeDay(days.length), same(days.last));
    expect({for (final day in days) day.background}, hasLength(days.length));
  });

  test('blends app colors for theme animations', () {
    final other = appColors.copyWith(cardBorder: Colors.black);

    expect(appColors.lerp(other, 0).cardBorder, appColors.cardBorder);
    expect(appColors.lerp(other, 1).cardBorder, Colors.black);
  });
}
