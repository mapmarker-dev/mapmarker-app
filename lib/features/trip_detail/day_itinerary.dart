import 'package:flutter/foundation.dart';

import '../../data/models/segment.dart';
import '../../data/models/stop.dart';
import '../../data/models/trip_route.dart';

/// 일차 동선 시트에 늘어놓을 그날의 동선. 지도와 같은 것을 보여 주려고 [RouteView]로 만든다.
@immutable
class DayItinerary {
  const DayItinerary({required this.day, this.start, this.stops = const []});

  /// [view]는 [day]일차 보기여야 한다(`route.view(day: day, ...)`).
  /// 숙소를 끈 보기면 숙소와 숙소에 닿는 구간이 빠진다.
  factory DayItinerary.of(TripRoute route, RouteView view, int day) {
    final arrivals = {
      for (final segment in view.segments) segment.toStopId: segment,
    };
    Stop? start;
    final stops = <ItineraryStop>[];
    for (final stop in view.stops) {
      if (stop.day != day) {
        start = stop;
        continue;
      }
      stops.add(
        ItineraryStop(
          stop: stop,
          number: route.numberOf(stop),
          arrival: arrivals[stop.id],
        ),
      );
    }
    return DayItinerary(
      day: day,
      start: start,
      stops: List.unmodifiable(stops),
    );
  }

  final int day;

  /// 출발 숙소. 앞 일차의 마지막 장소라서 이 일차에서 옮기거나 지우지 않는다.
  final Stop? start;

  /// 이 일차의 장소. 동선 순서다.
  final List<ItineraryStop> stops;

  /// 화면에 보이는 장소의 ID. 출발 숙소부터 동선 순서다.
  List<String> get stopIds => [?start?.id, for (final s in stops) s.stop.id];

  /// "오늘 밤도 여기서 묵기"로 이 일차 밤에 다시 넣을 수 있는 전날 밤 숙소.
  /// 출발 숙소가 있고, 이 일차 마지막이 숙소가 아닐 때(이 일차의 밤 숙소를 아직 넣지 않았을 때)다.
  Stop? get lodgingToStayAgain {
    if (stops.lastOrNull?.stop.isLodging ?? false) return null;
    return start;
  }

  /// [id] 장소나 구간이 이 목록에 있는지.
  bool contains(String id) =>
      start?.id == id ||
      stops.any((s) => s.stop.id == id || s.arrival?.id == id);
}

/// 일차 동선 시트의 장소 한 줄과, 그 위에 붙는 앞 장소에서 오는 구간.
@immutable
class ItineraryStop {
  const ItineraryStop({required this.stop, this.number, this.arrival});

  final Stop stop;

  /// 지도 마커와 같은 번호. 숙소는 null이다.
  final int? number;

  /// 앞 장소에서 이 장소로 오는 구간. 그날 첫 장소이고 출발 숙소가 없거나, 앞 장소가 숨었으면 null이다.
  final Segment? arrival;
}

/// 시트에서 장소를 끌어 옮긴 뒤 저장소에 넘길 일차 안 순서([Stop.order]).
///
/// [visibleIds]는 옮기기 전 시트의 장소 순서다(출발 숙소 제외).
/// [dayStops]는 그 일차의 모든 장소다. 숙소를 끄면 시트에 보이지 않는 숙소가 섞여 있어서,
/// 옮긴 장소를 시트에서 바로 앞에 놓인 장소 뒤에 넣는다. 맨 앞으로 옮기면 바로 뒤 장소 앞에 넣는다.
///
/// [oldIndex]는 옮기기 전 자리, [newIndex]는 옮긴 뒤 자리다(`onReorderItem`의 값).
int reorderedStopOrder({
  required List<String> visibleIds,
  required List<Stop> dayStops,
  required int oldIndex,
  required int newIndex,
}) {
  final moved = visibleIds[oldIndex];
  final visible = [...visibleIds]..removeAt(oldIndex);
  final target = newIndex;
  visible.insert(target, moved);

  final others = [
    for (final stop in dayStops)
      if (stop.id != moved) stop.id,
  ];
  if (target > 0) return others.indexOf(visible[target - 1]) + 1;
  if (visible.length > 1) return others.indexOf(visible[1]);
  return 0;
}
