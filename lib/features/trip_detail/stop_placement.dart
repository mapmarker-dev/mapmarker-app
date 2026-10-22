import 'package:flutter/foundation.dart';

import '../../data/models/segment.dart';
import '../../data/models/stop.dart';
import '../../data/models/trip_route.dart';
import '../../data/trips/route_links.dart';
import 'stop_draft.dart';

/// 새로 넣거나 다른 일차로 옮긴 장소가 들어갈 기본 일차 안 순서([Stop.order]).
/// 장소 입력 화면의 "넣을 자리" 칸이 처음 고르고 있는 자리다.
///
/// 그 일차의 맨 뒤다. 다만 마지막이 숙소면 숙소 바로 앞이다.
/// 숙소는 그날 밤 묵는 곳이라 일차 마지막에 남아야 다음 날 보기가 그 숙소에서 출발한다.
/// 넣는 장소가 숙소면 맨 뒤다.
///
/// [dayStops]는 넣을 일차의 장소다(동선 순서, 옮기는 장소는 빼고).
int insertionOrder(List<Stop> dayStops, StopKind kind) {
  if (kind == StopKind.lodging) return dayStops.length;
  if (dayStops.lastOrNull?.isLodging ?? false) return dayStops.length - 1;
  return dayStops.length;
}

/// 장소 입력 화면의 "넣을 자리" 칸에서 고를 수 있는 자리 하나. 그 일차 장소 사이의 빈자리다.
@immutable
class InsertionSlot {
  const InsertionSlot({required this.order, this.before, this.after});

  /// 넣을 일차 안 순서([Stop.order]).
  final int order;

  /// 바로 앞 장소. 맨 앞이면 null이다.
  final Stop? before;

  /// 바로 뒤 장소. 맨 뒤면 null이다.
  final Stop? after;
}

/// [kind] 장소를 넣을 수 있는 [dayStops] 사이의 빈자리. 맨 앞부터 동선 순서다.
///
/// - 출발 장소 앞은 없다. 출발 장소는 앞 일차의 마지막 장소라서, 그 앞에 넣는 것은 앞 일차에 넣는 것이다.
/// - 숙소를 꺼서 지도·시트에 보이지 않는 숙소도 넣는다. 숙소 앞인지 뒤인지에 따라 다음 날 출발이 달라져서,
///   입력 화면은 보기 필터가 아니라 실제 순서를 보여 준다.
/// - 그날 밤 숙소(마지막이 숙소일 때 그 숙소) 뒤는 숙소가 아닌 장소에게는 없다. 거기 넣으면 그 숙소가
///   낮에 들른 숙소가 되어, 숙소를 끈 보기에서 앞뒤 선이 끊기고 다음 날이 그 숙소에서 출발하지 않는다.
///   숙소를 옮기는 날(숙소A > 장소 > 숙소B)처럼 숙소는 그 뒤에 넣을 수 있다.
///
/// [dayStops]는 넣을 일차의 장소다(동선 순서, 옮기는 장소는 빼고).
List<InsertionSlot> insertionSlots(List<Stop> dayStops, StopKind kind) {
  final endsWithLodging = dayStops.lastOrNull?.isLodging ?? false;
  final last = endsWithLodging && kind != StopKind.lodging
      ? dayStops.length - 1
      : dayStops.length;
  return [
    for (var i = 0; i <= last; i++)
      InsertionSlot(
        order: i,
        before: i > 0 ? dayStops[i - 1] : null,
        after: i < dayStops.length ? dayStops[i] : null,
      ),
  ];
}

/// [day]일차의 장소. 동선 순서이고, 옮기는 장소([stopId])는 뺀다.
List<Stop> dayStopsOf(TripRoute route, int day, {String? stopId}) => [
  for (final stop in route.stops)
    if (stop.day == day && stop.id != stopId) stop,
];

/// 입력 화면 값으로 장소가 들어갈 일차 안 순서. "넣을 자리" 칸도 이 자리를 고르고 있다.
///
/// 넣을 자리를 고르지 않았거나, 고른 자리가 지금 종류로는 고를 수 없는 자리면 기본 자리([insertionOrder])다.
/// 예: 숙소로 그날 밤 숙소 뒤를 고른 뒤 종류를 음식으로 바꿨다.
///
/// [stopId]는 편집해서 옮기는 장소다. 새 장소면 null이다.
int placedOrder(TripRoute route, StopDraft draft, {String? stopId}) {
  final dayStops = dayStopsOf(route, draft.day, stopId: stopId);
  final chosen = draft.slotOrder;
  if (chosen != null &&
      insertionSlots(dayStops, draft.kind).any((s) => s.order == chosen)) {
    return chosen;
  }
  return insertionOrder(dayStops, draft.kind);
}

/// [segments] 중 이동 수단을 적어 둔 구간. 사라질 때 알릴 것은 이것뿐이다(미정 구간은 잃을 것이 없다).
List<Segment> withTransport(Iterable<Segment> segments) => [
  for (final segment in segments)
    if (segment.legs.isNotEmpty) segment,
];

/// 입력 화면 값대로 새 장소를 넣거나([stop]이 null) [stop]을 옮기면 지워지는 이동 수단.
/// "넣을 자리" 칸 아래에 미리 보여 준다.
///
/// 편집에서 일차를 바꾸지 않았으면 없다. 같은 일차 안 순서는 입력 화면이 아니라 끌어서 바꾼다.
List<Segment> transportsDroppedByDraft(
  TripRoute route,
  StopDraft draft, {
  Stop? stop,
}) {
  if (stop != null && stop.day == draft.day) return const [];
  final order = placedOrder(route, draft, stopId: stop?.id);
  return withTransport(
    stop == null
        ? segmentsDroppedByInsert(
            stops: route.stops,
            segments: route.segments,
            day: draft.day,
            order: order,
          )
        : segmentsDroppedByMove(
            stops: route.stops,
            segments: route.segments,
            stopId: stop.id,
            day: draft.day,
            order: order,
          ),
  );
}

/// 장소를 추가할 때 처음 고를 일차.
///
/// 일차 보기면 그 일차다. 전체 보기면 장소가 있는 마지막 일차이고, 장소가 없으면 1일차다.
/// 계획은 보통 앞에서부터 채워 가서, 마지막으로 채우던 일차에 이어 넣을 가능성이 크다.
int defaultDayForNewStop(TripRoute route, {int? viewDay}) =>
    viewDay ?? route.stops.lastOrNull?.day ?? 1;

/// 연박: 전날 밤 숙소(또는 그날 들른 숙소)를 [day]일차 밤에 묵는 숙소로 복사한다. 그 일차 맨 뒤에 넣을 장소다.
///
/// 같은 자리라 지도에서는 마커 하나로 합쳐진다. 메모(체크인 시각, 현관 비밀번호 등)도 두 밤에 다 필요해서 복사한다.
/// 예정 시각과 방문 기록은 그날 것이라 복사하지 않는다.
Stop stayAnotherNight(
  Stop lodging, {
  required String id,
  required int day,
  required int order,
}) => Stop(
  id: id,
  tripId: lodging.tripId,
  latitude: lodging.latitude,
  longitude: lodging.longitude,
  name: lodging.name,
  kind: lodging.kind,
  day: day,
  order: order,
  description: lodging.description,
  memo: lodging.memo,
  timeZone: lodging.timeZone,
  placeProvider: lodging.placeProvider,
  placeId: lodging.placeId,
);
