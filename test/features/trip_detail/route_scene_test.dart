import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/map/route_arrow.dart';
import 'package:mapmarker_app/core/map/route_curve.dart';
import 'package:mapmarker_app/core/theme/app_colors.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/route_links.dart';
import 'package:mapmarker_app/features/trip_detail/route_scene.dart';

import '../../helpers/test_stops.dart';

final _colors = AppTheme.light().extension<AppColors>()!;

TripRoute _route(List<Stop> stops) => TripRoute(
  stops: stops,
  segments: linkStops(
    tripId: 'trip',
    stops: TripRoute(stops: stops).stops,
    existing: const [],
  ),
);

void main() {
  // 1일차: 관광 > 음식 > 숙소, 2일차: 기타 > 숙소(연박) > 같은 숙소를 또 넣음
  final route = _route([
    testStop('sight', kind: StopKind.tour),
    testStop('lunch', order: 1, kind: StopKind.food),
    testLodging('hotel', order: 2),
    testStop('shop', day: 2),
    testLodging('hotel2', day: 2, order: 1),
    testLodging('hotel3', day: 2, order: 2),
  ]);
  final whole = routeOverlays(
    route: route,
    view: route.view(),
    colors: _colors,
  );

  test('numbers places in the color of their day', () {
    final [sight, lunch, _, shop] = whole.markers;

    expect([sight, lunch, shop].map((m) => m.look.label), ['1', '2', '1']);
    expect(sight.look.fill, _colors.routeDay(1).background);
    expect(sight.look.foreground, _colors.routeDay(1).foreground);
    expect(shop.look.fill, _colors.routeDay(2).background);
    expect(sight.look.halo, _colors.routeHalo);
  });

  test('badges food and tour but not other places', () {
    expect(whole.markers.map((m) => m.look.badge), [
      Icons.photo_camera,
      Icons.restaurant,
      null,
      null,
    ]);
  });

  test('draws lodging once per place with its own look', () {
    final lodging = whole.markers[2];

    expect(whole.markers.map((m) => m.id), ['sight', 'lunch', 'hotel', 'shop']);
    expect(lodging.look.icon, lodgingIcon);
    expect(lodging.look.label, isNull);
    expect(lodging.look.fill, _colors.routeLodging.background);
  });

  test('colors lines by the day they arrive in', () {
    final colors = [for (final line in whole.lines) line.color];

    // sight>lunch, lunch>hotel, hotel>shop(다음 날 아침), shop>hotel2.
    // hotel2>hotel3는 같은 자리라 그리지 않는다.
    expect(colors, [
      _colors.routeDay(1).background,
      _colors.routeDay(1).background,
      _colors.routeDay(2).background,
      _colors.routeDay(2).background,
    ]);
    expect(whole.lines.every((l) => l.outline == _colors.routeHalo), isTrue);
  });

  test('puts an arrow on each line, pointing from start to end', () {
    expect(whole.arrows.map((a) => a.id), whole.lines.map((l) => l.id));
    for (final (i, arrow) in whole.arrows.indexed) {
      final line = whole.lines[i];
      final expected = routeArrow(line.points.first, line.points.last)!;

      expect(arrow.color, line.color);
      expect(arrow.outline, _colors.routeHalo);
      expect(arrow.position, expected.position);
      expect(arrow.bearing, expected.bearing);
      expect(arrow.minZoom, expected.minZoom);
    }
  });

  test('follows the view', () {
    final day2 = routeOverlays(
      route: route,
      view: route.view(day: 2, showLodging: false),
      colors: _colors,
    );

    expect(day2.markers.map((m) => m.id), ['shop']);
    expect(day2.lines, isEmpty);
    expect(day2.arrows, isEmpty);
  });

  group('same place twice', () {
    // 공항에서 시작해 공항에서 끝나는 여행. 공항은 숙소가 아니다.
    Stop airport(String id, {required int day, int order = 0}) => testStop(
      id,
      day: day,
      order: order,
      latitude: 33.51,
      longitude: 126.49,
    );
    final trip = _route([
      airport('arrive', day: 1),
      testStop('sight', order: 1),
      testStop('cafe', day: 2),
      airport('leave', day: 2, order: 1),
    ]);

    test('draws one marker, the first in the route', () {
      final overlays = routeOverlays(
        route: trip,
        view: trip.view(),
        colors: _colors,
      );

      expect(overlays.markers.map((m) => m.id), ['arrive', 'sight', 'cafe']);
      expect(overlays.markers.first.look.label, '1');
      expect(overlays.markers.first.look.fill, _colors.routeDay(1).background);
    });

    test('finds every visible place under the marker', () {
      expect(stopsAtMarker(trip.view(), 'arrive').map((s) => s.id), [
        'arrive',
        'leave',
      ]);
      expect(stopsAtMarker(trip.view(day: 2), 'leave').map((s) => s.id), [
        'leave',
      ]);
      expect(stopsAtMarker(trip.view(), 'sight').map((s) => s.id), ['sight']);
      expect(stopsAtMarker(trip.view(day: 2), 'sight'), isEmpty);
    });

    test('finds the lodging of both nights in a day view', () {
      // 2일차 보기: 출발 숙소(hotel)와 그날 밤 숙소(hotel2)는 같은 자리다.
      expect(stopsAtMarker(route.view(day: 2), 'hotel').map((s) => s.id), [
        'hotel',
        'hotel2',
        'hotel3',
      ]);
    });
  });

  group('transport', () {
    // 1일차: a > b > c > d > 숙소. 구간마다 이동 수단이 다르다.
    final stops = [
      testStop('a'),
      testStop('b', order: 1),
      testStop('c', order: 2),
      testStop('d', order: 3),
      testLodging('hotel', order: 4),
    ];
    final legsByPair = <(String, String), List<TransportLeg>>{
      ('a', 'b'): const [TransportLeg(TransportMode.walk)],
      ('b', 'c'): const [
        TransportLeg(TransportMode.subway, stopCount: 2),
        TransportLeg(TransportMode.walk),
      ],
      ('c', 'd'): const [TransportLeg(TransportMode.ferry)],
      // d > hotel은 미정.
    };
    final linked = linkStops(
      tripId: 'trip',
      stops: TripRoute(stops: stops).stops,
      existing: const [],
    );
    final trip = TripRoute(
      stops: stops,
      segments: [
        for (final s in linked)
          s.copyWith(legs: legsByPair[(s.fromStopId, s.toStopId)]),
      ],
    );
    final overlays = routeOverlays(
      route: trip,
      view: trip.view(),
      colors: _colors,
    );

    test('shapes each line by its representative mode', () {
      expect(overlays.lines.map((l) => l.style), [
        MapLineStyle.dotted,
        MapLineStyle.solid,
        MapLineStyle.dashed,
        MapLineStyle.solid,
      ]);
    });

    test('puts the mode icon on decided lines only', () {
      final ids = [for (final s in trip.segments) s.id];

      expect(overlays.lineIcons.map((i) => i.id), ids.take(3));
      expect(overlays.lineIcons.map((i) => i.icon), [
        Icons.directions_walk,
        Icons.subway,
        Icons.directions_boat,
      ]);
    });

    test('places icons a quarter of the way, in the colors of the day', () {
      for (final icon in overlays.lineIcons) {
        final line = overlays.lines.singleWhere((l) => l.id == icon.id);
        final expected = routeLineIcon(line.points.first, line.points.last)!;

        expect(icon.position, expected.position);
        expect(icon.minZoom, expected.minZoom);
        expect(icon.border, line.color);
        expect(icon.background, _colors.routeHalo);
        expect(icon.foreground, _colors.routeDay(1).foreground);
      }
    });
  });

  test('keeps undecided routes as before: solid lines, no icons', () {
    expect(whole.lines.every((l) => l.style == MapLineStyle.solid), isTrue);
    expect(whole.lineIcons, isEmpty);
  });

  group('curves', () {
    final stops = [
      testStop('a'),
      testStop('b', order: 1),
      testStop('c', order: 2),
    ];
    final linked = linkStops(
      tripId: 'trip',
      stops: TripRoute(stops: stops).stops,
      existing: const [],
    );
    final [ab, bc] = linked;
    final trip = TripRoute(
      stops: stops,
      segments: [
        ab.copyWith(
          curvature: 0.4,
          legs: const [TransportLeg(TransportMode.bus)],
        ),
        bc,
      ],
    );

    ({
      List<MapMarker> markers,
      List<MapLine> lines,
      List<MapArrow> arrows,
      List<MapLineIcon> lineIcons,
      MapCurveHandle? curveHandle,
    })
    overlaysOf({String? curveSegmentId}) => routeOverlays(
      route: trip,
      view: trip.view(day: 1),
      colors: _colors,
      curveSegmentId: curveSegmentId,
    );

    test('draws curved segments as points along the curve', () {
      final [curved, straight] = overlaysOf().lines;
      final a = trip.stopById('a')!.position;
      final b = trip.stopById('b')!.position;

      expect(curved.points, routeCurvePoints(a, b, 0.4));
      expect(curved.points.length, greaterThan(2));
      expect(straight.points, hasLength(2));
    });

    test('puts the arrow and the icon on the curve', () {
      final overlays = overlaysOf();
      final a = trip.stopById('a')!.position;
      final b = trip.stopById('b')!.position;

      expect(
        overlays.arrows.first.position,
        routeArrow(a, b, curvature: 0.4)!.position,
      );
      expect(
        overlays.lineIcons.single.position,
        routeLineIcon(a, b, curvature: 0.4)!.position,
      );
    });

    test('has no handle unless a segment is picked in the list', () {
      expect(overlaysOf().curveHandle, isNull);
      expect(overlaysOf(curveSegmentId: 'missing').curveHandle, isNull);
    });

    test('puts the handle on the picked segment instead of its arrow', () {
      final overlays = overlaysOf(curveSegmentId: ab.id);
      final handle = overlays.curveHandle!;

      expect(handle.id, ab.id);
      expect(handle.from, trip.stopById('a')!.position);
      expect(handle.to, trip.stopById('b')!.position);
      expect(handle.curvature, 0.4);
      expect(handle.color, _colors.routeDay(1).background);
      expect(handle.outline, _colors.routeHalo);
      // 핸들 안에 화살표가 있어서 그 구간의 화살표와 선 아이콘은 그리지 않는다. 선은 그대로다.
      expect(overlays.arrows.map((a) => a.id), [bc.id]);
      expect(overlays.lineIcons, isEmpty);
      expect(overlays.lines.map((l) => l.id), [ab.id, bc.id]);
    });
  });
}
