import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trashed_trip.dart';
import '../models/trip.dart';
import '../models/trip_route.dart';
import '../trips/trip_repository.dart';
import 'jeju_sample.dart';
import 'sample_store.dart';

/// 사용자의 저장소([inner])에 샘플 여행을 하나 더해 보여 준다. 샘플은 서버에 없다.
///
/// - 목록: 사용자의 여행 뒤에 샘플을 붙인다. 숨겼는지 아직 모르면 붙이지 않는다(보였다 사라지는 것보다 낫다).
/// - 샘플은 보기만 된다. 고치려 하면 [StateError]다(화면이 고칠 곳을 보여 주지 않는다).
/// - 샘플을 지우면 숨기고 [SampleStore]에 기억한다. 내 여행으로 쓴 뒤에도 지운다(`copySample`).
/// - 그 밖의 여행은 모두 [inner]가 처리한다.
class SampleTripRepository implements TripRepository {
  SampleTripRepository({
    required this._inner,
    required this._store,
    required this._sample,
  }) {
    _store.isHidden().then((hidden) {
      _hidden ??= hidden;
      _changed();
    });
  }

  final TripRepository _inner;
  final SampleStore _store;
  final SampleTrip _sample;

  /// 숨겼는지. 아직 모르면 null이다.
  bool? _hidden;

  final _changes = StreamController<void>.broadcast();

  bool get _shown => _hidden == false;

  @override
  Stream<List<Trip>> watchTrips() {
    List<Trip>? last;
    StreamSubscription<List<Trip>>? trips;
    StreamSubscription<void>? changes;
    late final StreamController<List<Trip>> controller;
    void emit() {
      if (last case final list?) {
        controller.add(_shown ? [...list, _sample.trip] : list);
      }
    }

    controller = StreamController(
      onListen: () {
        trips = _inner.watchTrips().listen((list) {
          last = list;
          emit();
        }, onError: controller.addError);
        changes = _changes.stream.listen((_) => emit());
      },
      onCancel: () async {
        await trips?.cancel();
        await changes?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<Trip?> watchTrip(String id) {
    if (!isSampleTrip(id)) return _inner.watchTrip(id);
    late final StreamController<Trip?> controller;
    StreamSubscription<void>? changes;
    void emit() {
      if (_hidden != null) controller.add(_shown ? _sample.trip : null);
    }

    controller = StreamController(
      onListen: () {
        emit();
        changes = _changes.stream.listen((_) => emit());
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<TripRoute> watchRoute(String tripId) => isSampleTrip(tripId)
      ? Stream.value(_sample.route)
      : _inner.watchRoute(tripId);

  @override
  Future<Trip> createTrip(Trip trip) async =>
      _inner.createTrip(_mine(trip.id, trip));

  @override
  Future<Trip> updateTrip(Trip trip) async =>
      _inner.updateTrip(_mine(trip.id, trip));

  /// 샘플은 휴지통에 넣지 않고 이 기기에서 숨긴다.
  @override
  Future<void> trashTrip(String tripId) async {
    if (!isSampleTrip(tripId)) return _inner.trashTrip(tripId);
    _hidden = true;
    _changed();
    await _store.hide();
  }

  @override
  Future<List<TrashedTrip>> fetchTrash() => _inner.fetchTrash();

  @override
  Future<Trip> restoreTrip(String tripId) => _inner.restoreTrip(tripId);

  @override
  Future<void> deleteTripForever(String tripId) =>
      _inner.deleteTripForever(tripId);

  @override
  Future<Stop> addStop(Stop stop) async =>
      _inner.addStop(_mine(stop.tripId, stop));

  @override
  Future<Stop> updateStop(Stop stop) async =>
      _inner.updateStop(_mine(stop.tripId, stop));

  @override
  Future<Stop> moveStop(
    String stopId, {
    required int day,
    required int order,
  }) async => _inner.moveStop(_mineStop(stopId), day: day, order: order);

  @override
  Future<void> deleteStop(String stopId) async =>
      _inner.deleteStop(_mineStop(stopId));

  @override
  Future<Segment> updateSegment(Segment segment) async =>
      _inner.updateSegment(_mine(segment.tripId, segment));

  @override
  Future<void> refreshTrips() => _inner.refreshTrips();

  @override
  Future<void> refreshTrip(String tripId) async {
    if (!isSampleTrip(tripId)) await _inner.refreshTrip(tripId);
  }

  @override
  void refreshWatched() => _inner.refreshWatched();

  void dispose() => _changes.close();

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// 샘플이 아니면 [value]를 그대로 돌려준다. 샘플이면 던진다.
  T _mine<T>(String tripId, T value) {
    if (isSampleTrip(tripId)) throw StateError('샘플 여행은 고칠 수 없습니다');
    return value;
  }

  String _mineStop(String stopId) {
    if (_sample.route.stopById(stopId) != null) {
      throw StateError('샘플 여행은 고칠 수 없습니다');
    }
    return stopId;
  }
}

/// 앱에 담아 둔 샘플 여행. 글자는 앱 언어다.
final sampleTripProvider = Provider<SampleTrip>(
  (ref) => jejuSample(ref.watch(l10nProvider)),
);
