import 'dart:async';

import '../models/trip.dart';
import 'trip_repository.dart';

/// 메모리에만 두는 저장소. 앱을 끄면 사라진다.
class MemoryTripRepository implements TripRepository {
  MemoryTripRepository({
    this.clock = DateTime.now,
    Iterable<Trip> seed = const [],
  }) {
    for (final trip in seed) {
      _trips[trip.id] = trip;
    }
  }

  /// 만든 시각과 고친 시각을 정할 때 쓴다.
  final DateTime Function() clock;
  final _trips = <String, Trip>{};
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Trip>> watchTrips() => _watch(() {
    final trips = _trips.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(trips);
  });

  @override
  Stream<Trip?> watchTrip(String id) => _watch(() => _trips[id]);

  @override
  Future<Trip> createTrip(Trip trip) async {
    if (_trips.containsKey(trip.id)) {
      throw StateError('이미 있는 여행입니다: ${trip.id}');
    }
    final now = clock().toUtc();
    return _save(trip.copyWith(createdAt: now, updatedAt: now));
  }

  @override
  Future<Trip> updateTrip(Trip trip) async {
    final saved = _trips[trip.id];
    if (saved == null) throw StateError('없는 여행입니다: ${trip.id}');
    return _save(
      trip.copyWith(createdAt: saved.createdAt, updatedAt: clock().toUtc()),
    );
  }

  void dispose() => _changes.close();

  Trip _save(Trip trip) {
    _trips[trip.id] = trip;
    _changes.add(null);
    return trip;
  }

  /// 구독하자마자 지금 값을 내고, 저장소가 바뀔 때마다 새 값을 낸다.
  Stream<T> _watch<T>(T Function() read) {
    StreamSubscription<void>? changes;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        changes = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }
}
