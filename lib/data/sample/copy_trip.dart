import '../api/api_exception.dart';
import '../models/new_id.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trip.dart';
import '../models/trip_route.dart';
import '../trips/trip_repository.dart';
import 'jeju_sample.dart';

/// 샘플 여행을 사용자의 새 여행으로 복사한다([SampleTrip]은 서버에 없다). 날짜는 미정 그대로다.
///
/// 샘플을 숨기는 것은 부른 쪽이 한다(복사가 끝난 뒤에).
Future<Trip> copySample(
  TripRepository repository,
  SampleTrip sample, {
  String Function() createId = newId,
}) => copyTrip(
  repository,
  trip: sample.trip,
  stops: sample.route.stops,
  segments: sample.route.segments,
  createId: createId,
);

/// [trip]과 그 장소를 저장소의 일반 메서드(여행 만들기, 장소 넣기, 구간 고치기)로 새 ID로 넣는다.
/// 서버 저장소에도 그대로 들어간다.
///
/// 구간은 저장소가 장소 사이에 만들고 ID도 저장소(서버)가 정한다.
/// 그래서 [segments] 중 이동 수단이나 곡률이 있는 것만, 잇는 두 장소로 찾아 고친다.
///
/// 중간에 실패하면 반쯤 만든 여행을 한 번 지워 보고(지우지 못해도 그만둔다) 던진다.
Future<Trip> copyTrip(
  TripRepository repository, {
  required Trip trip,
  required List<Stop> stops,
  required List<Segment> segments,
  String Function() createId = newId,
}) async {
  final saved = await repository.createTrip(
    Trip(
      id: createId(),
      title: trip.title,
      region: trip.region,
      nights: trip.nights,
      season: trip.season,
      dates: trip.dates,
      createdAt: trip.createdAt,
      updatedAt: trip.updatedAt,
    ),
  );
  try {
    final ids = <String, String>{};
    // 동선 순서로 하나씩 넣는다. 각 장소의 순서가 곧 넣을 자리다.
    for (final stop in [...stops]..sort(compareRouteOrder)) {
      final id = ids[stop.id] = createId();
      await repository.addStop(_copyOf(stop, id: id, tripId: saved.id));
    }
    final wanted = [
      for (final segment in segments)
        if (segment.legs.isNotEmpty || segment.curvature != 0) segment,
    ];
    if (wanted.isEmpty) return saved;
    final route = await repository.watchRoute(saved.id).first;
    for (final segment in wanted) {
      final made = route.segments.where(
        (s) =>
            s.fromStopId == ids[segment.fromStopId] &&
            s.toStopId == ids[segment.toStopId],
      );
      if (made.isEmpty) continue;
      await repository.updateSegment(
        made.single.copyWith(legs: segment.legs, curvature: segment.curvature),
      );
    }
    return saved;
  } on Object {
    try {
      await repository.deleteTrip(saved.id);
    } on ApiException {
      // 반쯤 만든 여행이 목록에 남는다. 사용자가 지울 수 있다.
    }
    rethrow;
  }
}

Stop _copyOf(Stop stop, {required String id, required String tripId}) => Stop(
  id: id,
  tripId: tripId,
  latitude: stop.latitude,
  longitude: stop.longitude,
  name: stop.name,
  kind: stop.kind,
  day: stop.day,
  order: stop.order,
  description: stop.description,
  memo: stop.memo,
  plannedTime: stop.plannedTime,
  timeZone: stop.timeZone,
  placeProvider: stop.placeProvider,
  placeId: stop.placeId,
);
