import '../models/trip.dart';
import '../models/trip_route.dart';

/// 서버에서 받은 여행을 기억해 둔다. 지금은 메모리에만 둔다.
/// 2-2단계(오프라인)에서 기기에 저장하는 구현으로 바꾼다. 로그아웃하면 지운다.
class TripCache {
  /// 목록에 있는 여행 ID. 목록을 아직 받지 못했으면 null이다.
  List<String>? listIds;

  /// 목록이나 상세로 받은 여행.
  final trips = <String, Trip>{};

  /// 받은 동선.
  final routes = <String, TripRoute>{};

  /// 서버에 없다고 한 여행(지워졌거나 남의 것).
  final missing = <String>{};

  /// 목록을 받은 그대로 바꾼다.
  void putList(List<Trip> list) {
    listIds = [for (final trip in list) trip.id];
    for (final trip in list) {
      trips[trip.id] = trip;
      missing.remove(trip.id);
    }
  }

  void putTrip(Trip trip, {TripRoute? route}) {
    trips[trip.id] = trip;
    if (route != null) routes[trip.id] = route;
    missing.remove(trip.id);
    final ids = listIds;
    if (ids != null && !ids.contains(trip.id)) ids.add(trip.id);
  }

  void markMissing(String tripId) {
    trips.remove(tripId);
    routes.remove(tripId);
    listIds?.remove(tripId);
    missing.add(tripId);
  }

  /// 목록. 최근에 고친 여행이 앞이다.
  List<Trip>? get list {
    final ids = listIds;
    if (ids == null) return null;
    return List.unmodifiable(
      [for (final id in ids) ?trips[id]]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }

  /// [stopId] 장소가 있는 여행.
  String? tripOfStop(String stopId) {
    for (final MapEntry(key: tripId, value: route) in routes.entries) {
      if (route.stopById(stopId) != null) return tripId;
    }
    return null;
  }

  /// [segmentId] 구간이 있는 여행.
  String? tripOfSegment(String segmentId) {
    for (final MapEntry(key: tripId, value: route) in routes.entries) {
      if (route.segments.any((segment) => segment.id == segmentId)) {
        return tripId;
      }
    }
    return null;
  }
}
