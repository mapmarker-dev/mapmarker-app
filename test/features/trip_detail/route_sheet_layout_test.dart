import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/features/trip_detail/route_sheet_layout.dart';

void main() {
  group('routeSheetLayoutOf', () {
    test('puts the list beside the map on wide landscape screens', () {
      // 태블릿 가로, 휴대폰 가로.
      expect(routeSheetLayoutOf(const Size(1280, 800)), RouteSheetLayout.side);
      expect(routeSheetLayoutOf(const Size(800, 360)), RouteSheetLayout.side);
    });

    test('keeps the bottom sheet on portrait and narrow screens', () {
      // 휴대폰 세로, 태블릿 세로, 화면 분할로 좁아진 가로.
      expect(routeSheetLayoutOf(const Size(390, 844)), RouteSheetLayout.bottom);
      expect(
        routeSheetLayoutOf(const Size(800, 1280)),
        RouteSheetLayout.bottom,
      );
      expect(routeSheetLayoutOf(const Size(560, 400)), RouteSheetLayout.bottom);
      // 정사각형은 가로가 아니다.
      expect(routeSheetLayoutOf(const Size(900, 900)), RouteSheetLayout.bottom);
    });
  });

  group('sidePanelWidth', () {
    test('takes 35% of the screen', () {
      expect(sidePanelWidth(1000), 350);
    });

    test('stays wide enough for a stop row and no wider than useful', () {
      expect(sidePanelWidth(800), 320);
      expect(sidePanelWidth(1280), 420);
    });
  });
}
