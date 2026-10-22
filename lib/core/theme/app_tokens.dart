import 'package:flutter/widgets.dart';

/// 1단계 기본 값: 색 원값. 뜻은 붙이지 않는다.
///
/// 화면은 이 값을 바로 쓰지 않는다. `ColorScheme`이나 `AppColors`(2단계)로 읽는다.
abstract final class AppPalette {
  /// 주 색. 씨앗 색으로 쓰면 `fidelity` 방식에서 그대로 강조 면(`primaryContainer`)이 된다.
  static const coral = Color(0xFFFF6F61);

  static const mint100 = Color(0xFFDDF3EC);
  static const mint800 = Color(0xFF1F6B55);

  static const sand100 = Color(0xFFEFE9E6);
  static const sand800 = Color(0xFF5C504C);

  // 동선 일차 색. 지도 위에서 잘 보이는 중간 밝기(400)에, 번호는 같은 계열의 진한 색(900)이다.
  // 파랑(현재 위치)과 초록(공원)은 지도에서 다른 뜻이라 쓰지 않는다.
  static const coral900 = Color(0xFF4A1510);
  static const violet400 = Color(0xFF9B7BFF);
  static const violet900 = Color(0xFF24124F);
  static const amber400 = Color(0xFFF5B02E);
  static const amber900 = Color(0xFF4A2E00);
  static const teal400 = Color(0xFF2BB3A3);
  static const teal900 = Color(0xFF003D36);
  static const magenta400 = Color(0xFFE55BB0);
  static const magenta900 = Color(0xFF3D0A2C);

  /// 숙소 마커. 숙소는 이틀에 걸쳐 쓰여서 일차 색과 겹치지 않는 진한 색을 쓴다.
  static const ink700 = Color(0xFF3A3550);
}

/// 1단계 기본 값: 간격. 4의 배수로 둔다.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// 1단계 기본 값: 모서리.
abstract final class AppRadius {
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(12));
  static const lg = BorderRadius.all(Radius.circular(16));

  /// 여행 카드.
  static const card = BorderRadius.all(Radius.circular(20));

  /// 대화상자.
  static const dialog = BorderRadius.all(Radius.circular(28));
}

/// 1단계 기본 값: 글꼴. `pubspec.yaml`에 넣은 굵기만 쓴다.
abstract final class AppFont {
  static const family = 'NanumSquareRound';
  static const regular = FontWeight.w400;
  static const bold = FontWeight.w700;
  static const extraBold = FontWeight.w800;
}
