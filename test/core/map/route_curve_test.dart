import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/route_arrow.dart';
import 'package:mapmarker_app/core/map/route_curve.dart';

const _jeju = LatLng(33.5, 126.5);
const _east = LatLng(33.5, 126.54);

void main() {
  group('curve points', () {
    test('are just the two ends for a straight segment', () {
      expect(routeCurvePoints(_jeju, _east, 0), [_jeju, _east]);
    });

    test('start and end at the stops and bend through the middle', () {
      final points = routeCurvePoints(_jeju, _east, 0.4);
      final arrow = routeArrow(_jeju, _east, curvature: 0.4)!;

      expect(points.length, greaterThan(10));
      expect(points.first, _jeju);
      expect(points.last, _east);
      // 가운데 점은 곡선 가운데(화살표 자리)다.
      final middle = points[points.length ~/ 2];
      expect(middle.latitude, closeTo(arrow.position.latitude, 1e-9));
      expect(middle.longitude, closeTo(arrow.position.longitude, 1e-9));
      // 동쪽으로 가는 구간에서 k > 0이면 남쪽(화면 아래)으로 휜다.
      expect(middle.latitude, lessThan(_jeju.latitude));
    });

    test('bend the other way for a negative curvature', () {
      final points = routeCurvePoints(_jeju, _east, -0.4);

      expect(points[points.length ~/ 2].latitude, greaterThan(33.5));
    });
  });

  group('curvature from the handle', () {
    const from = Offset(100, 300);
    const to = Offset(300, 300);

    test('goes back to the same handle place', () {
      for (final k in [0.2, -0.5, 1.0]) {
        final handle = curveMiddleOnScreen(from, to, k);

        expect(curvatureForHandle(from, to, handle), closeTo(k, 1e-9));
      }
    });

    test('bends toward the side the handle was pulled', () {
      // 화면은 아래로 갈수록 y가 크다. 동쪽으로 가는 선을 아래로 끌면 k > 0이다.
      expect(curvatureForHandle(from, to, const Offset(200, 360)), 0.6);
      expect(curvatureForHandle(from, to, const Offset(200, 240)), -0.6);
    });

    test('snaps to a straight line near the line', () {
      expect(
        curvatureForHandle(
          from,
          to,
          const Offset(200, 300 + curveSnapDistance - 1),
        ),
        0,
      );
      expect(
        curvatureForHandle(
          from,
          to,
          const Offset(200, 300 + curveSnapDistance + 1),
        ),
        isNot(0),
      );
    });

    test('ignores how far along the line the handle moves', () {
      expect(
        curvatureForHandle(from, to, const Offset(120, 360)),
        curvatureForHandle(from, to, const Offset(200, 360)),
      );
    });

    test('stops at the largest curvature', () {
      expect(
        curvatureForHandle(from, to, const Offset(200, 2000)),
        maxCurvature,
      );
      expect(
        curvatureForHandle(from, to, const Offset(200, -2000)),
        -maxCurvature,
      );
    });

    test('is the same however the map is zoomed or turned', () {
      const handle = Offset(180, 350);
      final k = curvatureForHandle(from, to, handle);

      Offset turn(Offset p) {
        const angle = math.pi / 3;
        final x = p.dx * math.cos(angle) - p.dy * math.sin(angle);
        final y = p.dx * math.sin(angle) + p.dy * math.cos(angle);
        return Offset(x, y) * 2.5 + const Offset(40, -70);
      }

      expect(
        curvatureForHandle(turn(from), turn(to), turn(handle)),
        closeTo(k, 1e-9),
      );
    });

    test('is zero between the same place', () {
      expect(curvatureForHandle(from, from, const Offset(0, 0)), 0);
    });
  });

  test('points the handle along the curve', () {
    const from = Offset(0, 0);
    const to = Offset(200, 0);

    // 동쪽으로 가는 선의 가운데는 휘어도 동쪽(90도)을 가리킨다(대칭인 곡선).
    expect(curveBearingOnScreen(from, to, 0), closeTo(90, 1e-9));
    expect(curveBearingOnScreen(from, to, 0.7), closeTo(90, 1e-9));
    // 북쪽(화면 위)으로 가는 선은 0도다.
    expect(
      curveBearingOnScreen(const Offset(0, 200), Offset.zero, 0),
      closeTo(0, 1e-9),
    );
  });
}
