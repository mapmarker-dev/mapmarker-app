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

  /// [day]일차의 출발 장소. 앞 일차의 마지막 장소다.
  ///
  /// - 그날 밤 묵는 숙소를 그 일차 마지막에 한 번만 넣어도, 다음 날 보기는 그 숙소에서 출발한다.
  /// - 숙소가 아닌 곳(공항, 야간 이동, 숙소를 아직 넣지 않음)에서 끝난 날도 다음 날 보기는 거기서 출발한다.
  ///   그래야 일차를 넘는 구간(그 장소 → 다음 날 첫 장소)이 다음 날 보기와 목록에 보여 이동 수단을 적을 수 있다.
  /// - 그날 첫 장소가 같은 자리면(같은 숙소를 다시 넣음) 같은 곳이 두 번 보이지 않게 없다.
  Stop? startOf(int day) {
    final before = stops.where((stop) => stop.day < day).lastOrNull;
    if (before == null) return null;
    final first = stops.where((stop) => stop.day == day).firstOrNull;
    if (first != null && first.isSamePlaceAs(before)) return null;
    return before;
  }

  /// 지도에 보일 장소와 구간. [day]가 null이면 여행 전체다.
  ///
  /// - 일차 보기는 그 일차 장소 앞에 출발 장소([startOf])를 붙인다.
  /// - [showLodging]이 false면 숙소를 뺀다. 숙소에 닿는 구간도 함께 빠진다.
  ///   그 대신 낮에 들른 숙소의 앞뒤는 [RouteView.vias]로 잇는다.
  /// - 구간은 양 끝 장소가 모두 보일 때만 넣는다.
  RouteView view({int? day, bool showLodging = true}) {
    final List<Stop> all = day == null
        ? stops
        : [?startOf(day), ...stops.where((stop) => stop.day == day)];
    final visibleStops = List<Stop>.unmodifiable(
      showLodging ? all : all.where((stop) => !stop.isLodging),
    );
    final ids = {for (final stop in visibleStops) stop.id};
    return RouteView(
      stops: visibleStops,
      segments: List.unmodifiable(
        segments.where(
          (s) => ids.contains(s.fromStopId) && ids.contains(s.toStopId),
        ),
      ),
      vias: showLodging ? const [] : List.unmodifiable(_viasOf(all)),
    );
  }

  /// 숙소를 끈 보기에서 숨긴 숙소를 건너 이을 쌍. [line]은 숙소를 끄기 전의 보이는 장소다(동선 순서).
  ///
  /// 보이는 두 장소 사이에 숙소만 끼어 있고, 그 숙소가 모두 뒤 장소와 같은 일차일 때(그날 낮에 들른 숙소)다.
  /// - 숨긴 숙소가 둘 이어져도 하나로 잇는다(숙소A > 숙소B).
  /// - 그날 밤 숙소를 거쳐 다음 날로 넘어가는 곳은 잇지 않는다. 하루가 끝나는 자리라서다.
  /// - 출발 숙소 → 첫 장소처럼 앞에 보이는 장소가 없으면, 그리고 앞뒤가 같은 자리면 잇지 않는다.
  static List<RouteVia> _viasOf(List<Stop> line) {
    final vias = <RouteVia>[];
    for (var i = 0; i < line.length; i++) {
      final from = line[i];
      if (from.isLodging) continue;
      var j = i + 1;
      while (j < line.length && line[j].isLodging) {
        j++;
      }
      if (j == i + 1 || j == line.length) continue;
      final to = line[j];
      final hidden = line.sublist(i + 1, j);
      if (hidden.every((stop) => stop.day == to.day) &&
          !from.isSamePlaceAs(to)) {
        vias.add(RouteVia(from: from, to: to));
      }
    }
    return vias;
  }
}

/// 동선 중 지금 보이는 부분.
@immutable
class RouteView {
  const RouteView({
    required this.stops,
    required this.segments,
    this.vias = const [],
  });

  /// 동선 순서다.
  final List<Stop> stops;

  final List<Segment> segments;

  /// 숙소를 끈 보기에서 낮에 들른 숙소를 건너 잇는 쌍. 동선 순서다. 숙소를 켜면 비어 있다.
  final List<RouteVia> vias;
}

/// 숙소를 끈 보기에서 숨긴 숙소를 건너 바로 잇는 두 장소. 실제 구간이 아니라 "숙소를 거침" 표시다.
///
/// 숙소 자리를 거쳐 이으면 숨긴 숙소 위치가 꺾인 곳으로 드러나고, 보통 선으로 바로 이으면 가지 않은 길처럼 보여서
/// 지도와 시트는 이것을 흐린 선으로 그린다. 구간이 아니라서 이동 수단·곡률이 없고 고칠 수 없다.
@immutable
class RouteVia {
  const RouteVia({required this.from, required this.to});

  final Stop from;
  final Stop to;

  /// 지도 선 ID. 장소 ID(UUID)·구간 ID와 겹치지 않는다.
  String get id => 'via:${from.id}>${to.id}';

  @override
  bool operator ==(Object other) =>
      other is RouteVia && other.from.id == from.id && other.to.id == to.id;

  @override
  int get hashCode => Object.hash(from.id, to.id);
}

/// 동선 순서: 일차, 일차 안 순서.
int compareRouteOrder(Stop a, Stop b) {
  final byDay = a.day.compareTo(b.day);
  return byDay != 0 ? byDay : a.order.compareTo(b.order);
}
