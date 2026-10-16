import 'package:flutter/foundation.dart';

import 'segment.dart';
import 'stop.dart';

/// 여행의 동선: 장소와 그 사이 구간.
///
/// 장소는 (일차, 일차 안 순서)로 늘어선 하나의 줄이고, 일차를 넘어서도 이어진다.
/// 구간은 이 줄에서 바로 이웃한 두 장소 사이마다 하나씩 있다(저장소가 맞춘다).
@immutable
class TripRoute {
  TripRoute({
    Iterable<Stop> stops = const [],
    Iterable<Segment> segments = const [],
  }) : stops = List.unmodifiable(stops.toList()..sort(compareRouteOrder)),
       segments = List.unmodifiable(segments);

  /// 동선 순서다.
  final List<Stop> stops;

  final List<Segment> segments;

  late final Map<String, Stop> _stopsById = {
    for (final stop in stops) stop.id: stop,
  };

  /// 숙소가 아닌 장소에 일차마다 1부터 붙인 번호.
  late final Map<String, int> _numbers = () {
    final numbers = <String, int>{};
    final counts = <int, int>{};
    for (final stop in stops) {
      if (stop.isLodging) continue;
      numbers[stop.id] = counts[stop.day] = (counts[stop.day] ?? 0) + 1;
    }
    return numbers;
  }();

  Stop? stopById(String id) => _stopsById[id];

  /// 지도에 보여 줄 번호. 숙소가 아닌 장소에 일차마다 1부터 붙인다. 숙소는 null이다.
  ///
  /// 숙소를 끄고 켜도 번호가 바뀌지 않게, 보이는 장소가 아니라 동선 전체로 센다.
  int? numberOf(Stop stop) => _numbers[stop.id];

  /// [day]일차의 출발 숙소. 앞 일차의 마지막 장소가 숙소면 그 숙소다.
  ///
  /// 그날 밤 묵는 숙소를 그 일차 마지막에 한 번만 넣어도, 다음 날 보기는 그 숙소에서 출발한다.
  Stop? startLodgingOf(int day) {
    final before = stops.where((stop) => stop.day < day).lastOrNull;
    if (before == null || !before.isLodging) return null;
    final first = stops.where((stop) => stop.day == day).firstOrNull;
    if (first != null && first.isLodging && first.isSamePlaceAs(before)) {
      return null;
    }
    return before;
  }

  /// 지도에 보일 장소와 구간. [day]가 null이면 여행 전체다.
  ///
  /// - 일차 보기는 그 일차 장소 앞에 출발 숙소([startLodgingOf])를 붙인다.
  /// - [showLodging]이 false면 숙소를 뺀다. 숙소에 닿는 구간도 함께 빠진다.
  /// - 구간은 양 끝 장소가 모두 보일 때만 넣는다.
  RouteView view({int? day, bool showLodging = true}) {
    Iterable<Stop> visible = day == null
        ? stops
        : [?startLodgingOf(day), ...stops.where((stop) => stop.day == day)];
    if (!showLodging) visible = visible.where((stop) => !stop.isLodging);
    final visibleStops = List<Stop>.unmodifiable(visible);
    final ids = {for (final stop in visibleStops) stop.id};
    return RouteView(
      stops: visibleStops,
      segments: List.unmodifiable(
        segments.where(
          (s) => ids.contains(s.fromStopId) && ids.contains(s.toStopId),
        ),
      ),
    );
  }
}

/// 동선 중 지금 보이는 부분.
@immutable
class RouteView {
  const RouteView({required this.stops, required this.segments});

  /// 동선 순서다.
  final List<Stop> stops;

  final List<Segment> segments;
}

/// 동선 순서: 일차, 일차 안 순서.
int compareRouteOrder(Stop a, Stop b) {
  final byDay = a.day.compareTo(b.day);
  return byDay != 0 ? byDay : a.order.compareTo(b.order);
}
