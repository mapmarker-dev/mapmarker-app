import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/theme/app_tokens.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/route_scene.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_day_panel.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_day_sheet.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_title_bar.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 2박 3일 여행. 1일차: a > b > 숙소, 2일차: c > d > 숙소(연박, 같은 자리).
final _stops = [
  testStop('a', tripId: 'jeju', kind: StopKind.tour),
  testStop('b', tripId: 'jeju', order: 1, kind: StopKind.food),
  testLodging('hotel', tripId: 'jeju', order: 2),
  testStop('c', tripId: 'jeju', day: 2).copyWith(memo: '주차 2시간 무료'),
  testStop('d', tripId: 'jeju', day: 2, order: 1),
  testLodging('hotel2', tripId: 'jeju', day: 2, order: 2),
];

/// 태블릿 가로 화면. 패널 폭은 1280의 35%(448)가 최대값 420으로 줄어든다.
const _tablet = Size(1280, 800);
const _panelWidth = 420.0;

void _useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
}

Future<void> _pumpJeju(WidgetTester tester) async {
  _useScreen(tester, _tablet);
  await pumpTestApp(
    tester,
    repository: testRepository([
      testTrip(id: 'jeju', region: '제주', nights: 2),
    ], _stops),
    location: Routes.trip('jeju'),
  );
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (w) => w is ChoiceChip || w is FilterChip,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _closePanel(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(RouteDayPanel),
      matching: find.byTooltip('닫기'),
    ),
  );
  await tester.pumpAndSettle();
}

/// 패널이 화면 안에 열려 있는지.
bool _panelOpen(WidgetTester tester) {
  final panel = find.byType(RouteDayPanel);
  if (panel.evaluate().isEmpty) return false;
  return tester.getRect(panel).left < _tablet.width;
}

ItineraryStopTile _tile(WidgetTester tester, String name) =>
    tester.widget<ItineraryStopTile>(
      find.byWidgetPredicate(
        (w) => w is ItineraryStopTile && w.stop.name == name,
        skipOffstage: false,
      ),
    );

MapMarker? _draft(WidgetTester tester) =>
    mapScene(tester).markers.where((m) => m.id == draftMarkerId).firstOrNull;

void main() {
  testWidgets('shows the day beside the map on a wide landscape screen', (
    tester,
  ) async {
    await _pumpJeju(tester);

    // 전체 보기에는 목록이 없다.
    expect(find.byType(RouteDayPanel), findsNothing);
    expect(mapScene(tester).padding.right, 0);

    await _tapChip(tester, '2일차');

    expect(find.byType(RouteDaySheet), findsNothing);
    expect(_panelOpen(tester), isTrue);
    final panel = tester.getRect(find.byType(RouteDayPanel));
    expect(panel.width, _panelWidth);
    expect(panel.right, _tablet.width);
    // 세로 전체를 쓴다.
    expect((panel.top, panel.bottom), (0, _tablet.height));
    expect(find.text('장소 3곳'), findsOneWidget);
    // 지도 내용과 위에 뜬 것은 패널 왼쪽에 둔다. 로고는 왼쪽 아래라서 올리지 않는다.
    final scene = mapScene(tester);
    expect(scene.padding.right, _panelWidth);
    expect(scene.logoLift, 0);
    expect(
      tester.getTopRight(find.byType(RouteTitleBar)).dx,
      lessThanOrEqualTo(panel.left),
    );
    expect(
      tester.getBottomRight(find.byTooltip('동선에 맞추기')).dx,
      lessThanOrEqualTo(panel.left - AppSpace.lg),
    );
  });

  testWidgets('closes and opens again by picking a day', (tester) async {
    await _pumpJeju(tester);
    await _tapChip(tester, '2일차');

    await _closePanel(tester);

    expect(_panelOpen(tester), isFalse);
    expect(mapScene(tester).padding.right, 0);
    expect(
      tester.getTopRight(find.byType(RouteTitleBar)).dx,
      greaterThan(_tablet.width - _panelWidth),
      reason: '제목 카드가 화면 폭을 다시 쓴다',
    );

    // 지금 일차를 다시 골라도 열린다.
    await _tapChip(tester, '2일차');

    expect(_panelOpen(tester), isTrue);
    expect(mapScene(tester).padding.right, _panelWidth);
  });

  testWidgets('opens on a marker tap and shows its row', (tester) async {
    await _pumpJeju(tester);
    await _tapChip(tester, '2일차');
    await _closePanel(tester);
    final camera = mapScene(tester).camera.key;

    await tapMarker(tester, 'c');

    expect(_panelOpen(tester), isTrue);
    expect(_tile(tester, 'c').highlighted, isTrue);
    expect(_tile(tester, 'c').expanded, isTrue);
    expect(find.text('주차 2시간 무료'), findsOneWidget);
    // 일차 보기에서는 카메라를 움직이지 않는다.
    expect(mapScene(tester).camera.key, camera);
  });

  testWidgets('drops a pin on the first map tap', (tester) async {
    await _pumpJeju(tester);
    await _tapChip(tester, '2일차');

    await tapMap(tester, const LatLng(33.4, 126.6));

    // 패널은 지도를 덮지 않아서 접을 것이 없다.
    expect(_draft(tester), isNotNull);
    expect(_panelOpen(tester), isTrue);
    expect(
      tester.getBottomRight(find.text('여기에 장소 추가')).dx,
      lessThan(_tablet.width - _panelWidth),
    );
  });

  testWidgets('keeps the picked row when the screen turns', (tester) async {
    await _pumpJeju(tester);
    await _tapChip(tester, '2일차');
    await tester.tap(find.text('c'));
    await tester.pumpAndSettle();

    expect(_tile(tester, 'c').expanded, isTrue);

    // 세로로 돌린다: 아래 시트가 가운데 높이로 올라오고, 펼친 줄과 고른 줄은 그대로다.
    _useScreen(tester, const Size(800, 1280));
    await tester.pumpAndSettle();

    expect(find.byType(RouteDayPanel), findsNothing);
    expect(find.byType(RouteDaySheet), findsOneWidget);
    expect(_tile(tester, 'c').expanded, isTrue);
    expect(_tile(tester, 'c').highlighted, isTrue);
    expect(mapScene(tester).logoLift, greaterThan(0));
    expect(mapScene(tester).padding.right, 0);

    // 다시 가로로 돌린다.
    _useScreen(tester, _tablet);
    await tester.pumpAndSettle();

    expect(_panelOpen(tester), isTrue);
    expect(_tile(tester, 'c').highlighted, isTrue);
    expect(mapScene(tester).logoLift, 0);
  });

  testWidgets('keeps a closed panel closed when the screen turns back', (
    tester,
  ) async {
    await _pumpJeju(tester);
    await _tapChip(tester, '2일차');
    await _closePanel(tester);

    _useScreen(tester, const Size(800, 1280));
    await tester.pumpAndSettle();

    // 패널을 닫은 채 세로로 돌리면 시트는 접힌 채다.
    expect(mapScene(tester).logoLift, 0);

    _useScreen(tester, _tablet);
    await tester.pumpAndSettle();

    expect(_panelOpen(tester), isFalse);
  });
}
