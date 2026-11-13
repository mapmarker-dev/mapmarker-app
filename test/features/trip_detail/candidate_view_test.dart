import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/links/open_link.dart';
import 'package:mapmarker_app/core/map/external_map.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/candidate_list.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_day_panel.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_day_sheet.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 2박 3일 여행. 1일차: a > b > 숙소, 2일차: c.
final _stops = [
  testStop('a', tripId: 'jeju', kind: StopKind.tour),
  testStop('b', tripId: 'jeju', order: 1, kind: StopKind.food),
  testLodging('hotel', tripId: 'jeju', order: 2),
  testStop('c', tripId: 'jeju', day: 2),
];

/// 후보 두 곳. 넣은 순서: 우도, 카페. 동선보다 멀리 있다.
const _udo = Candidate(
  id: 'udo',
  tripId: 'jeju',
  latitude: 33.5,
  longitude: 126.95,
  name: '우도',
  kind: StopKind.tour,
  description: '배 타고 들어가는 섬',
  memo: '배 시간 확인',
);
const _cafe = Candidate(
  id: 'cafe',
  tripId: 'jeju',
  latitude: 33.4,
  longitude: 126.3,
  name: '카페',
  kind: StopKind.food,
);

Future<void> _pumpJeju(
  WidgetTester tester, {
  List<Candidate> candidates = const [_udo, _cafe],
  OpenLink? openLink,
}) => pumpTestApp(
  tester,
  repository: testRepository(
    [testTrip(id: 'jeju', region: '제주', nights: 2)],
    _stops,
    candidates,
  ),
  location: Routes.trip('jeju'),
  openLink: openLink ?? refuseLinks,
);

/// 지도의 후보 마커(보조 마커) ID.
List<String> _candidateMarkers(MapScene scene) => [
  for (final marker in scene.markers)
    if (marker.secondary) marker.id,
];

/// 지도의 장소 마커 ID.
List<String> _stopMarkers(MapScene scene) => [
  for (final marker in scene.markers)
    if (!marker.secondary) marker.id,
];

LatLngBounds _boundsOf(Iterable<LatLng> positions) =>
    cameraBoundsFor(positions)!;

Finder _inCandidate(String name, Finder finder) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(CandidateTile)),
  matching: finder,
);

void main() {
  testWidgets('puts the views on the first row and the filters below', (
    tester,
  ) async {
    await _pumpJeju(tester);

    Rect chip(String label) => tester.getRect(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) => w is ChoiceChip || w is FilterChip,
        ),
      ),
    );
    final all = chip('전체');
    // 첫 줄: 하나만 고르는 보기.
    expect(chip('1일차').top, all.top);
    expect(chip('후보 목록').top, all.top);
    expect(find.widgetWithText(ChoiceChip, '후보 목록'), findsOneWidget);
    // 둘째 줄: "함께 보기" 뒤의 켜고 끄는 필터.
    final label = tester.getRect(find.text('함께 보기'));
    expect(label.top, greaterThan(all.bottom));
    for (final filter in ['숙소', '후보']) {
      expect(find.widgetWithText(FilterChip, filter), findsOneWidget);
      expect(chip(filter).left, greaterThan(label.right));
      expect(
        chip(filter).center.dy,
        moreOrLessEquals(label.center.dy, epsilon: 1),
      );
    }
  });

  group('"후보" filter chip', () {
    testWidgets('shows candidates with the route from the start', (
      tester,
    ) async {
      await _pumpJeju(tester);

      final scene = mapScene(tester);
      expect(_candidateMarkers(scene), ['udo', 'cafe']);
      expect(_stopMarkers(scene), ['a', 'b', 'hotel', 'c']);
      // 후보는 작은 회색 마커다. 동선 카메라 맞춤에는 넣지 않는다.
      expect(scene.markers.first.look.small, isTrue);
      expect(
        scene.camera.bounds,
        _boundsOf(_stops.map((stop) => stop.position)),
      );

      await tapChip(tester, '2일차');

      expect(_candidateMarkers(mapScene(tester)), ['udo', 'cafe']);
    });

    testWidgets('hides candidates when turned off, in every day', (
      tester,
    ) async {
      await _pumpJeju(tester);
      final fit = mapScene(tester).camera.key;

      await tapChip(tester, '후보');

      expect(_candidateMarkers(mapScene(tester)), isEmpty);
      // 카메라는 그대로다(후보는 카메라 맞춤에 들지 않는다).
      expect(mapScene(tester).camera.key, fit);

      await tapChip(tester, '1일차');

      expect(_candidateMarkers(mapScene(tester)), isEmpty);
    });
  });

  group('"후보" view', () {
    testWidgets('lists candidates in order over the faded route', (
      tester,
    ) async {
      await _pumpJeju(tester);

      await tapChip(tester, '후보 목록');

      final scene = mapScene(tester);
      expect(_candidateMarkers(scene), ['udo', 'cafe']);
      // 동선은 흐리게 깔려 있고, 화살표·선 아이콘은 없다.
      expect(_stopMarkers(scene), ['a', 'b', 'hotel', 'c']);
      expect(scene.markers.last.look.fill.a, lessThan(1));
      expect(scene.lines, isNotEmpty);
      expect(scene.lines.every((line) => line.color.a < 1), isTrue);
      expect(scene.arrows, isEmpty);
      // 카메라는 후보에 맞춘다.
      expect(scene.camera.bounds, _boundsOf([_udo.position, _cafe.position]));

      // 기본 화면(800×600)은 가로라 오른쪽 패널이다.
      expect(find.byType(RouteDayPanel), findsOneWidget);
      expect(find.text('후보 장소'), findsOneWidget);
      expect(find.text('2곳'), findsOneWidget);
      final names = tester
          .widgetList<CandidateTile>(find.byType(CandidateTile))
          .map((tile) => tile.candidate.name);
      expect(names, ['우도', '카페']);
    });

    testWidgets('shows candidates even when the "후보" filter is off', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await tapChip(tester, '후보');

      await tapChip(tester, '후보 목록');

      expect(_candidateMarkers(mapScene(tester)), ['udo', 'cafe']);

      // 다른 보기로 가면 꺼 둔 대로다.
      await tapChip(tester, '전체');

      expect(_candidateMarkers(mapScene(tester)), isEmpty);
    });

    testWidgets('says there are no candidates yet', (tester) async {
      await _pumpJeju(tester, candidates: []);

      await tapChip(tester, '후보 목록');

      expect(find.textContaining('아직 후보가 없습니다.'), findsOneWidget);
      expect(find.text('없음'), findsOneWidget);
      // 후보가 없으면 카메라는 동선에 맞춘다.
      expect(
        mapScene(tester).camera.bounds,
        _boundsOf(_stops.map((stop) => stop.position)),
      );
    });

    testWidgets('expands a candidate to show its memo', (tester) async {
      await _pumpJeju(tester);
      await tapChip(tester, '후보 목록');
      expect(find.text('배 시간 확인'), findsNothing);

      await tester.tap(find.text('우도'));
      await tester.pumpAndSettle();

      expect(find.text('배 시간 확인'), findsOneWidget);
    });

    testWidgets('opens a candidate on Naver Map', (tester) async {
      final opened = <Uri>[];
      await _pumpJeju(
        tester,
        openLink: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await tapChip(tester, '후보 목록');

      await tester.tap(_inCandidate('카페', find.text('네이버 지도에서 영업시간·리뷰 보기')));
      await tester.pumpAndSettle();

      expect(opened, [naverMapSearchUri('카페', _cafe.position)]);
    });

    testWidgets('goes to the day of a stop tapped on the faded route', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await tapChip(tester, '후보 목록');

      await tapMarker(tester, 'c');

      expect(find.byType(CandidateList), findsNothing);
      expect(_stopMarkers(mapScene(tester)), ['hotel', 'c']);
    });
  });

  group('tapping a candidate on the map', () {
    testWidgets('opens the "후보" view on that candidate', (tester) async {
      await _pumpJeju(tester);
      await tapChip(tester, '1일차');

      await tapMarker(tester, 'cafe');

      expect(find.byType(CandidateList), findsOneWidget);
      final tile = tester.widget<CandidateTile>(
        find.ancestor(
          of: find.text('카페'),
          matching: find.byType(CandidateTile),
        ),
      );
      expect(tile.expanded, isTrue);
      expect(tile.highlighted, isTrue);
    });

    testWidgets('keeps the camera when already in the "후보" view', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await tapChip(tester, '후보 목록');
      final fit = mapScene(tester).camera.key;

      await tapMarker(tester, 'udo');

      expect(find.text('배 시간 확인'), findsOneWidget);
      expect(mapScene(tester).camera.key, fit);
    });

    testWidgets('raises the bottom sheet on a phone', (tester) async {
      usePortraitPhone(tester);
      await _pumpJeju(tester);

      await tapMarker(tester, 'udo');

      expect(find.byType(RouteDaySheet), findsOneWidget);
      expect(find.text('배 시간 확인'), findsOneWidget);
    });
  });
}
