import 'package:flutter/material.dart';

import '../../core/map/map_provider.dart';
import '../../core/map/route_arrow.dart';
import '../../core/map/route_curve.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/stop.dart';
import '../../data/models/trip_route.dart';
import 'transport_look.dart';

/// 숙소 마커 가운데 아이콘.
const lodgingIcon = Icons.bed;

/// 마커 배지. 숙소는 마커 자체가 다르고, 기타는 배지 없이 번호만 보인다.
IconData? kindBadge(StopKind kind) => switch (kind) {
  StopKind.food => Icons.restaurant,
  StopKind.tour => Icons.photo_camera,
  StopKind.lodging || StopKind.other => null,
};

/// 보이는 동선을 지도의 마커와 선으로 바꾼다.
///
/// - 숙소가 아닌 장소: 일차 색 원에 일차 안 번호, 오른쪽 위에 종류 배지.
/// - 숙소: 숙소 색 원에 침대 아이콘.
/// - 같은 자리에 여러 번 넣은 장소(연박한 숙소, 처음과 끝이 같은 공항)는 종류와 상관없이 마커 하나로 합친다.
///   마커는 동선에서 먼저 오는 장소의 것이다. 누르면 [stopsAtMarker]로 그 자리의 장소를 모두 찾는다.
/// - 선: 도착 장소의 일차 색. 일차를 넘는 구간은 다음 날 아침의 이동이라 다음 날 색이다.
///   모양은 구간의 대표 수단으로 정한다([lineStyleOf], [representativeMode]). 미정은 실선이다.
///   곡률이 있으면 곡선으로 그린다([routeCurvePoints]).
/// - 화살표: 선 가운데에 가는 방향으로, 선과 같은 색. 선이 화면에서 짧으면 숨는다.
/// - 선 아이콘: 대표 수단 아이콘을 선의 1/4 지점(출발 쪽)에 둔다. 화살표와 겹치지 않는다.
///   미정 구간에는 없고, 선이 화면에서 짧아지면 화살표보다 조금 먼저(출발 마커와 겹치기 전에) 숨는다.
/// - 곡선 핸들: [curveSegmentId] 구간(일차 동선 목록에서 직접 고른 구간)의 가운데에 둔다.
///   핸들 안에 진행 방향 화살표가 있어서, 그 구간의 화살표와 선 아이콘은 그리지 않는다.
({
  List<MapMarker> markers,
  List<MapLine> lines,
  List<MapArrow> arrows,
  List<MapLineIcon> lineIcons,
  MapCurveHandle? curveHandle,
})
routeOverlays({
  required TripRoute route,
  required RouteView view,
  required AppColors colors,
  String? curveSegmentId,
}) {
  final markers = <MapMarker>[];
  final drawn = <Stop>[];
  for (final stop in view.stops) {
    if (drawn.any(stop.isSamePlaceAs)) continue;
    drawn.add(stop);
    markers.add(
      MapMarker(
        id: stop.id,
        position: stop.position,
        caption: stop.name,
        look: markerLookOf(route, stop, colors),
      ),
    );
  }

  final lines = <MapLine>[];
  final arrows = <MapArrow>[];
  final lineIcons = <MapLineIcon>[];
  MapCurveHandle? curveHandle;
  for (final segment in view.segments) {
    final from = route.stopById(segment.fromStopId);
    final to = route.stopById(segment.toStopId);
    // 같은 자리를 잇는 구간(예: 숙소를 다음 날 첫 장소로 또 넣음)은 그릴 것이 없다.
    if (from == null || to == null || from.isSamePlaceAs(to)) continue;
    final dayColors = colors.routeDay(to.day);
    final color = dayColors.background;
    final mode = representativeMode(segment.legs);
    final curvature = segment.curvature;
    lines.add(
      MapLine(
        id: segment.id,
        points: routeCurvePoints(from.position, to.position, curvature),
        color: color,
        outline: colors.routeHalo,
        style: lineStyleOf(mode),
      ),
    );
    if (segment.id == curveSegmentId) {
      curveHandle = MapCurveHandle(
        id: segment.id,
        from: from.position,
        to: to.position,
        curvature: curvature,
        color: color,
        outline: colors.routeHalo,
      );
      continue;
    }
    if (mode != null) {
      if (routeLineIcon(from.position, to.position, curvature: curvature)
          case final place?) {
        lineIcons.add(
          MapLineIcon(
            id: segment.id,
            position: place.position,
            icon: transportIcon(mode),
            background: colors.routeHalo,
            border: color,
            foreground: dayColors.foreground,
            minZoom: place.minZoom,
          ),
        );
      }
    }
    if (routeArrow(from.position, to.position, curvature: curvature)
        case final arrow?) {
      arrows.add(
        MapArrow(
          id: segment.id,
          position: arrow.position,
          bearing: arrow.bearing,
          color: color,
          outline: colors.routeHalo,
          minZoom: arrow.minZoom,
        ),
      );
    }
  }
  return (
    markers: markers,
    lines: lines,
    arrows: arrows,
    lineIcons: lineIcons,
    curveHandle: curveHandle,
  );
}

/// 장소를 넣으려고 지도를 누른 자리의 임시 핀 ID. 장소 ID(UUID)와 겹치지 않는다.
const draftMarkerId = 'draft';

/// 임시 핀. 주 색 원에 + 아이콘이고, 심볼을 눌렀으면 그 이름을 단다.
MapMarker draftMarker(MapTap place, ColorScheme scheme, AppColors colors) =>
    MapMarker(
      id: draftMarkerId,
      position: place.position,
      caption: place.placeName ?? '',
      look: MarkerLook(
        fill: scheme.primary,
        foreground: scheme.onPrimary,
        halo: colors.routeHalo,
        icon: Icons.add,
      ),
    );

/// 장소의 마커 그림. 일차 동선 시트의 장소 줄도 같은 그림을 쓴다.
MarkerLook markerLookOf(TripRoute route, Stop stop, AppColors colors) {
  final dayColors = stop.isLodging
      ? colors.routeLodging
      : colors.routeDay(stop.day);
  return MarkerLook(
    fill: dayColors.background,
    foreground: dayColors.foreground,
    halo: colors.routeHalo,
    label: route.numberOf(stop)?.toString(),
    icon: stop.isLodging ? lodgingIcon : null,
    badge: kindBadge(stop.kind),
  );
}

/// [markerId] 마커가 나타내는 장소들. 같은 자리의 보이는 장소를 동선 순서로 모은다.
/// 지도에 없는 마커면 빈 목록이다.
List<Stop> stopsAtMarker(RouteView view, String markerId) {
  final marked = view.stops.where((stop) => stop.id == markerId).firstOrNull;
  if (marked == null) return const [];
  return [
    for (final stop in view.stops)
      if (stop.isSamePlaceAs(marked)) stop,
  ];
}
