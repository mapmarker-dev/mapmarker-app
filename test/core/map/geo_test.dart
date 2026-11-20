import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';

void main() {
  test('bounds hold every point', () {
    final bounds = LatLngBounds.around(const [
      LatLng(37.58, 126.98),
      LatLng(37.55, 126.99),
      LatLng(37.57, 126.97),
    ]);

    expect(bounds.southWest, const LatLng(37.55, 126.97));
    expect(bounds.northEast, const LatLng(37.58, 126.99));
    expect(bounds.center.latitude, closeTo(37.565, 1e-9));
    expect(bounds.center.longitude, closeTo(126.98, 1e-9));
  });

  test('bounds need at least one point', () {
    expect(() => LatLngBounds.around(const []), throwsArgumentError);
  });

  group('camera bounds', () {
    test('does not move the camera without stops', () {
      expect(cameraBoundsFor(const []), isNull);
    });

    test('widens a single stop so the map does not zoom all the way in', () {
      final bounds = cameraBoundsFor(const [LatLng(33.45, 126.56)])!;

      expect(bounds.center, const LatLng(33.45, 126.56));
      expect(
        bounds.northEast.latitude - bounds.southWest.latitude,
        closeTo(minCameraSpan, 1e-9),
      );
      expect(
        bounds.northEast.longitude - bounds.southWest.longitude,
        closeTo(minCameraSpan, 1e-9),
      );
    });

    test('widens only the narrow side', () {
      final bounds = cameraBoundsFor(const [
        LatLng(33.45, 126.30),
        LatLng(33.45, 126.90),
      ])!;

      expect(bounds.southWest.longitude, 126.30);
      expect(bounds.northEast.longitude, 126.90);
      expect(
        bounds.northEast.latitude - bounds.southWest.latitude,
        closeTo(minCameraSpan, 1e-9),
      );
    });

    test('keeps a wide route as it is', () {
      const points = [LatLng(33.2, 126.2), LatLng(33.5, 126.9)];

      expect(cameraBoundsFor(points), LatLngBounds.around(points));
    });
  });

  group('distanceMeters', () {
    test('is zero for the same point and symmetric', () {
      const a = LatLng(35.8346, 129.2187);
      const b = LatLng(35.8350, 129.2245);
      expect(distanceMeters(a, a), 0);
      expect(distanceMeters(a, b), closeTo(distanceMeters(b, a), 1e-9));
    });

    test('matches known distances', () {
      // 위도 0.01도는 약 1112m다.
      expect(
        distanceMeters(const LatLng(37.0, 127.0), const LatLng(37.01, 127.0)),
        closeTo(1112, 2),
      );
      // 서울시청에서 부산시청까지 직선으로 약 325km다.
      expect(
        distanceMeters(
          const LatLng(37.5663, 126.9779),
          const LatLng(35.1798, 129.0750),
        ),
        closeTo(325000, 3000),
      );
    });
  });

  test('boundsAround reaches the given distance on every side', () {
    const center = LatLng(35.8346, 129.2187);
    final bounds = boundsAround(center, 1000);

    expect(bounds.center.latitude, closeTo(center.latitude, 1e-9));
    expect(bounds.center.longitude, closeTo(center.longitude, 1e-9));
    expect(
      distanceMeters(center, LatLng(bounds.northEast.latitude, 129.2187)),
      closeTo(1000, 1),
    );
    expect(
      distanceMeters(center, LatLng(35.8346, bounds.northEast.longitude)),
      closeTo(1000, 5),
    );
  });
}
