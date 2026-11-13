import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/candidate.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trashed_trip.dart';
import '../models/trip.dart';
import 'trip_json.dart';

/// 여행·장소·구간·후보·휴지통 API(`/v1/trips`, `/v1/stops`, `/v1/segments`, `/v1/candidates`, `/v1/trash`).
///
/// 실패는 [ApiException]이다. 읽을 수 없는 응답은 [ApiFailure.server]로 바꾼다.
/// 동선을 바꾸는 요청(장소 넣기·옮기기·지우기, 동선에 넣기·후보로 빼기)은 여행과 새 동선(후보 포함) 전체를 돌려준다.
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

  /// 휴지통으로 옮긴다. 장소·구간도 함께 휴지통에 간다.
  Future<void> trashTrip(String tripId) => _client.delete('/trips/$tripId');

  /// 휴지통. 최근에 넣은 순서이고, 보관 기간이 끝난 여행은 빠져 있다.
  Future<List<TrashedTrip>> listTrash() => _read(
    _client.get('/trash'),
    (json) => switch (json) {
      final List<Object?> list => [
        for (final item in list) trashedTripFromJson(item),
      ],
      _ => throw const FormatException('휴지통 목록이 아닙니다'),
    },
  );

  /// 휴지통에서 꺼낸 여행. 고친 시각이 그대로라 목록의 원래 자리로 간다.
  Future<Trip> restoreTrip(String tripId) =>
      _read(_client.post('/trash/$tripId/restore'), tripFromJson);

  /// 휴지통의 여행을 장소·구간과 함께 영구 삭제한다.
  Future<void> deleteTripForever(String tripId) =>
      _client.delete('/trash/$tripId');

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

  /// 응답은 후보뿐이다. 동선은 바뀌지 않는다.
  Future<Candidate> addCandidate(Candidate candidate) => _read(
    _client.post(
      '/trips/${candidate.tripId}/candidates',
      data: createCandidateJson(candidate),
    ),
    candidateFromJson,
  );

  Future<Candidate> updateCandidate(Candidate candidate) => _read(
    _client.patch(
      '/candidates/${candidate.id}',
      data: updateCandidateJson(candidate),
    ),
    candidateFromJson,
  );

  Future<void> deleteCandidate(String candidateId) =>
      _client.delete('/candidates/$candidateId');

  /// 후보를 같은 ID의 장소로 [stop]의 일차·자리에 넣는다. 새 동선을 돌려준다.
  Future<TripDetail> promoteCandidate(Stop stop) => _read(
    _client.post(
      '/candidates/${stop.id}/stop',
      data: promoteCandidateJson(stop),
    ),
    tripDetailFromJson,
  );

  /// 장소를 같은 ID의 후보로 뺀다. 앞뒤 장소는 새로 이어진다. 새 동선을 돌려준다.
  Future<TripDetail> demoteStop(String stopId) =>
      _read(_client.post('/stops/$stopId/candidate'), tripDetailFromJson);

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
