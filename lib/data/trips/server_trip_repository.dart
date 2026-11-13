import 'dart:async';

import '../api/api_exception.dart';
import '../models/candidate.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trashed_trip.dart';
import '../models/trip.dart';
import '../models/trip_route.dart';
import 'trip_api.dart';
import 'trip_cache.dart';
import 'trip_json.dart';
import 'trip_repository.dart';

/// 서버에 저장하는 여행 저장소. 사용자 한 명의 것이다. 사용자가 바뀌면 새로 만든다.
///
/// - 읽기: 기억한 값을 먼저 내고, 화면이 보기 시작할 때(스트림을 들을 때) 뒤에서 다시 받는다.
///   처음 받다가 실패하면 스트림에 오류를 내고, 다시 받다가 실패하면 보이던 값을 그대로 둔다.
/// - 쓰기: 서버 응답을 받은 뒤에 반영한다(낙관적 갱신 없음). 구간 ID를 서버가 만들기 때문이다.
///   여행마다 하나씩 차례로 보낸다. 쓰기와 시간이 겹친 읽기 결과는 버린다(쓰기 전 값일 수 있다).
/// - 쓰기 실패: [ApiException]을 던지고 그 여행을 다시 받는다. 응답만 잃었을 수 있어서다.
///   로그인이 끊긴 실패(401)는 다시 받지 않는다. 자동으로 다시 보내지는 않는다.
class ServerTripRepository implements TripRepository {
  ServerTripRepository({
    required this._api,
    this.clock = DateTime.now,
    TripCache? cache,
  }) : _cache = cache ?? TripCache();

  final TripApi _api;
  final TripCache _cache;

  /// 장소·구간 고치기 응답에는 여행이 없어서, 여행의 고친 시각을 이 시각으로 맞춘다.
  /// 다음에 여행을 받으면 서버 값으로 바뀐다.
  final DateTime Function() clock;

  final _changes = StreamController<void>.broadcast();

  /// 목록을 아직 받지 못했고 마지막 시도가 실패했다.
  ApiException? _listError;
  final _tripErrors = <String, ApiException>{};

  Future<void>? _listLoad;
  final _tripLoads = <String, Future<void>>{};

  /// 여행마다 마지막 쓰기. 다음 쓰기는 이것이 끝난 뒤에 보낸다.
  final _writes = <String, Future<void>>{};

  /// 쓰기를 시작하고 끝낼 때마다 늘린다. 읽기를 시작할 때와 끝낼 때 다르면 그 결과를 버린다.
  int _writeEpoch = 0;

  int _listWatchers = 0;
  final _tripWatchers = <String, int>{};

  @override
  Stream<List<Trip>> watchTrips() => _watch(
    onListen: () {
      _listWatchers++;
      _quietly(_loadList());
    },
    onCancel: () => _listWatchers--,
    read: () => switch (_cache.list) {
      final list? => _Value(list),
      null => _failureOrLoading(_listError),
    },
  );

  @override
  Stream<Trip?> watchTrip(String id) => _watchTripPart(
    id,
    () => switch (_cache.trips[id]) {
      final trip? => _Value(trip),
      null when _cache.missing.contains(id) => const _Value(null),
      null => _failureOrLoading(_tripErrors[id]),
    },
  );

  @override
  Stream<TripRoute> watchRoute(String tripId) => _watchTripPart(
    tripId,
    () => switch (_cache.routes[tripId]) {
      final route? => _Value(route),
      null when _cache.missing.contains(tripId) => _Value(TripRoute()),
      null => _failureOrLoading(_tripErrors[tripId]),
    },
  );

  @override
  Future<void> refreshTrips() => _loadList();

  @override
  Future<void> refreshTrip(String tripId) => _loadTrip(tripId);

  @override
  void refreshWatched() {
    if (_listWatchers > 0) _quietly(_loadList());
    for (final MapEntry(key: tripId, value: count) in _tripWatchers.entries) {
      if (count > 0) _quietly(_loadTrip(tripId));
    }
  }

  @override
  Future<Trip> createTrip(Trip trip) => _write(trip.id, () async {
    final saved = await _api.createTrip(trip);
    // 새 여행에는 장소가 없다. 화면에 들어가도 동선을 받지 않아도 된다.
    _cache.putTrip(saved, route: TripRoute());
    _changed();
    return saved;
  });

  @override
  Future<Trip> updateTrip(Trip trip) => _write(trip.id, () async {
    final saved = await _api.updateTrip(trip);
    _cache.putTrip(saved);
    _changed();
    return saved;
  });

  @override
  Future<void> trashTrip(String tripId) => _write(tripId, () async {
    try {
      await _api.trashTrip(tripId);
    } on ApiException catch (error) {
      // 이미 없다(다른 기기에서 지웠다). 옮긴 것으로 본다.
      if (error.failure != ApiFailure.notFound) rethrow;
    }
    _cache.markMissing(tripId);
    _changed();
  });

  /// 휴지통은 휴지통 화면에서만 보고 자주 바뀌지 않아서 기억하지 않는다.
  @override
  Future<List<TrashedTrip>> fetchTrash() => _api.listTrash();

  /// 동선은 받지 않는다. 여행을 열면 받는다.
  @override
  Future<Trip> restoreTrip(String tripId) => _write(tripId, () async {
    final trip = await _api.restoreTrip(tripId);
    _cache.putTrip(trip);
    _changed();
    return trip;
  });

  /// 목록에 없는 여행이라 기억한 값은 바꾸지 않는다.
  @override
  Future<void> deleteTripForever(String tripId) => _write(tripId, () async {
    try {
      await _api.deleteTripForever(tripId);
    } on ApiException catch (error) {
      // 이미 없다(다른 기기에서 지웠거나 보관 기간이 끝났다). 지운 것으로 본다.
      if (error.failure != ApiFailure.notFound) rethrow;
    }
  });

  @override
  Future<Stop> addStop(Stop stop) => _write(stop.tripId, () async {
    final detail = await _api.addStop(stop);
    return _putDetail(detail, stop.id);
  });

  @override
  Future<Stop> updateStop(Stop stop) => _write(stop.tripId, () async {
    final saved = await _api.updateStop(stop);
    _replaceInRoute(
      saved.tripId,
      (route) => route.copyWith(
        stops: [
          for (final old in route.stops) old.id == saved.id ? saved : old,
        ],
      ),
    );
    return saved;
  });

  @override
  Future<Stop> moveStop(
    String stopId, {
    required int day,
    required int order,
  }) => _write(_cache.tripOfStop(stopId) ?? stopId, () async {
    final detail = await _api.moveStop(stopId, day: day, order: order);
    return _putDetail(detail, stopId);
  });

  @override
  Future<void> deleteStop(String stopId) =>
      _write(_cache.tripOfStop(stopId) ?? stopId, () async {
        final detail = await _api.deleteStop(stopId);
        _cache.putTrip(detail.trip, route: detail.route);
        _changed();
      });

  @override
  Future<Segment> updateSegment(Segment segment) => _write(
    segment.tripId,
    () async {
      final saved = await _api.updateSegment(segment);
      _replaceInRoute(
        saved.tripId,
        (route) => route.copyWith(
          segments: [
            for (final old in route.segments) old.id == saved.id ? saved : old,
          ],
        ),
      );
      return saved;
    },
  );

  @override
  Future<Candidate> addCandidate(Candidate candidate) =>
      _write(candidate.tripId, () async {
        final saved = await _api.addCandidate(candidate);
        _replaceInRoute(
          saved.tripId,
          (route) => route.copyWith(
            candidates: [
              for (final old in route.candidates)
                if (old.id != saved.id) old,
              saved,
            ],
          ),
        );
        return saved;
      });

  @override
  Future<Candidate> updateCandidate(Candidate candidate) =>
      _write(candidate.tripId, () async {
        final saved = await _api.updateCandidate(candidate);
        _replaceInRoute(
          saved.tripId,
          (route) => route.copyWith(
            candidates: [
              for (final old in route.candidates)
                old.id == saved.id ? saved : old,
            ],
          ),
        );
        return saved;
      });

  @override
  Future<void> deleteCandidate(String candidateId) {
    final tripId = _cache.tripOfCandidate(candidateId);
    return _write(tripId ?? candidateId, () async {
      await _api.deleteCandidate(candidateId);
      if (tripId == null) return;
      _replaceInRoute(
        tripId,
        (route) => route.copyWith(
          candidates: [
            for (final old in route.candidates)
              if (old.id != candidateId) old,
          ],
        ),
      );
    });
  }

  @override
  Future<Stop> promoteCandidate(Stop stop) => _write(stop.tripId, () async {
    final detail = await _api.promoteCandidate(stop);
    return _putDetail(detail, stop.id);
  });

  @override
  Future<Candidate> demoteStop(String stopId) =>
      _write(_cache.tripOfStop(stopId) ?? stopId, () async {
        final detail = await _api.demoteStop(stopId);
        _cache.putTrip(detail.trip, route: detail.route);
        _changed();
        return detail.route.candidateById(stopId) ??
            (throw const ApiException(ApiFailure.server));
      });

  void dispose() => _changes.close();

  Stop _putDetail(TripDetail detail, String stopId) {
    _cache.putTrip(detail.trip, route: detail.route);
    _changed();
    return detail.route.stopById(stopId) ??
        (throw const ApiException(ApiFailure.server));
  }

  /// 장소·구간 하나를 바꾼 응답을 동선에 넣고, 여행의 고친 시각을 앱 시각으로 맞춘다.
  void _replaceInRoute(String tripId, TripRoute Function(TripRoute) replace) {
    final route = _cache.routes[tripId];
    if (route != null) _cache.routes[tripId] = replace(route);
    final trip = _cache.trips[tripId];
    if (trip != null) {
      _cache.trips[tripId] = trip.copyWith(updatedAt: clock().toUtc());
    }
    _changed();
  }

  Stream<T> _watchTripPart<T>(String tripId, _Snapshot<T>? Function() read) =>
      _watch(
        onListen: () {
          _tripWatchers[tripId] = (_tripWatchers[tripId] ?? 0) + 1;
          _quietly(_loadTrip(tripId));
        },
        onCancel: () => _tripWatchers[tripId] = _tripWatchers[tripId]! - 1,
        read: read,
      );

  _Snapshot<T>? _failureOrLoading<T>(ApiException? error) =>
      error == null ? null : _Failure(error);

  /// 구독하자마자 지금 값을 내고, 저장소가 바뀔 때마다 다시 낸다. 아직 받는 중이면 내지 않는다.
  /// [onListen]이 [read]보다 먼저다. 받기를 시작하면 지난 실패가 지워져서 처음에는 오류 대신 기다린다.
  Stream<T> _watch<T>({
    required _Snapshot<T>? Function() read,
    required void Function() onListen,
    required void Function() onCancel,
  }) {
    StreamSubscription<void>? changes;
    late final StreamController<T> controller;
    void emit() {
      switch (read()) {
        case _Value(:final value):
          controller.add(value);
        case _Failure(:final error):
          controller.addError(error);
        case null:
      }
    }

    controller = StreamController<T>(
      onListen: () {
        onListen();
        emit();
        changes = _changes.stream.listen((_) => emit());
      },
      onCancel: () {
        onCancel();
        return changes?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _loadList() => _listLoad ??= () async {
    final epoch = _writeEpoch;
    _listError = null;
    var again = false;
    try {
      final list = await _api.listTrips();
      if (epoch != _writeEpoch) {
        // 쓰기와 겹쳤다. 목록이 아직 없으면 다시 받는다.
        again = _cache.listIds == null;
        return;
      }
      _cache.putList(list);
    } on ApiException catch (error) {
      if (_cache.listIds == null) _listError = error;
      rethrow;
    } finally {
      _listLoad = null;
      _changed();
      if (again) _quietly(_loadList());
    }
  }();

  Future<void> _loadTrip(String tripId) => _tripLoads[tripId] ??= () async {
    final epoch = _writeEpoch;
    _tripErrors.remove(tripId);
    var again = false;
    try {
      final TripDetail detail;
      try {
        detail = await _api.getTrip(tripId);
      } on ApiException catch (error) {
        if (error.failure != ApiFailure.notFound) rethrow;
        _cache.markMissing(tripId);
        return;
      }
      if (epoch != _writeEpoch) {
        again = !_cache.routes.containsKey(tripId);
        return;
      }
      _cache.putTrip(detail.trip, route: detail.route);
    } on ApiException catch (error) {
      if (!_cache.routes.containsKey(tripId)) _tripErrors[tripId] = error;
      rethrow;
    } finally {
      _tripLoads.remove(tripId);
      _changed();
      if (again) _quietly(_loadTrip(tripId));
    }
  }();

  /// [tripId] 여행의 쓰기를 앞 쓰기가 끝난 뒤에 보낸다.
  Future<T> _write<T>(String tripId, Future<T> Function() send) {
    final previous = _writes[tripId];
    final result = () async {
      if (previous != null) await previous;
      _writeEpoch++;
      ApiException? failure;
      try {
        return await send();
      } on ApiException catch (error) {
        failure = error;
        rethrow;
      } finally {
        _writeEpoch++;
        if (failure != null && failure.failure != ApiFailure.unauthorized) {
          _reloadAfterFailure(tripId);
        }
      }
    }();
    final done = result.then<void>((_) {}, onError: (_) {});
    _writes[tripId] = done;
    unawaited(
      done.whenComplete(() {
        if (identical(_writes[tripId], done)) _writes.remove(tripId);
      }),
    );
    return result;
  }

  void _reloadAfterFailure(String tripId) {
    final known =
        _cache.trips.containsKey(tripId) || _cache.missing.contains(tripId);
    _quietly(known ? _loadTrip(tripId) : _loadList());
  }

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// 뒤에서 받는 것이라 실패를 버린다. 처음 받는 실패는 스트림이 오류로 알린다.
  static void _quietly(Future<void> load) =>
      unawaited(load.catchError((Object _) {}, test: (e) => e is ApiException));
}

sealed class _Snapshot<T> {
  const _Snapshot();
}

class _Value<T> extends _Snapshot<T> {
  const _Value(this.value);

  final T value;
}

class _Failure<T> extends _Snapshot<T> {
  const _Failure(this.error);

  final ApiException error;
}
