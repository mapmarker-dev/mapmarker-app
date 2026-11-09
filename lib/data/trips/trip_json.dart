import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../models/map_provider_type.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trip.dart';
import '../models/trip_route.dart';

/// 서버 JSON과 앱 모델 사이의 변환. 필드 이름과 enum 값은 서버 DTO와 같다(`mapmarker-server/src/trips/dto/`).
///
/// 읽기는 모양이 틀리면 [FormatException]을 던진다. 2-2단계에서 기기에 저장한 여행을 읽을 때도 쓴다.
/// 쓰기는 서버가 받는 필드만 담는다. 서버는 DTO에 없는 필드를 400으로 거절한다.

/// 여행 하나와 그 동선.
typedef TripDetail = ({Trip trip, TripRoute route});

Trip tripFromJson(Object? json) {
  final map = _map(json);
  final nights = _field<int>(map, 'nights');
  final dates = switch (map['dates']) {
    null => null,
    final Object value => _datesFromJson(value),
  };
  if (dates != null && dates.nights != nights) {
    throw FormatException('기간과 박 수가 다릅니다', map);
  }
  return Trip(
    id: _field(map, 'id'),
    title: _field(map, 'title'),
    region: _field(map, 'region'),
    nights: nights,
    season: _enum(Season.values, map, 'season'),
    dates: dates,
    phaseOverride: _optionalEnum(TripPhase.values, map, 'phaseOverride'),
    mapProvider: _optionalEnum(MapProviderType.values, map, 'mapProvider'),
    origin: _enum(TripOrigin.values, map, 'origin'),
    copiedFromTripId: _field(map, 'copiedFromTripId'),
    shareId: _field(map, 'shareId'),
    createdAt: _instant(map, 'createdAt'),
    updatedAt: _instant(map, 'updatedAt'),
  );
}

/// 여행 만들기. 만든 방법·복사 원본·공유 ID·시각은 서버가 정한다.
Map<String, Object?> createTripJson(Trip trip) => {
  'id': trip.id,
  ...updateTripJson(trip),
};

/// 여행 고치기. 모든 필드를 보내고, 지운 기간·상태·지도는 null로 보낸다.
Map<String, Object?> updateTripJson(Trip trip) => {
  'title': trip.title,
  'region': trip.region,
  'nights': trip.nights,
  'season': trip.season.name,
  'dates': switch (trip.dates) {
    null => null,
    final dates => {'start': '${dates.start}', 'end': '${dates.end}'},
  },
  'phaseOverride': trip.phaseOverride?.name,
  'mapProvider': trip.mapProvider?.name,
};

Stop stopFromJson(Object? json) {
  final map = _map(json);
  final day = _field<int>(map, 'day');
  final order = _field<int>(map, 'order');
  if (day < 1 || order < 0) throw FormatException('일차나 순서가 틀립니다', map);
  return Stop(
    id: _field(map, 'id'),
    tripId: _field(map, 'tripId'),
    day: day,
    order: order,
    latitude: _field<num>(map, 'latitude').toDouble(),
    longitude: _field<num>(map, 'longitude').toDouble(),
    name: _field(map, 'name'),
    kind: _enum(StopKind.values, map, 'kind'),
    description: _field(map, 'description'),
    memo: _field(map, 'memo'),
    plannedTime: switch (_field<String?>(map, 'plannedTime')) {
      null => null,
      final text => LocalTime.parse(text),
    },
    visited: _field(map, 'visited'),
    visitedAt: _optionalInstant(map, 'visitedAt'),
    timeZone: _field(map, 'timeZone'),
    placeProvider: _optionalEnum(MapProviderType.values, map, 'placeProvider'),
    placeId: _field(map, 'placeId'),
  );
}

/// 장소 넣기. 방문 체크는 1-4단계에서 보낸다.
Map<String, Object?> createStopJson(Stop stop) => {
  'id': stop.id,
  'day': stop.day,
  'order': stop.order,
  ...updateStopJson(stop),
};

/// 장소 고치기. 일차·순서는 옮기기로 바꾼다. 지운 예정 시각·장소 서비스 ID는 null로 보낸다.
Map<String, Object?> updateStopJson(Stop stop) => {
  'latitude': stop.latitude,
  'longitude': stop.longitude,
  'name': stop.name,
  'kind': stop.kind.name,
  'description': stop.description,
  'memo': stop.memo,
  'plannedTime': stop.plannedTime?.toString(),
  'timeZone': stop.timeZone,
  'placeProvider': stop.placeProvider?.name,
  'placeId': stop.placeId,
};

Segment segmentFromJson(Object? json) {
  final map = _map(json);
  return Segment(
    id: _field(map, 'id'),
    tripId: _field(map, 'tripId'),
    fromStopId: _field(map, 'fromStopId'),
    toStopId: _field(map, 'toStopId'),
    legs: List.unmodifiable(
      _field<List<Object?>>(map, 'legs').map(_legFromJson),
    ),
    curvature: _field<num>(map, 'curvature').toDouble(),
    type: _enum(SegmentType.values, map, 'type'),
  );
}

/// 구간 고치기. 어느 장소를 잇는지는 서버가 정한다.
Map<String, Object?> updateSegmentJson(Segment segment) => {
  'legs': [for (final leg in segment.legs) _legToJson(leg)],
  'curvature': segment.curvature,
  'type': segment.type.name,
};

TripDetail tripDetailFromJson(Object? json) {
  final map = _map(json);
  return (
    trip: tripFromJson(map['trip']),
    route: TripRoute(
      stops: _field<List<Object?>>(map, 'stops').map(stopFromJson),
      segments: _field<List<Object?>>(map, 'segments').map(segmentFromJson),
    ),
  );
}

TransportLeg _legFromJson(Object? json) {
  final map = _map(json);
  final minutes = _field<int?>(map, 'durationMinutes');
  return TransportLeg(
    _enum(TransportMode.values, map, 'mode'),
    stopCount: _field(map, 'stopCount'),
    duration: minutes == null ? null : Duration(minutes: minutes),
  );
}

/// 비운 정류장 수·시간은 빼고 보낸다. 서버는 이 둘에 null을 받지 않는다.
Map<String, Object?> _legToJson(TransportLeg leg) => {
  'mode': leg.mode.name,
  if (leg.stopCount case final count?) 'stopCount': count,
  if (leg.duration case final duration?) 'durationMinutes': duration.inMinutes,
};

TripDates _datesFromJson(Object json) {
  final map = _map(json);
  final start = LocalDate.parse(_field(map, 'start'));
  final end = LocalDate.parse(_field(map, 'end'));
  if (end.isBefore(start)) throw FormatException('종료일이 시작일보다 앞입니다', map);
  return TripDates(start, end);
}

Map<String, Object?> _map(Object? json) => switch (json) {
  final Map<String, Object?> map => map,
  _ => throw FormatException('JSON 객체가 아닙니다', json),
};

/// [key]의 값. 타입이 [T]가 아니면 [FormatException]이다. [T]가 nullable이면 null도 받는다.
T _field<T>(Map<String, Object?> map, String key) => switch (map[key]) {
  final T value => value,
  final value => throw FormatException('$key: ${value.runtimeType}', map),
};

T _enum<T extends Enum>(List<T> values, Map<String, Object?> map, String key) =>
    _optionalEnum(values, map, key) ??
    (throw FormatException('$key: 값이 없습니다', map));

T? _optionalEnum<T extends Enum>(
  List<T> values,
  Map<String, Object?> map,
  String key,
) {
  final name = _field<String?>(map, key);
  if (name == null) return null;
  return values.asNameMap()[name] ??
      (throw FormatException('$key: 모르는 값', name));
}

/// ISO 8601 순간. UTC로 둔다.
DateTime _instant(Map<String, Object?> map, String key) =>
    _optionalInstant(map, key) ?? (throw FormatException('$key: 값이 없습니다', map));

DateTime? _optionalInstant(Map<String, Object?> map, String key) =>
    switch (_field<String?>(map, key)) {
      null => null,
      final text => DateTime.parse(text).toUtc(),
    };
