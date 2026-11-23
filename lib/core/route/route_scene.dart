import 'package:flutter/material.dart';

import '../map/map_provider.dart';
import '../map/route_arrow.dart';
import '../map/route_curve.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../../data/models/photo.dart';
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
/// - 저장을 기다리는 구간([savingSegmentId], 끌어 놓은 곡선): 선을 [AppOpacity.pending]만큼 흐리게 그리고,
///   화살표와 선 아이콘은 그리지 않는다. 저장되면 보통 선으로 돌아온다.
/// - 숙소를 거침([RouteView.vias]): 흐린 가는 파선([MapLineStyle.faint]) 직선 하나. 선 목록 맨 앞이다.
/// - [faded]("후보 목록" 보기): 후보가 어디쯤인지 보이게 동선 전체를 [AppOpacity.backdrop]만큼 흐리게 깐다.
///   마커와 선만 그리고 화살표·선 아이콘·곡선 핸들은 없다. 마커는 누를 수 있다(그 일차로 간다).
/// - 사진([photoOf]): 사진이 있는 장소는 둥근 사각 사진 마커다([MarkerLook.photo]). 합친 마커는 그 자리 장소 중
///   동선에서 먼저 오는 사진을 쓴다. [faded]에서는 보통 원 마커다.
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
  String? savingSegmentId,
  bool faded = false,
  ImageProvider Function(Photo photo)? photoOf,
}) {
  Color backdrop(Color color) =>
      faded ? color.withValues(alpha: color.a * AppOpacity.backdrop) : color;
  final markers = <MapMarker>[];
  final drawn = <Stop>[];
  for (final stop in view.stops) {
    if (drawn.any(stop.isSamePlaceAs)) continue;
    drawn.add(stop);
    var look = markerLookOf(route, stop, colors);
    final photo = view.stops
        .where(stop.isSamePlaceAs)
        .map((s) => s.photo)
        .nonNulls
        .firstOrNull;
    if (photo != null && photoOf != null) {
      // 테두리를 일차 색보다 조금 어둡게 해서 선과 붙어 보이지 않게 한다. 숙소 색은 이미 어둡다.
      look = look.withPhoto(
        photoOf(photo),
        frame: stop.isLodging ? null : colors.routePhotoFrame(stop.day),
      );
    }
    markers.add(
      MapMarker(
        id: stop.id,
        position: stop.position,
        caption: stop.name,
        look: faded ? look.faded(AppOpacity.backdrop) : look,
      ),
    );
  }

  // 숙소를 거침: 숙소를 끈 보기에서 낮에 들른 숙소 앞뒤를 흐린 가는 파선으로 바로 잇는다.
  // 실제 구간이 아니라서 화살표·선 아이콘·곡선이 없고 누를 수 없다. 색은 도착 장소의 일차 색을 흐리게 쓴다.
  final lines = <MapLine>[
    for (final via in view.vias)
      MapLine(
        id: via.id,
        points: [via.from.position, via.to.position],
        color: backdrop(colors.routeVia(via.to.day)),
        outline: backdrop(colors.routeHalo),
        style: MapLineStyle.faint,
      ),
  ];
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
    final saving = segment.id == savingSegmentId;
    Color dim(Color color) => saving
        ? color.withValues(alpha: color.a * AppOpacity.pending)
        : backdrop(color);
    lines.add(
      MapLine(
        id: segment.id,
        points: routeCurvePoints(from.position, to.position, curvature),
        color: dim(color),
        outline: dim(colors.routeHalo),
        style: lineStyleOf(mode),
      ),
    );
    if (saving || faded) continue;
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

/// 후보 장소 마커들. 마커 ID는 후보 ID다(장소 ID와 겹치지 않는다).
///
/// - 전체·일차 보기("후보"를 켰을 때): 흰 바탕·회색 테두리의 작은 원에 종류 아이콘, 흐린 이름이다
///   ([MapMarker.secondary]). 동선의 마커·선 아이콘보다 아래에 그려 동선을 가리지 않는다.
/// - [focused]("후보 목록" 보기): 후보가 주인공이라 진한 보통 크기 마커에 또렷한 이름이다.
///   부른 쪽이 흐린 동선보다 뒤에 넣어 위에 그린다.
List<MapMarker> candidateMarkers(
  TripRoute route,
  AppColors colors, {
  bool focused = false,
}) => [
  for (final candidate in route.candidates)
    MapMarker(
      id: candidate.id,
      position: candidate.position,
      caption: candidate.name,
      look: candidateLookOf(candidate.kind, colors, focused: focused),
      secondary: !focused,
    ),
];

/// 후보의 마커 그림. 후보 목록의 줄도 같은 그림을 쓴다.
/// [focused]면 "후보 목록" 보기의 진한 마커다([candidateMarkers]).
MarkerLook candidateLookOf(
  StopKind kind,
  AppColors colors, {
  bool focused = false,
}) => MarkerLook(
  fill: focused
      ? colors.routeCandidateFocus.background
      : colors.routeCandidate.background,
  foreground: focused
      ? colors.routeCandidateFocus.foreground
      : colors.routeCandidate.foreground,
  halo: colors.routeHalo,
  ring: focused ? null : colors.routeCandidateRing,
  icon: switch (kind) {
    StopKind.lodging => lodgingIcon,
    StopKind.food || StopKind.tour => kindBadge(kind),
    StopKind.other => Icons.place,
  },
  small: !focused,
);

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
