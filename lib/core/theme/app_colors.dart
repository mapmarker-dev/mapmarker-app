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
  });

  factory AppColors.light(ColorScheme scheme) => AppColors(
    phaseBefore: const ChipColors(AppPalette.mint100, AppPalette.mint800),
    phaseDuring: ChipColors(scheme.primaryContainer, scheme.onPrimaryContainer),
    phaseAfter: const ChipColors(AppPalette.sand100, AppPalette.sand800),
    cardBorder: scheme.outlineVariant,
    cardHighlight: scheme.primaryContainer,
  );

  /// 상태 칩: 여행 전(민트), 여행 중(코랄), 여행 후(모래).
  final ChipColors phaseBefore;
  final ChipColors phaseDuring;
  final ChipColors phaseAfter;

  /// 여행 카드 테두리. 여행 중인 카드는 [cardHighlight]로 강조한다.
  final Color cardBorder;
  final Color cardHighlight;

  @override
  AppColors copyWith({
    ChipColors? phaseBefore,
    ChipColors? phaseDuring,
    ChipColors? phaseAfter,
    Color? cardBorder,
    Color? cardHighlight,
  }) => AppColors(
    phaseBefore: phaseBefore ?? this.phaseBefore,
    phaseDuring: phaseDuring ?? this.phaseDuring,
    phaseAfter: phaseAfter ?? this.phaseAfter,
    cardBorder: cardBorder ?? this.cardBorder,
    cardHighlight: cardHighlight ?? this.cardHighlight,
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
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
