import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/map/geo.dart';
import '../../core/map/map_provider.dart';
import '../../core/map/marker_icon.dart';
import '../../core/route/route_scene.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/photo.dart';
import '../../data/models/trip.dart';
import '../../data/models/trip_route.dart';
import '../../l10n/l10n.dart';

/// 내보내기 이미지 크기(px). 비율은 4:5 하나다(인스타 피드에 잘리지 않고 대화방에서 한 장이 다 보인다).
const exportPixelSize = Size(1080, 1350);

/// 여행 후 이미지의 사진 마커는 앱 지도보다 이만큼 크게 그린다. 사진은 잘 보이되 다른 장소와 동선을 덮지 않을 만큼이다.
const largePhotoScale = 1.3;

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
    this.large = false,
  });

  /// 장소 ID(같은 자리의 장소를 합친 마커는 동선에서 먼저 오는 장소).
  final String id;
  final LatLng position;
  final MarkerLook look;
  final String name;

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
/// 가장 중요한 것은 동선의 순서와 장소가 어디인지다. 그래서 여행 전, 중, 후 모두, 방문 여부와 사진에
/// 관계없이 모든 장소와 구간을 똑같이 또렷하게 그린다. 방문 기록은 이미지에 넣지 않는다.
///
/// - 범위와 숙소: 지도 보기와 같다([TripRoute.view]). 숙소를 끄면 숙소를 거친 곳은 흐린 선([RouteView.vias])이다.
/// - 여행 후: 사진 마커를 [largePhotoScale]만큼 조금 크게 그리고, 제목 아래 줄에 사진 수를 붙인다.
///   사진 마커가 번호 마커를 가리지 않게 번호 마커를 위에 그린다([ExportCanvas]).
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
  final large = phase == TripPhase.after && options.photos;
  final markers = [
    for (final marker in overlays.markers)
      ExportMarker(
        id: marker.id,
        position: marker.position,
        look: marker.look,
        name: marker.caption,
        large: large && marker.look.photo != null,
      ),
  ];
  final lines = overlays.lines;

  final inRange = [
    for (final stop in view.stops)
      if (options.day == null || stop.day == options.day) stop,
  ];
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
  // 전체는 기간과 일정(예: 2026.10.20 – 10.22, 2박 3일), 일차는 그 날짜다.
  final range = rangeText ?? l10n.tripSummaryOf(trip);
  final subtitle = phase == TripPhase.after && options.photos && photoCount > 0
      ? l10n.exportPhotoCount(range, photoCount)
      : range;

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
    arrows: overlays.arrows,
    lineIcons: overlays.lineIcons,
    title: options.title ? l10n.exportTripTitle(trip.title) : null,
    subtitle: subtitle,
    legendDays: options.day == null && days.length >= 2 && days.length <= 5
        ? days
        : const [],
    hasPhotos: view.stops.any((stop) => stop.photo != null),
    bounds: cameraBoundsFor(points),
  );
}
