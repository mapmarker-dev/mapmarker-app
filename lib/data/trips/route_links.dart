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
