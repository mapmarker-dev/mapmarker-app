import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_capture.dart';

void main() {
  const jeju = LatLng(33.5, 126.5);
  const size = Size(400, 500);

  test('a centered projection puts the center in the middle', () {
    final projection = MapProjection.centered(jeju, 10, size);

    expect(projection.toScreen(jeju), const Offset(200, 250));
  });

  test('one zoom step doubles distances on the screen', () {
    const east = LatLng(33.5, 126.6);
    double width(double zoom) {
      final p = MapProjection.centered(jeju, zoom, size);
      return (p.toScreen(east) - p.toScreen(jeju)).dx;
    }

    expect(width(11), closeTo(width(10) * 2, 1e-6));
  });

  test('turns screen positions back into places', () {
    final projection = MapProjection.fromPairs(
      (const LatLng(33.2, 126.2), const Offset(40, 460)),
      (const LatLng(33.6, 126.9), const Offset(360, 120)),
    );
    const place = LatLng(33.41, 126.55);

    final back = projection.toLatLng(projection.toScreen(place));

    expect(back.latitude, closeTo(place.latitude, 1e-9));
    expect(back.longitude, closeTo(place.longitude, 1e-9));
  });

  test('frames that fit and frames at a place differ', () {
    final fit = MapFrame.fit(
      bounds: LatLngBounds.around(const [jeju, LatLng(33.4, 126.9)]),
      padding: const EdgeInsets.all(8),
    );
    const at = MapFrame.at(center: jeju, zoom: 12);

    expect(fit, isNot(at));
    expect(at, const MapFrame.at(center: jeju, zoom: 12));
    expect(at.bounds, isNull);
  });
}
