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
}
