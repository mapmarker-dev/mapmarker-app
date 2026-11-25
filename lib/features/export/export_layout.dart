import 'package:flutter/material.dart';

import '../../core/map/geo.dart';
import '../../core/map/map_provider.dart';
import '../../core/map/route_arrow.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/photo.dart';
import 'export_scene.dart';

/// 이름표와 마커 사이, 이름표와 이미지 가장자리 사이의 틈(논리 px).
const _labelGap = AppSpace.xs / 2;

/// 자리를 잡은 마커.
@immutable
class PlacedMarker {
  const PlacedMarker(this.marker, this.rect);

  final ExportMarker marker;

  /// 마커 그림이 들어가는 곳(논리 px).
  final Rect rect;
}

/// 자리를 잡은 이름표.
@immutable
class PlacedLabel {
  const PlacedLabel(this.marker, this.rect);

  final ExportMarker marker;
  final Rect rect;
}

/// 화면 위치로 바꾼 이미지의 그림 요소.
@immutable
class ExportLayout {
  const ExportLayout({
    required this.lines,
    required this.arrows,
    required this.lineIcons,
    required this.markers,
    required this.labels,
  });

  final List<(MapLine, List<Offset>)> lines;
  final List<(MapArrow, Offset)> arrows;
  final List<(MapLineIcon, Offset)> lineIcons;
  final List<PlacedMarker> markers;
  final List<PlacedLabel> labels;
}

/// [scene]을 [size] 이미지(논리 px) 위에 놓는다. [projection]은 찍은 지도의 좌표 변환이다.
///
/// - 화살표와 선 아이콘은 앱 지도와 같은 규칙으로, 선이 화면에서 짧으면 뺀다([arrowMinLineLength], [lineIconMinLineLength]).
/// - 이름표는 마커 아래, 오른쪽, 왼쪽, 위 순서로 둘 곳을 찾는다. 이미지 밖, [reserved](제목 카드, 로고, 앱 이름),
///   다른 마커와 이름표에 겹치지 않는 첫 자리다. 둘 곳이 없으면 이름표만 뺀다(번호는 마커에 남는다).
///   동선 순서로 자리를 잡아서 앞 장소의 이름이 먼저 들어간다.
ExportLayout layoutExport({
  required ExportScene scene,
  required MapProjection projection,
  required Size size,
  required List<Rect> reserved,
  required Size Function(String name) labelSize,
}) {
  Offset at(LatLng position) => projection.toScreen(position);
  final markers = [
    for (final marker in scene.markers)
      PlacedMarker(marker, _markerRect(marker, at(marker.position))),
  ];

  final bounds = (Offset.zero & size).deflate(_labelGap);
  final labels = <PlacedLabel>[];
  for (final placed in markers) {
    if (placed.marker.name.isEmpty) continue;
    final label = labelSize(placed.marker.name);
    final box = placed.rect;
    final below = Rect.fromLTWH(
      box.center.dx - label.width / 2,
      box.bottom + _labelGap,
      label.width,
      label.height,
    );
    final right = Rect.fromLTWH(
      box.right + _labelGap,
      box.center.dy - label.height / 2,
      label.width,
      label.height,
    );
    final left = Rect.fromLTWH(
      box.left - _labelGap - label.width,
      box.center.dy - label.height / 2,
      label.width,
      label.height,
    );
    final above = Rect.fromLTWH(
      box.center.dx - label.width / 2,
      box.top - _labelGap - label.height,
      label.width,
      label.height,
    );
    // 사진 마커는 사진 반대쪽(장소 자리 쪽)부터 찾는다. 앱 지도의 이름 자리와 같다.
    final look = placed.marker.look;
    final candidates = look.photo == null
        ? [below, right, left, above]
        : switch (look.photoSide) {
            PhotoSide.up => [below, right, left, above],
            PhotoSide.down => [above, right, left, below],
            PhotoSide.left => [right, below, above, left],
            PhotoSide.right => [left, below, above, right],
          };
    bool free(Rect rect) =>
        _contains(bounds, rect) &&
        !reserved.any(rect.overlaps) &&
        !labels.any((other) => other.rect.overlaps(rect)) &&
        !markers.any(
          (other) => !identical(other, placed) && other.rect.overlaps(rect),
        );
    if (candidates.where(free).firstOrNull case final rect?) {
      labels.add(PlacedLabel(placed.marker, rect));
    }
  }

  final lines = [
    for (final line in scene.lines)
      (line, [for (final p in line.points) at(p)]),
  ];
  // 선의 화면 길이는 양 끝 사이 거리다(앱 지도가 줌으로 숨기는 기준과 같다).
  final chords = {
    for (final (line, points) in lines)
      line.id: (points.first - points.last).distance,
  };
  List<(T, Offset)> farEnough<T>(
    List<T> items,
    String Function(T) idOf,
    LatLng Function(T) positionOf,
    double minLength,
  ) => [
    for (final item in items)
      if ((chords[idOf(item)] ?? 0) >= minLength) (item, at(positionOf(item))),
  ];

  return ExportLayout(
    lines: lines,
    arrows: farEnough(
      scene.arrows,
      (a) => a.id,
      (a) => a.position,
      arrowMinLineLength,
    ),
    lineIcons: farEnough(
      scene.lineIcons,
      (i) => i.id,
      (i) => i.position,
      lineIconMinLineLength,
    ),
    markers: markers,
    labels: labels,
  );
}

Rect _markerRect(ExportMarker marker, Offset point) {
  final size = marker.size;
  final anchor = marker.anchor;
  return Rect.fromLTWH(
    point.dx - anchor.dx * size.width,
    point.dy - anchor.dy * size.height,
    size.width,
    size.height,
  );
}

bool _contains(Rect outer, Rect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;
