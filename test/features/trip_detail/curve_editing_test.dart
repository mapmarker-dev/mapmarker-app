import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 1박 2일 여행. 1일차: a > b > 숙소, 2일차: c.
final _stops = [
  testStop('a', tripId: 'jeju', kind: StopKind.tour),
  testStop('b', tripId: 'jeju', order: 1),
  testLodging('hotel', tripId: 'jeju', order: 2),
  testStop('c', tripId: 'jeju', day: 2),
];

/// 태블릿 가로 화면. 일차 동선 목록이 지도 오른쪽 패널로 뜬다.
Future<ProviderContainer> _pumpJeju(
  WidgetTester tester, {
  Size screen = const Size(1280, 800),
}) async {
  tester.view.physicalSize = screen * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  return pumpTestApp(
    tester,
    repository: testRepository([
      testTrip(id: 'jeju', region: '제주', nights: 1),
    ], _stops),
    location: Routes.trip('jeju'),
  );
}

Segment _segment(ProviderContainer container, String from, String to) =>
    container
        .read(tripRouteProvider('jeju'))
        .value!
        .segments
        .singleWhere((s) => s.fromStopId == from && s.toStopId == to);

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ChoiceChip),
    ),
  );
  await tester.pumpAndSettle();
}

/// [index]번째 구간 줄을 목록에서 누른다(위에서부터, 0은 a → b).
Future<void> _tapSegmentRow(WidgetTester tester, int index) async {
  await tester.tap(find.byType(ItinerarySegmentTile).at(index));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the handle on a segment picked in the list', (
    tester,
  ) async {
    final container = await _pumpJeju(tester);
    await _tapChip(tester, '1일차');
    expect(mapScene(tester).curveHandle, isNull);

    await _tapSegmentRow(tester, 0);

    final ab = _segment(container, 'a', 'b');
    final handle = mapScene(tester).curveHandle!;
    expect(handle.id, ab.id);
    expect(handle.curvature, 0);
    // 핸들 안에 화살표가 있어서 그 구간의 화살표는 따로 그리지 않는다.
    expect(mapScene(tester).arrows.map((a) => a.id), isNot(contains(ab.id)));
  });

  testWidgets('moves the handle to the next picked segment', (tester) async {
    final container = await _pumpJeju(tester);
    await _tapChip(tester, '1일차');
    await _tapSegmentRow(tester, 0);

    await _tapSegmentRow(tester, 1);

    expect(
      mapScene(tester).curveHandle!.id,
      _segment(container, 'b', 'hotel').id,
    );
  });

  testWidgets('has no handle when the segment is picked on the map', (
    tester,
  ) async {
    final container = await _pumpJeju(tester);
    await _tapChip(tester, '1일차');

    await tapLine(tester, _segment(container, 'a', 'b').id);

    expect(
      tester
          .widget<ItinerarySegmentTile>(find.byType(ItinerarySegmentTile).first)
          .highlighted,
      isTrue,
    );
    expect(mapScene(tester).curveHandle, isNull);
  });

  testWidgets('drops the handle when a stop row or another day is picked', (
    tester,
  ) async {
    await _pumpJeju(tester);
    await _tapChip(tester, '1일차');
    await _tapSegmentRow(tester, 0);

    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    expect(mapScene(tester).curveHandle, isNull);

    await _tapSegmentRow(tester, 0);
    await _tapChip(tester, '2일차');
    expect(mapScene(tester).curveHandle, isNull);
  });

  testWidgets('saves the curvature dragged on the map', (tester) async {
    final container = await _pumpJeju(tester);
    await _tapChip(tester, '1일차');
    await _tapSegmentRow(tester, 0);
    final id = _segment(container, 'a', 'b').id;

    await dragCurveHandle(tester, 0.35);

    expect(_segment(container, 'a', 'b').curvature, 0.35);
    // 선이 곡선으로 바뀌고, 핸들은 새 곡률로 그대로 있다.
    expect(
      mapScene(tester).lines.singleWhere((l) => l.id == id).points.length,
      greaterThan(2),
    );
    expect(mapScene(tester).curveHandle!.curvature, 0.35);
  });

  testWidgets('keeps the transport when bending the line', (tester) async {
    final container = await _pumpJeju(tester);
    await _tapChip(tester, '1일차');
    await _tapSegmentRow(tester, 0);
    // 이동 수단을 먼저 적는다.
    await tester.tap(find.byTooltip('이동 수단 고치기'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(ActionChip, '도보'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, '저장'),
      ),
    );
    await tester.pumpAndSettle();

    await dragCurveHandle(tester, -0.5);

    final ab = _segment(container, 'a', 'b');
    expect(ab.curvature, -0.5);
    expect(ab.legs, const [TransportLeg(TransportMode.walk)]);
  });

  testWidgets('straightens the line when dragged back to it', (tester) async {
    final container = await _pumpJeju(tester);
    await _tapChip(tester, '1일차');
    await _tapSegmentRow(tester, 0);
    await dragCurveHandle(tester, 0.6);

    await dragCurveHandle(tester, 0);

    expect(_segment(container, 'a', 'b').curvature, 0);
    final id = _segment(container, 'a', 'b').id;
    expect(
      mapScene(tester).lines.singleWhere((l) => l.id == id).points,
      hasLength(2),
    );
  });

  testWidgets('works from the bottom sheet on a portrait phone', (
    tester,
  ) async {
    final container = await _pumpJeju(tester, screen: const Size(412, 915));
    await _tapChip(tester, '1일차');
    await tester.drag(
      find.textContaining(RegExp('장소 ')).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await _tapSegmentRow(tester, 0);

    await dragCurveHandle(tester, 0.2);

    expect(_segment(container, 'a', 'b').curvature, 0.2);
  });
}
