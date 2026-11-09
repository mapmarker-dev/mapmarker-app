import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trip.dart';
import 'trip_json.dart';

/// 여행·장소·구간 API(`/v1/trips`, `/v1/stops`, `/v1/segments`).
///
/// 실패는 [ApiException]이다. 읽을 수 없는 응답은 [ApiFailure.server]로 바꾼다.
/// 동선을 바꾸는 요청(장소 넣기·옮기기·지우기)은 여행과 새 동선 전체를 돌려준다.
class TripApi {
  const TripApi(this._client);

  final ApiClient _client;

  /// 최근에 고친 순서.
  Future<List<Trip>> listTrips() => _read(
    _client.get('/trips'),
    (json) => switch (json) {
      final List<Object?> list => [for (final item in list) tripFromJson(item)],
      _ => throw const FormatException('여행 목록이 아닙니다'),
    },
  );

  Future<Trip> createTrip(Trip trip) =>
      _read(_client.post('/trips', data: createTripJson(trip)), tripFromJson);

  Future<TripDetail> getTrip(String tripId) =>
      _read(_client.get('/trips/$tripId'), tripDetailFromJson);

  Future<Trip> updateTrip(Trip trip) => _read(
    _client.patch('/trips/${trip.id}', data: updateTripJson(trip)),
    tripFromJson,
  );

  /// 장소·구간도 함께 지운다.
  Future<void> deleteTrip(String tripId) => _client.delete('/trips/$tripId');

  Future<TripDetail> addStop(Stop stop) => _read(
    _client.post('/trips/${stop.tripId}/stops', data: createStopJson(stop)),
    tripDetailFromJson,
  );

  /// 응답은 장소뿐이다. 여행의 고친 시각은 오지 않는다.
  Future<Stop> updateStop(Stop stop) => _read(
    _client.patch('/stops/${stop.id}', data: updateStopJson(stop)),
    stopFromJson,
  );

  Future<TripDetail> moveStop(
    String stopId, {
    required int day,
    required int order,
  }) => _read(
    _client.put('/stops/$stopId/position', data: {'day': day, 'order': order}),
    tripDetailFromJson,
  );

  Future<TripDetail> deleteStop(String stopId) =>
      _read(_client.delete('/stops/$stopId'), tripDetailFromJson);

  /// 응답은 구간뿐이다. 여행의 고친 시각은 오지 않는다.
  Future<Segment> updateSegment(Segment segment) => _read(
    _client.patch('/segments/${segment.id}', data: updateSegmentJson(segment)),
    segmentFromJson,
  );

  Future<T> _read<T>(
    Future<Object?> response,
    T Function(Object? json) parse,
  ) async {
    final json = await response;
    try {
      return parse(json);
    } on FormatException {
      throw const ApiException(ApiFailure.server);
    }
  }
}

final tripApiProvider = Provider<TripApi>(
  (ref) => TripApi(ref.watch(apiClientProvider)),
);
