import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/theme/app_tokens.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_title_bar.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

Future<void> _rename(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('제목 바꾸기'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    title,
  );
  await tester.tap(find.text('저장'));
  await tester.pumpAndSettle();
}

/// 2박 3일 여행.
/// 1일차: a > b > 숙소, 2일차: c > d > 숙소(연박, 같은 자리), 3일차: 없음.
final _stops = [
  testStop('a', tripId: 'jeju', kind: StopKind.tour),
  testStop('b', tripId: 'jeju', order: 1, kind: StopKind.food),
  testLodging('hotel', tripId: 'jeju', order: 2),
  testStop('c', tripId: 'jeju', day: 2),
  testStop('d', tripId: 'jeju', day: 2, order: 1, kind: StopKind.tour),
  testLodging('hotel2', tripId: 'jeju', day: 2, order: 2),
];

Future<void> _pumpJeju(WidgetTester tester) => pumpTestApp(
  tester,
  repository: testRepository([
    testTrip(id: 'jeju', region: '제주', nights: 2),
  ], _stops),
  location: Routes.trip('jeju'),
);

/// 일차 칩이나 숙소 칩을 누른다. 칩은 글자가 아니라 칩 전체가 눌린다.
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

/// 선이 잇는 마커 이름. 예: `a>b`. 연박한 숙소는 같은 자리라 처음 이름(hotel)으로 읽는다.
List<String> _lines(MapScene scene) {
  final names = <LatLng, String>{};
  for (final stop in _stops) {
    names.putIfAbsent(stop.position, () => stop.id);
  }
  return [
    for (final line in scene.lines)
      '${names[line.points.first]}>${names[line.points.last]}',
  ];
}

LatLngBounds _boundsOf(List<String> ids) => cameraBoundsFor([
  for (final stop in _stops)
    if (ids.contains(stop.id)) stop.position,
])!;

void main() {
  testWidgets('shows the trip title', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
      location: Routes.trip('busan'),
    );

    expect(find.text('부산 1박 2일 봄 여행'), findsOneWidget);
    // 상태와 기간·일정이 제목 아래에 있다.
    expect(find.text('여행 전 · 날짜 미정 · 1박 2일'), findsOneWidget);
  });

  testWidgets('renames the trip', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
      location: Routes.trip('busan'),
    );

    await _rename(tester, '가족 여행');

    expect(find.text('가족 여행'), findsOneWidget);

    // 목록에도 바뀐 제목이 보인다.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('가족 여행'), findsOneWidget);
  });

  testWidgets('goes back to the default title when cleared', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([
        testTrip(id: 'busan').copyWith(title: '가족 여행'),
      ]),
      location: Routes.trip('busan'),
    );

    await _rename(tester, '');

    expect(find.text('부산 1박 2일 봄 여행'), findsOneWidget);
  });

  testWidgets('keeps the title when renaming is canceled', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
      location: Routes.trip('busan'),
    );

    await tester.tap(find.byTooltip('제목 바꾸기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '가족 여행');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('부산 1박 2일 봄 여행'), findsOneWidget);
  });

  testWidgets('says so when the trip does not exist', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository(),
      location: Routes.trip('missing'),
    );

    expect(find.text('여행을 찾을 수 없습니다.'), findsOneWidget);
  });

  group('route map', () {
    testWidgets('shows the whole trip first', (tester) async {
      await _pumpJeju(tester);

      final scene = mapScene(tester);
      // 연박한 숙소는 마커 하나다.
      expect(scene.captions, ['a', 'b', 'hotel', 'c', 'd']);
      expect(scene.markers.map((m) => m.look.label), [
        '1',
        '2',
        null,
        '1',
        '2',
      ]);
      expect(_lines(scene), ['a>b', 'b>hotel', 'hotel>c', 'c>d', 'd>hotel']);
      expect(scene.camera.bounds, _boundsOf(['a', 'b', 'hotel', 'c', 'd']));
      expect(find.byTooltip('동선에 맞추기'), findsOneWidget);
    });

    testWidgets('shows one day from the lodging of the night before', (
      tester,
    ) async {
      await _pumpJeju(tester);
      final before = mapScene(tester).camera.key;

      await _tapChip(tester, '2일차');

      final scene = mapScene(tester);
      expect(scene.captions, ['hotel', 'c', 'd']);
      expect(_lines(scene), ['hotel>c', 'c>d', 'd>hotel']);
      expect(scene.camera.key, isNot(before));
      expect(scene.camera.bounds, _boundsOf(['hotel', 'c', 'd']));

      await _tapChip(tester, '1일차');

      expect(mapScene(tester).captions, ['a', 'b', 'hotel']);
    });

    testWidgets('hides lodging and the lines to it', (tester) async {
      await _pumpJeju(tester);

      await _tapChip(tester, '숙소');

      expect(mapScene(tester).captions, ['a', 'b', 'c', 'd']);
      expect(_lines(mapScene(tester)), ['a>b', 'c>d']);
      expect(mapScene(tester).camera.bounds, _boundsOf(['a', 'b', 'c', 'd']));

      // 일차를 바꿔도 숙소는 꺼진 채로 있다.
      await _tapChip(tester, '2일차');

      expect(mapScene(tester).captions, ['c', 'd']);
    });

    testWidgets('says when a day has nothing to show', (tester) async {
      await _pumpJeju(tester);

      await _tapChip(tester, '3일차');

      // 3일차는 장소가 없지만 전날 숙소에서 출발한다.
      expect(mapScene(tester).captions, ['hotel2']);
      expect(find.text('3일차에는 장소가 없습니다.'), findsNothing);

      await _tapChip(tester, '숙소');

      expect(mapScene(tester).markers, isEmpty);
      expect(mapScene(tester).camera.bounds, isNull);
      expect(find.text('3일차에는 장소가 없습니다.'), findsOneWidget);
      expect(find.byTooltip('동선에 맞추기'), findsNothing);
    });

    testWidgets('says when the trip has no stops yet', (tester) async {
      await pumpTestApp(
        tester,
        repository: testRepository([testTrip(id: 'busan')]),
        location: Routes.trip('busan'),
      );

      expect(find.text('아직 장소가 없습니다.'), findsOneWidget);
      expect(mapScene(tester).markers, isEmpty);
      expect(mapScene(tester).camera.bounds, isNull);
      expect(find.byTooltip('동선에 맞추기'), findsNothing);
    });

    testWidgets('fits the camera again on request', (tester) async {
      await _pumpJeju(tester);
      final before = mapScene(tester).camera.key;

      await tester.tap(find.byTooltip('동선에 맞추기'));
      await tester.pumpAndSettle();

      expect(mapScene(tester).camera.key, isNot(before));
    });

    testWidgets('draws the map behind the system bars only', (tester) async {
      final padding = FakeViewPadding(
        top: 24 * tester.view.devicePixelRatio,
        bottom: 48 * tester.view.devicePixelRatio,
      );
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      addTearDown(tester.view.reset);

      await _pumpJeju(tester);

      final screen = tester.getRect(find.byType(Scaffold).last);
      // 지도는 화면 전체에 그린다.
      expect(tester.getRect(find.byType(FakeMap)), screen);
      // 제목 카드는 상태 표시줄 밑에서 시작한다.
      expect(
        tester.getTopLeft(find.byType(RouteTitleBar)).dy,
        greaterThanOrEqualTo(24),
      );
      // 지도 내용(로고, 카메라 맞춤)은 제목 카드·일차 칩과 내비게이션 막대를 피한다.
      final mapPadding = mapScene(tester).padding;
      expect(mapPadding.bottom, 48);
      expect(
        mapPadding.top,
        greaterThan(tester.getBottomLeft(find.text('전체')).dy),
      );
      // 맞추기 버튼도 내비게이션 막대 위에 있다.
      expect(
        tester.getBottomRight(find.byTooltip('동선에 맞추기')).dy,
        lessThanOrEqualTo(screen.bottom - 48 - AppSpace.lg),
      );
    });
  });
}
