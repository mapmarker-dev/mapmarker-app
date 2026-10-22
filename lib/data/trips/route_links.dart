import '../models/new_id.dart';
import '../models/segment.dart';
import '../models/stop.dart';

/// 동선 순서로 놓인 [stops]에서 이웃한 두 장소 사이마다 구간 하나를 둔다.
///
/// 장소를 넣고 빼고 옮길 때마다 저장소가 부른다. 사용자가 선을 따로 잇지 않아도 되고,
/// 화면·이미지·서버는 "구간 = 선"으로 다루면 된다.
/// - 이미 있는 이웃 쌍의 구간은 그대로 둔다. 이동 수단과 곡률이 남는다.
/// - 새로 이웃한 쌍에는 빈 구간(이동 수단 미정, 직선)을 만든다.
/// - 더는 이웃하지 않는 쌍의 구간은 버린다. A와 B 사이에 장소를 넣으면 A→B의 이동 수단은 사라진다.
/// - 일차를 넘어서도 잇는다. 1일차 마지막 숙소에서 2일차 첫 장소로 가는 길도 구간이다.
List<Segment> linkStops({
  required String tripId,
  required List<Stop> stops,
  required Iterable<Segment> existing,
  String Function() createId = newId,
}) {
  final byPair = {
    for (final segment in existing)
      (segment.fromStopId, segment.toStopId): segment,
  };
  return [
    for (var i = 0; i + 1 < stops.length; i++)
      byPair[(stops[i].id, stops[i + 1].id)] ??
          Segment(
            id: createId(),
            tripId: tripId,
            fromStopId: stops[i].id,
            toStopId: stops[i + 1].id,
          ),
  ];
}

/// [stopId] 장소를 [day]일차의 [order] 자리로 옮기면 사라지는 구간. 이웃이 바뀐 쌍의 구간이다.
///
/// 옮긴 장소로 오는 구간과 거기서 나가는 구간, 그리고 새로 끼어드는 자리의 구간(A와 B 사이에 넣으면 A→B)이다.
/// 화면이 옮기기 전에 이동 수단이 지워지는지 묻는 데 쓴다.
///
/// [stops]는 동선 순서다. 옮기는 방법은 저장소의 `moveStop`과 같다:
/// 그 일차의 다른 장소들 사이 [order] 자리에 넣고, 장소 수보다 크면 맨 뒤에 넣는다.
List<Segment> segmentsDroppedByMove({
  required List<Stop> stops,
  required Iterable<Segment> segments,
  required String stopId,
  required int day,
  required int order,
}) {
  if (!stops.any((stop) => stop.id == stopId)) return const [];
  final others = [
    for (final stop in stops)
      if (stop.id != stopId) stop.id,
  ];
  final at = _placeIndex(stops, others, day, order);
  return _droppedBy([...others]..insert(at, stopId), segments);
}

/// 새 장소를 [day]일차의 [order] 자리에 넣으면 사라지는 구간. 끼어드는 자리의 구간(A와 B 사이에 넣으면 A→B)이다.
///
/// 넣는 방법은 저장소의 `addStop`과 같다. 화면이 넣기 전에 이동 수단이 지워지는지 알리는 데 쓴다.
List<Segment> segmentsDroppedByInsert({
  required List<Stop> stops,
  required Iterable<Segment> segments,
  required int day,
  required int order,
}) {
  final ids = [for (final stop in stops) stop.id];
  final at = _placeIndex(stops, ids, day, order);
  return _droppedBy([...ids]..insert(at, null), segments);
}

/// [day]일차의 [order] 자리가 동선 [ids]의 몇 번째인지. 장소 수보다 크면 그 일차 맨 뒤다.
int _placeIndex(List<Stop> stops, List<String> ids, int day, int order) {
  final days = {for (final stop in stops) stop.id: stop.day};
  final dayIds = [
    for (final id in ids)
      if (days[id] == day) id,
  ];
  final index = order < 0 ? 0 : order;
  if (index < dayIds.length) return ids.indexOf(dayIds[index]);
  final after = ids.indexWhere((id) => days[id]! > day);
  return after == -1 ? ids.length : after;
}

/// 장소가 [next] 순서로 늘어서면 더는 이웃하지 않는 쌍의 구간. null은 새 장소다.
List<Segment> _droppedBy(List<String?> next, Iterable<Segment> segments) {
  final pairs = {
    for (var i = 0; i + 1 < next.length; i++) (next[i], next[i + 1]),
  };
  return [
    for (final segment in segments)
      if (!pairs.contains((segment.fromStopId, segment.toStopId))) segment,
  ];
}
