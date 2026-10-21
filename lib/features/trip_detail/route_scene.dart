import 'package:flutter/material.dart';

import '../../core/map/map_provider.dart';
import '../../core/map/route_arrow.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/stop.dart';
import '../../data/models/trip_route.dart';

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
/// - 화살표: 선 가운데에 가는 방향으로, 선과 같은 색. 선이 화면에서 짧으면 숨는다.
({List<MapMarker> markers, List<MapLine> lines, List<MapArrow> arrows})
routeOverlays({
  required TripRoute route,
  required RouteView view,
  required AppColors colors,
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
  for (final segment in view.segments) {
    final from = route.stopById(segment.fromStopId);
    final to = route.stopById(segment.toStopId);
    // 같은 자리를 잇는 구간(예: 숙소를 다음 날 첫 장소로 또 넣음)은 그릴 것이 없다.
    if (from == null || to == null || from.isSamePlaceAs(to)) continue;
    final color = colors.routeDay(to.day).background;
    lines.add(
      MapLine(
        id: segment.id,
        points: [from.position, to.position],
        color: color,
        outline: colors.routeHalo,
      ),
    );
    // 선을 아직 직선으로만 그려서 곡률은 넘기지 않는다. 곡선 단위에서 선과 함께 넘긴다.
    if (routeArrow(from.position, to.position) case final arrow?) {
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
  return (markers: markers, lines: lines, arrows: arrows);
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
