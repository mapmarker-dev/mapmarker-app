import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/prototype/route_geometry.dart';

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

  group('detectImageFormat', () {
    test('PNG', () {
      expect(
        detectImageFormat(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D])),
        'PNG',
      );
    });

    test('JPEG', () {
      expect(
        detectImageFormat(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        'JPEG',
      );
    });

    test('WebP', () {
      expect(
        detectImageFormat(
          Uint8List.fromList('RIFF\x00\x00\x00\x00WEBP'.codeUnits),
        ),
        'WebP',
      );
    });

    test('unknown', () {
      expect(detectImageFormat(Uint8List.fromList([1, 2])), 'unknown');
    });
  });
}
