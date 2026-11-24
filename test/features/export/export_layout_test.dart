import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/map/route_arrow.dart';
import 'package:mapmarker_app/core/theme/app_colors.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/models/photo.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/route_links.dart';
import 'package:mapmarker_app/features/export/export_layout.dart';
import 'package:mapmarker_app/features/export/export_scene.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

final _colors = AppTheme.light().extension<AppColors>()!;

const _size = Size(400, 500);

/// 이름 글자마다 8, 높이 18인 이름표.
Size _labelSize(String name) => Size(name.length * 8.0 + 16, 18);

ExportMarker _marker(String id, LatLng position) => ExportMarker(
  id: id,
  position: position,
  name: id,
  look: MarkerLook(
    fill: _colors.routeDay(1).background,
    foreground: _colors.routeDay(1).foreground,
    halo: _colors.routeHalo,
    label: '1',
  ),
);

ExportScene _sceneOf(
  List<ExportMarker> markers, {
  List<MapArrow> arrows = const [],
  List<MapLine> lines = const [],
}) => ExportScene(
  markers: markers,
  lines: lines,
  arrows: arrows,
  lineIcons: const [],
  title: null,
  subtitle: '',
  legendDays: const [],
  hasPhotos: false,
  bounds: cameraBoundsFor([for (final m in markers) m.position]),
);

/// 위도·경도 0~1을 이미지 전체에 편 좌표 변환.
final _projection = MapProjection.fromPairs(
  (const LatLng(0, 0), const Offset(0, 500)),
  (const LatLng(1, 1), const Offset(400, 0)),
);

ExportLayout _layout(ExportScene scene, {List<Rect> reserved = const []}) =>
    layoutExport(
      scene: scene,
      projection: _projection,
      size: _size,
      reserved: reserved,
      labelSize: _labelSize,
    );

void main() {
  test('places every stop below the title card', () {
    // 제주 동서로 긴 동선. 지도를 맞춘 여백 안에 장소가 모두 들어와야 한다.
    final stops = [
      testStop('a', latitude: 33.52, longitude: 126.30),
      testStop('b', order: 1, latitude: 33.25, longitude: 126.55),
      testStop('c', order: 2, latitude: 33.46, longitude: 126.94),
    ];
    final route = TripRoute(
      stops: stops,
      segments: linkStops(tripId: 'trip', stops: stops, existing: const []),
    );
    final scene = buildExportScene(
      trip: testTrip(id: 'trip'),
      route: route,
      phase: TripPhase.before,
      options: const ExportOptions(),
      colors: _colors,
      l10n: testL10n,
      photoOf: (photo) => NetworkImage(photo.thumbnailUrl),
    );
    const card = Rect.fromLTWH(12, 12, 200, 60);
    final frame = scene.frameFor(titleBottom: card.bottom)!;
    final capture = fakeCapture(frame, _size);

    final layout = layoutExport(
      scene: scene,
      projection: capture.projection,
      size: _size,
      reserved: [card, capture.logo],
      labelSize: _labelSize,
    );

    for (final placed in layout.markers) {
      expect(placed.rect.overlaps(card), isFalse, reason: placed.marker.name);
      expect((Offset.zero & _size).contains(placed.rect.center), isTrue);
    }
    expect(layout.labels.map((l) => l.marker.name), ['a', 'b', 'c']);
    for (final label in layout.labels) {
      expect(label.rect.overlaps(card), isFalse);
      expect(label.rect.overlaps(capture.logo), isFalse);
    }
  });

  test('puts the name below the marker when there is room', () {
    final layout = _layout(_sceneOf([_marker('용두암', const LatLng(0.5, 0.5))]));

    final marker = layout.markers.single.rect;
    final label = layout.labels.single.rect;
    expect(label.top, greaterThan(marker.bottom));
    expect(label.center.dx, closeTo(marker.center.dx, 0.01));
  });

  test('moves the name beside the marker when below is taken', () {
    final scene = _sceneOf([_marker('용두암', const LatLng(0.5, 0.5))]);
    final marker = _layout(scene).markers.single.rect;
    final below = Rect.fromLTWH(0, marker.bottom, _size.width, 40);

    final label = _layout(scene, reserved: [below]).labels.single.rect;

    expect(label.left, greaterThan(marker.right));
  });

  test('drops a name with no room but keeps the marker', () {
    final scene = _sceneOf([_marker('용두암', const LatLng(0.5, 0.5))]);

    final layout = _layout(scene, reserved: [Offset.zero & _size]);

    expect(layout.markers, hasLength(1));
    expect(layout.labels, isEmpty);
  });

  test('names do not cover each other', () {
    final layout = _layout(
      _sceneOf([
        _marker('첫째 장소', const LatLng(0.5, 0.5)),
        _marker('둘째 장소', const LatLng(0.5, 0.51)),
      ]),
    );

    final [first, second] = layout.labels;
    expect(first.rect.overlaps(second.rect), isFalse);
  });

  test('hides arrows on lines too short on the image', () {
    MapLine line(String id, LatLng from, LatLng to) => MapLine(
      id: id,
      points: [from, to],
      color: _colors.routeDay(1).background,
      outline: _colors.routeHalo,
    );
    MapArrow arrow(String id, LatLng at) => MapArrow(
      id: id,
      position: at,
      bearing: 90,
      color: _colors.routeDay(1).background,
      outline: _colors.routeHalo,
    );
    const a = LatLng(0.2, 0.2);
    const near = LatLng(0.2, 0.25);
    const far = LatLng(0.2, 0.8);

    final layout = _layout(
      _sceneOf(
        [_marker('a', a)],
        lines: [line('short', a, near), line('long', a, far)],
        arrows: [arrow('short', near), arrow('long', far)],
      ),
    );

    // 짧은 선은 화면에서 20px, 긴 선은 240px쯤이다.
    expect(arrowMinLineLength, inInclusiveRange(21, 239));
    expect(layout.arrows.map((a) => a.$1.id), ['long']);
  });

  test('puts the name across from a photo below the place', () {
    final marker = _marker('용두암', const LatLng(0.5, 0.5));
    final below = ExportMarker(
      id: marker.id,
      position: marker.position,
      name: marker.name,
      look: marker.look.withPhoto(
        const AssetImage('missing.png'),
        side: PhotoSide.down,
      ),
    );

    final layout = _layout(_sceneOf([below]));

    final photo = layout.markers.single.rect;
    final label = layout.labels.single.rect;
    expect(label.bottom, lessThan(photo.top));
    // 사진이 아래로 뻗어서 지도를 맞출 때 아래 여백이 더 크다.
    final plain = _sceneOf([marker]).frameFor()!;
    expect(
      _sceneOf([below]).frameFor()!.padding.bottom,
      greaterThan(plain.padding.bottom),
    );
  });
}
