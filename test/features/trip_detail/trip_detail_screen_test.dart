import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/external_map.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/theme/app_tokens.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_day_sheet.dart';
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
  testStop(
    'c',
    tripId: 'jeju',
    day: 2,
  ).copyWith(description: '바다 보며 산책', memo: '주차 2시간 무료'),
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
      // 선마다 가는 방향을 가리키는 화살표가 있다.
      expect(scene.arrows.map((a) => a.id), scene.lines.map((l) => l.id));
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
      expect(mapScene(tester).arrows, hasLength(2));
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

      expect(find.text('아직 장소가 없습니다.\n지도를 눌러 첫 장소를 넣어 보세요.'), findsOneWidget);
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

  group('day sheet', () {
    testWidgets('shows only in a day view', (tester) async {
      usePortraitPhone(tester);
      await _pumpJeju(tester);

      expect(find.byType(RouteDaySheet), findsNothing);

      await _tapChip(tester, '2일차');

      expect(find.byType(RouteDaySheet), findsOneWidget);
      // 날짜 미정 여행이라 날짜 없이 일차만 보인다. 출발 숙소는 세지 않는다.
      expect(find.text('장소 3곳'), findsOneWidget);

      await _tapChip(tester, '전체');

      expect(find.byType(RouteDaySheet), findsNothing);
    });

    testWidgets('lists the day from the lodging of the night before', (
      tester,
    ) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      expect(find.text('전날 묵은 숙소에서 출발'), findsOneWidget);
      expect(_tileNames(tester), ['hotel', 'c', 'd', 'hotel2']);
      // hotel>c, c>d, d>hotel2
      expect(find.text('이동 수단 미정'), findsNWidgets(3));
      // 설명은 접혀 있어도 보이고, 메모는 펼쳐야 보인다.
      expect(find.text('바다 보며 산책'), findsOneWidget);
      expect(find.text('주차 2시간 무료'), findsNothing);
      expect(find.text('관광'), findsOneWidget);
    });

    testWidgets('shows the date of the day', (tester) async {
      await pumpTestApp(
        tester,
        repository: testRepository([
          testTrip(
            id: 'jeju',
            region: '제주',
            dates: TripDates(LocalDate(2026, 10, 20), LocalDate(2026, 10, 22)),
          ),
        ], _stops),
        location: Routes.trip('jeju'),
      );

      await _tapChip(tester, '2일차');

      expect(find.text('2일차 · 10월 21일 (수)'), findsOneWidget);
    });

    testWidgets('keeps the handle and title on top while the list scrolls', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);
      final title = tester.getRect(find.text('장소 3곳'));
      final start = tester.getTopLeft(find.text('전날 묵은 숙소에서 출발')).dy;

      // 시트가 끝까지 올라온 뒤 목록을 넘긴다.
      await tester.drag(find.text('c'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('전날 묵은 숙소에서 출발', skipOffstage: false)).dy,
        lessThan(start),
        reason: '목록은 넘어간다',
      );
      expect(tester.getRect(find.text('장소 3곳')), title);
    });

    testWidgets('scrolls the list without resizing the sheet', (tester) async {
      usePortraitPhone(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      // 지도에서 장소를 누르면 시트가 가운데 높이(40%)로 올라온다.
      await tapMarker(tester, 'c');
      final title = tester.getRect(find.text('장소 3곳'));
      final lift = mapScene(tester).logoLift;
      expect(lift, greaterThan(0));
      double rowTop() =>
          tester.getTopLeft(find.text('전날 묵은 숙소에서 출발', skipOffstage: false)).dy;

      // 목록을 아래로 끌면 목록만 맨 위로 돌아간다. 시트는 내려가지 않는다.
      await tester.drag(find.text('c'), const Offset(0, 1000));
      await tester.pumpAndSettle();
      final top = rowTop();

      expect(tester.getRect(find.text('장소 3곳')), title);
      expect(mapScene(tester).logoLift, lift);

      // 목록을 위로 끌면 목록만 넘어간다. 시트는 올라가지 않는다.
      // 목록 맨 위 줄을 끈다. 40%에서는 아래 줄이 시트 밖에 있다.
      await tester.drag(find.text('전날 묵은 숙소에서 출발'), const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(rowTop(), lessThan(top));
      expect(tester.getRect(find.text('장소 3곳')), title);
      expect(mapScene(tester).logoLift, lift);

      // 시트 크기는 손잡이와 제목 줄을 끌어서 바꾼다.
      await tester.drag(find.text('장소 3곳'), const Offset(0, 1000));
      await tester.pumpAndSettle();

      expect(mapScene(tester).logoLift, 0);
      expect(tester.getRect(find.text('장소 3곳')).top, greaterThan(title.top));
    });

    testWidgets('highlights one row picked in the sheet', (tester) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      expect(_highlighted(tester), isEmpty);

      await tester.tap(find.text('c'));
      await tester.pumpAndSettle();

      expect(_highlighted(tester), ['c']);

      // c>d 구간 줄을 고르면 c는 풀린다.
      final cToD = tester
          .widgetList<ItinerarySegmentTile>(find.byType(ItinerarySegmentTile))
          .elementAt(1);
      await tester.tap(
        find.descendant(
          of: find.byWidget(cToD),
          matching: find.text('이동 수단 미정'),
        ),
      );
      await tester.pumpAndSettle();

      expect(_highlighted(tester), [cToD.segment.id]);

      // 지도에서 고르면 시트에서 고른 것도 바뀐다.
      await tapMarker(tester, 'd');

      expect(_highlighted(tester), ['d']);

      // 펼친 장소를 다시 누르면 접히지만 고른 것은 그대로다.
      await tester.tap(find.text('d'));
      await tester.pumpAndSettle();

      expect(_tile(tester, 'd').expanded, isFalse);
      expect(_highlighted(tester), ['d']);
    });

    testWidgets('expands a stop to show its memo', (tester) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      await tester.tap(find.text('c'));
      await tester.pumpAndSettle();

      expect(find.text('메모'), findsOneWidget);
      expect(find.text('주차 2시간 무료'), findsOneWidget);

      await tester.tap(find.text('c'));
      await tester.pumpAndSettle();

      expect(find.text('주차 2시간 무료'), findsNothing);
    });

    testWidgets('opens a stop in Naver Map by its name and place', (
      tester,
    ) async {
      _tallScreen(tester);
      final opened = <Uri>[];
      await pumpTestApp(
        tester,
        repository: testRepository([
          testTrip(id: 'jeju', region: '제주', nights: 2),
        ], _stops),
        location: Routes.trip('jeju'),
        openLink: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      await tester.tap(_inTile('d', find.text('네이버 지도에서 영업시간·리뷰 보기')));
      await tester.pumpAndSettle();

      final d = _stops.singleWhere((s) => s.id == 'd');
      expect(opened, [naverMapSearchUri('d', d.position)]);
      expect(find.text('네이버 지도를 열지 못했습니다.'), findsNothing);
    });

    testWidgets('says so when Naver Map cannot be opened', (tester) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      await tester.tap(_inTile('d', find.text('네이버 지도에서 영업시간·리뷰 보기')));
      await tester.pumpAndSettle();

      expect(find.text('네이버 지도를 열지 못했습니다.'), findsOneWidget);
    });

    testWidgets('deletes a stop after asking', (tester) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);
      await tester.tap(find.text('d'));
      await tester.pumpAndSettle();

      await tester.tap(_inTile('d', find.text('지우기')));
      await tester.pumpAndSettle();

      expect(find.text('‘d’ 지우기'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(_tileNames(tester), contains('d'));

      await tester.tap(_inTile('d', find.text('지우기')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('지우기'),
        ),
      );
      await tester.pumpAndSettle();

      expect(_tileNames(tester), ['hotel', 'c', 'hotel2']);
      expect(mapScene(tester).captions, ['hotel', 'c']);
      // 앞뒤 장소가 바로 이어진다.
      expect(_lines(mapScene(tester)), ['hotel>c', 'c>hotel']);
    });

    testWidgets('does not delete the lodging of the night before', (
      tester,
    ) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      await tester.tap(find.text('hotel'));
      await tester.pumpAndSettle();

      expect(_inTile('hotel', find.text('지우기')), findsNothing);
      expect(_inTile('hotel', find.byIcon(Icons.drag_handle)), findsNothing);
    });

    testWidgets('moves a stop by dragging its handle', (tester) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      // c를 d 아래로 끈다.
      final handle = _inTile('c', find.byIcon(Icons.drag_handle));
      final drag = await tester.startGesture(tester.getCenter(handle));
      // 줄 하나(d와 그 위 구간 줄)의 높이만큼 내리면 c와 d가 자리를 바꾼다.
      final rowHeight = tester.getSize(find.byKey(const ValueKey('d'))).height;
      await drag.moveBy(Offset(0, rowHeight / 2));
      await tester.pump();
      await drag.moveBy(Offset(0, rowHeight / 2 + 4));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(_tileNames(tester), ['hotel', 'd', 'c', 'hotel2']);
      final scene = mapScene(tester);
      expect(scene.captions, ['hotel', 'd', 'c']);
      // 번호도 동선 순서로 다시 붙는다.
      expect(scene.markers.map((m) => m.look.label), [null, '1', '2']);
      expect(_lines(scene), ['hotel>d', 'd>c', 'c>hotel']);
    });

    testWidgets('opens the day of a marker tapped in the whole trip', (
      tester,
    ) async {
      _tallScreen(tester);
      await _pumpJeju(tester);

      await tapMarker(tester, 'c');

      expect(mapScene(tester).captions, ['hotel', 'c', 'd']);
      expect(_tile(tester, 'c').highlighted, isTrue);
      expect(_tile(tester, 'c').expanded, isTrue);
      expect(_tile(tester, 'd').highlighted, isFalse);
      expect(find.text('주차 2시간 무료'), findsOneWidget);
      // 시트를 펼쳐 올린다.
      expect(mapScene(tester).logoLift, greaterThan(0));
    });

    testWidgets('shows both nights of a lodging tapped in a day view', (
      tester,
    ) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      final camera = mapScene(tester).camera.key;

      await tapMarker(tester, 'hotel');

      expect(_tile(tester, 'hotel').highlighted, isTrue);
      expect(_tile(tester, 'hotel2').highlighted, isTrue);
      expect(_tile(tester, 'c').highlighted, isFalse);
      // 시트만 바뀌고 카메라는 그대로다.
      expect(mapScene(tester).camera.key, camera);
    });

    testWidgets('asks which day for a place put in several days', (
      tester,
    ) async {
      _tallScreen(tester);
      Stop airport(String id, int day, int order) => testStop(
        id,
        tripId: 'jeju',
        day: day,
        order: order,
        latitude: 33.51,
        longitude: 126.49,
      );
      await pumpTestApp(
        tester,
        repository: testRepository(
          [testTrip(id: 'jeju', region: '제주', nights: 2)],
          [
            airport('arrive', 1, 0),
            testStop('sight', tripId: 'jeju', order: 1),
            testStop('cafe', tripId: 'jeju', day: 3),
            airport('leave', 3, 1),
          ],
        ),
        location: Routes.trip('jeju'),
      );

      // 같은 자리라 마커는 하나다.
      expect(mapScene(tester).captions, ['arrive', 'sight', 'cafe']);

      await tapMarker(tester, 'arrive');

      expect(find.text('어느 일차를 볼까요?'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('3일차'),
        ),
      );
      await tester.pumpAndSettle();

      expect(mapScene(tester).captions, ['cafe', 'leave']);
      expect(_tile(tester, 'leave').highlighted, isTrue);
    });

    testWidgets('shows the segment of a tapped line', (tester) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      final scene = mapScene(tester);
      final cToD = scene.lines[_lines(scene).indexOf('c>d')].id;

      await tapLine(tester, cToD);

      // 선 색의 일차(도착 장소의 일차)로 들어간다.
      expect(mapScene(tester).captions, ['hotel', 'c', 'd']);
      final segments = tester
          .widgetList<ItinerarySegmentTile>(find.byType(ItinerarySegmentTile))
          .where((tile) => tile.highlighted);
      expect(segments.map((tile) => tile.segment.id), [cToD]);
    });

    testWidgets('folds when the map is tapped', (tester) async {
      _tallScreen(tester);
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');

      await _openSheet(tester);

      expect(mapScene(tester).logoLift, greaterThan(0));

      await tapMap(tester, const LatLng(33.4, 126.5));

      expect(mapScene(tester).logoLift, 0);
    });

    testWidgets('keeps the map and the fit button above the folded sheet', (
      tester,
    ) async {
      usePortraitPhone(tester);
      showNavigationBar(tester);
      await _pumpJeju(tester);

      await _tapChip(tester, '2일차');

      final screen = tester.getRect(find.byType(Scaffold).last);
      final header = tester.getRect(find.text('장소 3곳'));
      final mapPadding = mapScene(tester).padding;
      // 접힌 시트(제목 줄)는 내비게이션 막대 위에 보인다.
      expect(header.bottom, lessThanOrEqualTo(screen.bottom - 48));
      // 지도 내용(로고, 카메라 맞춤)과 맞추기 버튼은 접힌 시트 위에 있다.
      expect(mapPadding.bottom, greaterThan(48));
      expect(screen.bottom - mapPadding.bottom, lessThanOrEqualTo(header.top));
      expect(
        tester.getBottomRight(find.byTooltip('동선에 맞추기')).dy,
        lessThanOrEqualTo(screen.bottom - mapPadding.bottom - AppSpace.lg),
      );
      expect(mapScene(tester).logoLift, 0);
    });
  });
}

/// 시트를 펼쳐도 장소가 모두 보이게 화면을 키운다.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize =
      const Size(800, 1800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
}

/// 시트 제목 줄을 끌어 올려 시트를 끝까지 펼친다.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.drag(
    find.textContaining(RegExp('장소 ')).last,
    const Offset(0, -1600),
  );
  await tester.pumpAndSettle();
}

ItineraryStopTile _tile(WidgetTester tester, String name) =>
    tester.widget<ItineraryStopTile>(_tileFinder(name));

Finder _tileFinder(String name) => find.byWidgetPredicate(
  (w) => w is ItineraryStopTile && w.stop.name == name,
);

Finder _inTile(String name, Finder finder) =>
    find.descendant(of: _tileFinder(name), matching: finder);

/// 시트의 장소 줄 이름. 위에서부터다.
List<String> _tileNames(WidgetTester tester) => [
  for (final tile in tester.widgetList<ItineraryStopTile>(
    find.byType(ItineraryStopTile),
  ))
    tile.stop.name,
];

/// 바탕색이 바뀐(고른) 장소 이름과 구간 ID. 위에서부터다.
List<String> _highlighted(WidgetTester tester) => [
  for (final tile in tester.widgetList<Widget>(
    find.byWidgetPredicate(
      (w) => w is ItineraryStopTile || w is ItinerarySegmentTile,
    ),
  ))
    if (tile case ItineraryStopTile(:final stop, highlighted: true))
      stop.name
    else if (tile case ItinerarySegmentTile(:final segment, highlighted: true))
      segment.id,
];
