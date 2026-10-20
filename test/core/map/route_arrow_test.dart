import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/route_arrow.dart';

const _jeju = LatLng(33.5, 126.5);

/// [from]에서 북쪽으로 [north]도, 동쪽으로 [east]도 떨어진 곳.
LatLng _offset(LatLng from, {double north = 0, double east = 0}) =>
    LatLng(from.latitude + north, from.longitude + east);

void main() {
  test('goes to and from mercator without losing the place', () {
    for (final p in const [_jeju, LatLng(0, 0), LatLng(-33.9, 151.2)]) {
      final back = latLngOfMercator(mercatorOf(p));

      expect(back.latitude, closeTo(p.latitude, 1e-9));
      expect(back.longitude, closeTo(p.longitude, 1e-9));
    }
  });

  test('points the way the segment goes', () {
    double bearing(LatLng to) => routeArrow(_jeju, to)!.bearing;

    expect(bearing(_offset(_jeju, north: 0.01)), closeTo(0, 1e-6));
    expect(bearing(_offset(_jeju, east: 0.01)), closeTo(90, 1e-6));
    expect(bearing(_offset(_jeju, north: -0.01)), closeTo(180, 1e-6));
    expect(bearing(_offset(_jeju, east: -0.01)), closeTo(270, 1e-6));
  });

  test('measures direction on the map, not in raw degrees', () {
    // 위도 60도에서 경도 1도는 위도 1도의 절반 길이로 보인다.
    // 위도·경도를 같은 만큼 가면 지도에서는 45도가 아니라 북동쪽보다 북쪽에 가깝다.
    const north60 = LatLng(60, 10);

    final arrow = routeArrow(
      north60,
      _offset(north60, north: 0.001, east: 0.001),
    )!;

    expect(arrow.bearing, closeTo(math.atan(0.5) * 180 / math.pi, 0.01));
  });

  test('sits in the middle of a straight segment', () {
    final to = _offset(_jeju, north: 0.02, east: 0.04);

    final arrow = routeArrow(_jeju, to)!;

    expect(arrow.position.latitude, closeTo(33.51, 1e-4));
    expect(arrow.position.longitude, closeTo(126.52, 1e-9));
  });

  test('sits on the bend of a curved segment, along the chord', () {
    final to = _offset(_jeju, east: 0.04);

    final straight = routeArrow(_jeju, to)!;
    final curved = routeArrow(_jeju, to, curvature: 0.3)!;

    expect(curved.position, isNot(straight.position));
    // 대칭인 2차 베지어의 가운데 방향은 양 끝을 잇는 방향과 같다.
    expect(curved.bearing, closeTo(straight.bearing, 1e-6));
  });

  test('has no direction between the same place', () {
    expect(routeArrow(_jeju, _jeju), isNull);
  });

  test('hides the arrow until the line is long enough on screen', () {
    final short = routeArrow(_jeju, _offset(_jeju, east: 0.01))!;
    final long = routeArrow(_jeju, _offset(_jeju, east: 0.02))!;

    // 두 배 긴 선은 한 단계 멀리서도 보인다.
    expect(short.minZoom - long.minZoom, closeTo(1, 1e-9));
    // 제주에서 동쪽으로 0.01도(약 0.93km)는 줌 13.3부터 화면에서 72px이 넘는다.
    expect(short.minZoom, closeTo(13.3, 0.05));
    expect(
      routeArrow(_jeju, _offset(_jeju, east: 150))!.minZoom,
      0,
      reason: '아주 긴 선은 언제나 보인다',
    );
  });
}
