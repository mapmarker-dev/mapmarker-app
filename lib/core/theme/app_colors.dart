import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 바탕색과 그 위 글자색 한 쌍.
@immutable
class ChipColors {
  const ChipColors(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static ChipColors lerp(ChipColors a, ChipColors b, double t) => ChipColors(
    Color.lerp(a.background, b.background, t)!,
    Color.lerp(a.foreground, b.foreground, t)!,
  );
}

/// 2단계 의미 토큰: `ColorScheme`에 없는 앱만의 색. 화면에서는 `context.appColors`로 읽는다.
///
/// 지금은 라이트 모드만 있다. 다크 모드는 `AppColors.dark`를 더해 같은 이름에 다른 값을 준다.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.phaseBefore,
    required this.phaseDuring,
    required this.phaseAfter,
    required this.cardBorder,
    required this.cardHighlight,
    required this.routeDays,
    required this.routeLodging,
    required this.routeHalo,
    required this.routeViaOpacity,
  });

  factory AppColors.light(ColorScheme scheme) => AppColors(
    phaseBefore: const ChipColors(AppPalette.mint100, AppPalette.mint800),
    phaseDuring: ChipColors(scheme.primaryContainer, scheme.onPrimaryContainer),
    phaseAfter: const ChipColors(AppPalette.sand100, AppPalette.sand800),
    cardBorder: scheme.outlineVariant,
    cardHighlight: scheme.primaryContainer,
    routeDays: const [
      ChipColors(AppPalette.coral, AppPalette.coral900),
      ChipColors(AppPalette.violet400, AppPalette.violet900),
      ChipColors(AppPalette.amber400, AppPalette.amber900),
      ChipColors(AppPalette.teal400, AppPalette.teal900),
      ChipColors(AppPalette.magenta400, AppPalette.magenta900),
    ],
    routeLodging: ChipColors(AppPalette.ink700, scheme.surfaceContainerLowest),
    routeHalo: scheme.surfaceContainerLowest,
    routeViaOpacity: 0.5,
  );

  /// 상태 칩: 여행 전(민트), 여행 중(코랄), 여행 후(모래).
  final ChipColors phaseBefore;
  final ChipColors phaseDuring;
  final ChipColors phaseAfter;

  /// 여행 카드 테두리. 여행 중인 카드는 [cardHighlight]로 강조한다.
  final Color cardBorder;
  final Color cardHighlight;

  /// 동선 일차 색. 바탕은 마커와 선, 글자는 마커 번호다. [routeDay]로 읽는다.
  ///
  /// 일차는 색으로, 이동 수단은 선 모양과 아이콘으로 구분한다.
  final List<ChipColors> routeDays;

  /// 숙소 마커. 바탕은 마커, 글자는 침대 아이콘이다.
  final ChipColors routeLodging;

  /// 마커 테두리, 선 테두리, 마커 배지 바탕. 지도 위에서 동선이 묻히지 않게 한다.
  final Color routeHalo;

  /// "숙소를 거침" 선(숙소를 끈 보기에서 낮에 들른 숙소 앞뒤를 바로 잇는 선)의 불투명도. [routeVia]로 읽는다.
  final double routeViaOpacity;

  /// [day]일차의 색. 일차가 색 수보다 많으면 처음 색부터 다시 쓴다.
  ChipColors routeDay(int day) => routeDays[(day - 1) % routeDays.length];

  /// [day]일차로 가는 "숙소를 거침" 선의 색. 일차 색을 흐리게 해서 실제 구간의 선과 구분한다.
  Color routeVia(int day) =>
      routeDay(day).background.withValues(alpha: routeViaOpacity);

  @override
  AppColors copyWith({
    ChipColors? phaseBefore,
    ChipColors? phaseDuring,
    ChipColors? phaseAfter,
    Color? cardBorder,
    Color? cardHighlight,
    List<ChipColors>? routeDays,
    ChipColors? routeLodging,
    Color? routeHalo,
    double? routeViaOpacity,
  }) => AppColors(
    phaseBefore: phaseBefore ?? this.phaseBefore,
    phaseDuring: phaseDuring ?? this.phaseDuring,
    phaseAfter: phaseAfter ?? this.phaseAfter,
    cardBorder: cardBorder ?? this.cardBorder,
    cardHighlight: cardHighlight ?? this.cardHighlight,
    routeDays: routeDays ?? this.routeDays,
    routeLodging: routeLodging ?? this.routeLodging,
    routeHalo: routeHalo ?? this.routeHalo,
    routeViaOpacity: routeViaOpacity ?? this.routeViaOpacity,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      phaseBefore: ChipColors.lerp(phaseBefore, other.phaseBefore, t),
      phaseDuring: ChipColors.lerp(phaseDuring, other.phaseDuring, t),
      phaseAfter: ChipColors.lerp(phaseAfter, other.phaseAfter, t),
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardHighlight: Color.lerp(cardHighlight, other.cardHighlight, t)!,
      routeDays: [
        for (final (i, day) in routeDays.indexed)
          ChipColors.lerp(day, other.routeDays[i], t),
      ],
      routeLodging: ChipColors.lerp(routeLodging, other.routeLodging, t),
      routeHalo: Color.lerp(routeHalo, other.routeHalo, t)!,
      routeViaOpacity: lerpDouble(routeViaOpacity, other.routeViaOpacity, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
