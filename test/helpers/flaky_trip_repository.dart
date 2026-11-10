import 'dart:async';

import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/data/trips/trip_repository.dart';

/// 서버 저장소처럼 실패할 수 있는 저장소. 실패하지 않을 때는 [inner]가 처리한다.
/// 화면이 실패를 어떻게 알리는지 볼 때 쓴다(서버 저장소의 동작은 그 저장소의 테스트가 본다).
class FlakyTripRepository implements TripRepository {
  FlakyTripRepository(this.inner);

  final MemoryTripRepository inner;

  /// 처음 불러오기(스트림)가 이 실패로 끝난다.
  ApiFailure? failLoads;

  /// 쓰기가 이 실패로 끝난다.
  ApiFailure? failWrites;

  /// 있으면 쓰기가 이것이 끝날 때까지 기다린다. 저장을 기다리는 동안의 화면을 볼 때 쓴다.
  Completer<void>? holdWrites;

  /// 다시 받기(당겨서 새로고침)가 이 실패로 끝난다.
  ApiFailure? failRefresh;

  /// 다시 받은 횟수.
  int refreshes = 0;

  /// 앱으로 돌아와 다시 받은 횟수.
  int watchedRefreshes = 0;

  Stream<T> _load<T>(Stream<T> Function() watch) => switch (failLoads) {
    final failure? => Stream.error(ApiException(failure)),
    null => watch(),
  };

  Future<T> _write<T>(Future<T> Function() write) async {
    if (holdWrites case final hold?) await hold.future;
    if (failWrites case final failure?) throw ApiException(failure);
    return write();
  }

  @override
  Stream<List<Trip>> watchTrips() => _load(inner.watchTrips);

  @override
  Stream<Trip?> watchTrip(String id) => _load(() => inner.watchTrip(id));

  @override
  Stream<TripRoute> watchRoute(String tripId) =>
      _load(() => inner.watchRoute(tripId));

  @override
  Future<Trip> createTrip(Trip trip) => _write(() => inner.createTrip(trip));

  @override
  Future<Trip> updateTrip(Trip trip) => _write(() => inner.updateTrip(trip));

  @override
  Future<void> deleteTrip(String tripId) =>
      _write(() => inner.deleteTrip(tripId));

  @override
  Future<Stop> addStop(Stop stop) => _write(() => inner.addStop(stop));

  @override
  Future<Stop> updateStop(Stop stop) => _write(() => inner.updateStop(stop));

  @override
  Future<Stop> moveStop(
    String stopId, {
    required int day,
    required int order,
  }) => _write(() => inner.moveStop(stopId, day: day, order: order));

  @override
  Future<void> deleteStop(String stopId) =>
      _write(() => inner.deleteStop(stopId));

  @override
  Future<Segment> updateSegment(Segment segment) =>
      _write(() => inner.updateSegment(segment));

  @override
  Future<void> refreshTrips() async {
    refreshes++;
    if (failRefresh case final failure?) throw ApiException(failure);
  }

  @override
  Future<void> refreshTrip(String tripId) => refreshTrips();

  @override
  void refreshWatched() => watchedRefreshes++;
}
