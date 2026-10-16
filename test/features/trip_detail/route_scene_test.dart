import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/theme/app_colors.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
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

  test('follows the view', () {
    final day2 = routeOverlays(
      route: route,
      view: route.view(day: 2, showLodging: false),
      colors: _colors,
    );

    expect(day2.markers.map((m) => m.id), ['shop']);
    expect(day2.lines, isEmpty);
  });
}
