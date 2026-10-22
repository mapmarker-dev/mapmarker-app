import 'dart:ui';

/// 일차 동선 목록을 어디에 둘지.
enum RouteSheetLayout {
  /// 지도 아래에서 끌어 올리는 시트(접힘·40%·70%).
  bottom,

  /// 지도 오른쪽에 세로 전체로 붙는 패널(열기·닫기).
  side,
}

/// 오른쪽 패널을 쓰는 가장 좁은 화면 폭(논리 px).
const sidePanelMinScreenWidth = 600.0;

/// 가로이고 폭이 [sidePanelMinScreenWidth] 이상이면 오른쪽 패널, 아니면 아래 시트.
///
/// 기기 종류(태블릿·휴대폰)가 아니라 화면 크기로 정한다. 화면 분할, 폴더블, 휴대폰 가로도 같은 규칙을 따른다.
/// 가로 화면은 세로가 짧아서 아래 시트를 올리면 지도와 목록이 모두 납작해진다.
RouteSheetLayout routeSheetLayoutOf(Size screen) =>
    screen.width > screen.height && screen.width >= sidePanelMinScreenWidth
    ? RouteSheetLayout.side
    : RouteSheetLayout.bottom;

/// 오른쪽 패널 폭. 화면 폭의 35%를 [min]~[max] 사이로 맞춘다.
///
/// 장소 줄(마커 그림, 이름, 손잡이, 외부 지도 링크)이 잘리지 않는 최소와,
/// 넓혀도 더 보이는 것이 없는 최대로 막는다. 남는 폭은 지도에 준다.
double sidePanelWidth(
  double screenWidth, {
  double min = 320,
  double max = 420,
}) => (screenWidth * 0.35).clamp(min, max);
