import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/map/geo.dart';
import '../../core/map/map_provider.dart';
import '../../core/map/marker_icon.dart';
import '../../core/route/route_scene.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/photo.dart';
import '../../data/models/stop.dart';
import '../../data/models/trip.dart';
import '../../data/models/trip_route.dart';
import '../../l10n/l10n.dart';

/// 내보내기 이미지 크기(px). 비율은 4:5 하나다(인스타 피드에 잘리지 않고 대화방에서 한 장이 다 보인다).
const exportPixelSize = Size(1080, 1350);

/// 여행 후 이미지의 사진 마커는 앱 지도보다 이만큼 크게 그린다(사진 중심 회고).
const largePhotoScale = 1.6;

/// 이미지 가장자리에서 장소까지 띄우는 최소 여백(논리 px). 이름표가 옆으로 붙을 자리다.
const _sideRoom = AppSpace.xxl + AppSpace.sm;

/// 아래 여백(논리 px). 왼쪽 아래 지도 로고와 오른쪽 아래 앱 이름, 장소 아래 이름표가 들어간다.
const _bottomRoom = AppSpace.xxl * 2 + AppSpace.sm;

/// 미리보기에서 고르는 것. 상태(전, 중, 후)는 고르지 않고 여행의 지금 상태를 쓴다.
@immutable
class ExportOptions {
  const ExportOptions({
    this.day,
    this.photos = true,
    this.lodging = true,
    this.title = true,
  });

  /// null이면 여행 전체다.
  final int? day;
  final bool photos;
  final bool lodging;

  /// 위쪽 제목 카드(여행 제목과 날짜). 끄면 카드가 통째로 빠진다.
  final bool title;

  ExportOptions copyWith({
    int? Function()? day,
    bool? photos,
    bool? lodging,
    bool? title,
  }) => ExportOptions(
    day: day != null ? day() : this.day,
    photos: photos ?? this.photos,
    lodging: lodging ?? this.lodging,
    title: title ?? this.title,
  );

  @override
  bool operator ==(Object other) =>
      other is ExportOptions &&
      other.day == day &&
      other.photos == photos &&
      other.lodging == lodging &&
      other.title == title;

  @override
  int get hashCode => Object.hash(day, photos, lodging, title);
}

/// 이미지 위의 장소 마커와 이름.
@immutable
class ExportMarker {
  const ExportMarker({
    required this.id,
    required this.position,
    required this.look,
    required this.name,
    this.faded = false,
    this.large = false,
  });

  /// 장소 ID(같은 자리의 장소를 합친 마커는 동선에서 먼저 오는 장소).
  final String id;
  final LatLng position;
  final MarkerLook look;
  final String name;

  /// 아직 가지 않은 곳이라 흐리게 그린다. 이름표도 흐리다.
  final bool faded;

  /// [largePhotoScale]만큼 크게 그리는 사진 마커.
  final bool large;

  double get scale => large ? largePhotoScale : 1;

  /// 그림 크기(논리 px).
  Size get size => MarkerIcon.sizeOf(look) * scale;

  /// 장소 자리가 그림의 어디인지(가로, 세로 0~1).
  Offset get anchor => MarkerIcon.anchorOf(look);

  ExportMarker withLook(MarkerLook look) => ExportMarker(
    id: id,
    position: position,
    look: look,
    name: name,
    faded: faded,
    large: large && look.photo != null,
  );
}

/// 이미지에 그릴 것. 지도 동선([routeOverlays])과 같은 색과 규칙에 여행 상태별 표현을 더한다.
@immutable
class ExportScene {
  const ExportScene({
    required this.markers,
    required this.lines,
    required this.arrows,
    required this.lineIcons,
    required this.title,
    required this.subtitle,
    required this.legendDays,
    required this.hasPhotos,
    required this.bounds,
  });

  final List<ExportMarker> markers;
  final List<MapLine> lines;
  final List<MapArrow> arrows;
  final List<MapLineIcon> lineIcons;

  /// 제목 카드의 제목. null이면 제목 카드가 없다.
  final String? title;
  final String subtitle;

  /// 제목 카드의 일차 색 범례. 비어 있으면 없다.
  final List<int> legendDays;

  /// 범위 안에 사진이 있는 장소가 있는지. 없으면 [사진] 칩을 숨긴다.
  final bool hasPhotos;

  /// 지도를 맞출 범위. 보이는 장소가 없으면 null이다.
  final LatLngBounds? bounds;

  /// 장소 자리보다 위로 솟는 가장 큰 높이(논리 px). 제목 카드 아래로 이만큼 더 띄운다.
  double get headroom => markers.fold(
    0,
    (most, marker) => math.max(most, marker.anchor.dy * marker.size.height),
  );

  /// 지도를 맞출 범위와 여백. [titleBottom]은 제목 카드의 아래 끝(논리 px)이고, 카드가 없으면 null이다.
  MapFrame? frameFor({double? titleBottom}) {
    final bounds = this.bounds;
    if (bounds == null) return null;
    final halfWidth = markers.fold<double>(
      0,
      (most, marker) => math.max(most, marker.size.width / 2),
    );
    final side = math.max(_sideRoom, halfWidth + AppSpace.xs);
    return MapFrame(
      bounds: bounds,
      padding: EdgeInsets.fromLTRB(
        side,
        (titleBottom ?? 0) + AppSpace.md + headroom,
        side,
        _bottomRoom,
      ),
    );
  }
}

/// 내보내기 이미지에 그릴 것을 만든다.
///
/// - 범위와 숙소: 지도 보기와 같다([TripRoute.view]). 숙소를 끄면 숙소를 거친 곳은 흐린 선([RouteView.vias])이다.
/// - 여행 전([TripPhase.before]): 계획한 동선 그대로다.
/// - 여행 중: 방문한 곳과 양 끝을 모두 방문한 구간은 또렷하게, 남은 곳은 [AppOpacity.backdrop]만큼 흐리게 그린다.
///   방문한 마커에는 종류 배지 자리에 ✓ 배지를 단다. 흐린 구간에는 화살표와 선 아이콘이 없다.
///   (앱 지도는 방문해도 마커가 그대로다. 이미지는 진행 상황을 보여 주는 것이라 나눠 그린다.)
/// - 여행 후: 사진 마커를 [largePhotoScale]만큼 크게 그린다. 방문을 하나라도 적었으면 가지 않은 곳은 여행 중처럼 흐리고,
///   하나도 적지 않았으면(방문 체크를 쓰지 않은 여행) 모두 또렷하다.
/// - 후보는 넣지 않는다(이미지는 정한 동선의 결과물이다).
ExportScene buildExportScene({
  required Trip trip,
  required TripRoute route,
  required TripPhase phase,
  required ExportOptions options,
  required AppColors colors,
  required AppLocalizations l10n,
  required ImageProvider Function(Photo photo) photoOf,
}) {
  final fullView = route.view(day: options.day, showLodging: options.lodging);
  // 그 일차에 넣은 장소가 없으면 출발 장소(전날 숙소)만 남는다. 그림이 되지 않아 빈 범위로 본다.
  final view =
      options.day != null &&
          !fullView.stops.any((stop) => stop.day == options.day)
      ? const RouteView(stops: [], segments: [])
      : fullView;
  final overlays = routeOverlays(
    route: route,
    view: view,
    colors: colors,
    photoOf: options.photos ? photoOf : null,
  );
  final progress =
      phase == TripPhase.during ||
      (phase == TripPhase.after && route.stops.any((stop) => stop.visited));
  bool visitedPlace(Stop stop) =>
      view.stops.where(stop.isSamePlaceAs).any((s) => s.visited);
  bool visitedId(String id) {
    final stop = route.stopById(id);
    return stop != null && visitedPlace(stop);
  }

  Color dim(Color color) =>
      color.withValues(alpha: color.a * AppOpacity.backdrop);
  final large = phase == TripPhase.after && options.photos;

  final markers = [
    for (final marker in overlays.markers)
      if (!progress || visitedId(marker.id))
        ExportMarker(
          id: marker.id,
          position: marker.position,
          look: progress ? _checked(marker.look) : marker.look,
          name: marker.caption,
          large: large && marker.look.photo != null,
        )
      else
        ExportMarker(
          id: marker.id,
          position: marker.position,
          look: marker.look.faded(AppOpacity.backdrop),
          name: marker.caption,
          faded: true,
        ),
  ];

  // 구간 선의 ID는 구간 ID, 숙소를 거침은 RouteVia.id다.
  final segmentsById = {for (final s in view.segments) s.id: s};
  final viasById = {for (final via in view.vias) via.id: via};
  bool doneLine(String id) {
    if (!progress) return true;
    if (segmentsById[id] case final segment?) {
      return visitedId(segment.fromStopId) && visitedId(segment.toStopId);
    }
    if (viasById[id] case final via?) {
      return visitedPlace(via.from) && visitedPlace(via.to);
    }
    return true;
  }

  final lines = [
    for (final line in overlays.lines)
      doneLine(line.id)
          ? line
          : MapLine(
              id: line.id,
              points: line.points,
              color: dim(line.color),
              outline: dim(line.outline),
              style: line.style,
            ),
  ];

  final inRange = [
    for (final stop in view.stops)
      if (options.day == null || stop.day == options.day) stop,
  ];
  final places = inRange.where((stop) => !stop.isLodging).toList();
  final photoCount = inRange.where((stop) => stop.photo != null).length;
  final dates = trip.dates;
  final day = options.day;
  final rangeText = switch ((day, dates)) {
    (null, _) => null,
    (final day?, null) => l10n.routeDay(day),
    (final day?, final dates?) => l10n.itineraryTitleWithDate(
      day,
      dates.dateOfDay(day).toDateTime(),
    ),
  };
  // 여행 전체의 짧은 범위: 기간이 있으면 날짜, 없으면 일정.
  final shortRange =
      rangeText ??
      (dates == null
          ? l10n.nightsText(trip.nights)
          : l10n.tripDatesText(dates));
  final subtitle = switch (phase) {
    TripPhase.during => l10n.exportProgress(
      shortRange,
      places.length,
      places.where((stop) => stop.visited).length,
    ),
    TripPhase.after when options.photos && photoCount > 0 =>
      l10n.exportPhotoCount(shortRange, photoCount),
    _ => rangeText ?? l10n.tripSummaryOf(trip),
  };

  final days = {
    for (final marker in markers)
      if (route.stopById(marker.id) case final stop? when !stop.isLodging)
        stop.day,
  }.toList()..sort();

  final points = [
    for (final marker in markers) marker.position,
    for (final line in lines) ...line.points,
  ];

  return ExportScene(
    markers: markers,
    lines: lines,
    arrows: [
      for (final arrow in overlays.arrows)
        if (doneLine(arrow.id)) arrow,
    ],
    lineIcons: [
      for (final icon in overlays.lineIcons)
        if (doneLine(icon.id)) icon,
    ],
    title: options.title ? l10n.exportTripTitle(trip.title) : null,
    subtitle: subtitle,
    legendDays: options.day == null && days.length >= 2 && days.length <= 5
        ? days
        : const [],
    hasPhotos: view.stops.any((stop) => stop.photo != null),
    bounds: cameraBoundsFor(points),
  );
}

/// 방문한 장소의 마커: 종류 배지 자리에 ✓ 배지. 사진 마커에는 배지가 없어서 그대로다.
MarkerLook _checked(MarkerLook look) => MarkerLook(
  fill: look.fill,
  foreground: look.foreground,
  halo: look.halo,
  ring: look.ring,
  label: look.label,
  icon: look.icon,
  badge: Icons.check,
  small: look.small,
  photo: look.photo,
  photoFrame: look.photoFrame,
);
