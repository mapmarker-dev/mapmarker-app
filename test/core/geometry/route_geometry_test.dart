import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/geometry/route_geometry.dart';

void main() {
  group('quadraticControlPoint', () {
    const a = Offset(0, 0);
    const b = Offset(100, 0);

    test('k = 0 is the midpoint (straight line)', () {
      expect(quadraticControlPoint(a, b, 0), const Offset(50, 0));
    });

    test('moves perpendicular to the segment, flipping with the sign of k', () {
      expect(quadraticControlPoint(a, b, 0.2), const Offset(50, 20));
      expect(quadraticControlPoint(a, b, -0.2), const Offset(50, -20));
    });
  });

  test('quadraticPoint hits both ends and the curve middle', () {
    const a = Offset(0, 0);
    const c = Offset(50, 20);
    const b = Offset(100, 0);
    expect(quadraticPoint(a, c, b, 0), a);
    expect(quadraticPoint(a, c, b, 1), b);
    expect(quadraticPoint(a, c, b, 0.5), const Offset(50, 10));
  });

  test('quadraticTangent at the middle points from a to b', () {
    final t = quadraticTangent(
      const Offset(0, 0),
      const Offset(50, 20),
      const Offset(100, 0),
      0.5,
    );
    expect(t.dx, greaterThan(0));
    expect(t.dy, 0);
  });
}
