import 'dart:async';

import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trip.dart';
import '../models/trip_route.dart';
import 'route_links.dart';
import 'trip_repository.dart';

/// 메모리에만 두는 저장소. 앱을 끄면 사라진다.
class MemoryTripRepository implements TripRepository {
  /// [seedStops]는 일차와 순서대로 넣고, 구간은 저장소가 잇는다.
  MemoryTripRepository({
    this.clock = DateTime.now,
    Iterable<Trip> seed = const [],
    Iterable<Stop> seedStops = const [],
  }) {
    for (final trip in seed) {
      _trips[trip.id] = trip;
    }
    final daysByTrip = <String, Map<int, List<Stop>>>{};
    for (final stop in seedStops.toList()..sort(compareRouteOrder)) {
      ((daysByTrip[stop.tripId] ??= {})[stop.day] ??= []).add(stop);
    }
    for (final MapEntry(key: tripId, value: days) in daysByTrip.entries) {
      _putRoute(tripId, _numbered(days));
    }
  }

  /// 만든 시각과 고친 시각을 정할 때 쓴다.
  final DateTime Function() clock;
  final _trips = <String, Trip>{};
  final _stops = <String, Stop>{};
  final _segments = <String, Segment>{};
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

  @override
  Stream<TripRoute> watchRoute(String tripId) => _watch(() => _routeOf(tripId));

  @override
  Future<Stop> addStop(Stop stop) async {
    final trip = _tripOf(stop.tripId);
    if (_stops.containsKey(stop.id)) {
      throw StateError('이미 있는 장소입니다: ${stop.id}');
    }
    _checkDay(trip, stop.day);
    final days = _daysOf(trip.id);
    _insert(days, stop, stop.day, stop.order);
    _changeRoute(trip, days);
    return _stops[stop.id]!;
  }

  @override
  Future<Stop> updateStop(Stop stop) async {
    final saved = _stopOf(stop.id);
    if (stop.tripId != saved.tripId) {
      throw ArgumentError.value(stop.tripId, 'tripId', '다른 여행의 장소입니다');
    }
    _stops[stop.id] = stop.copyWith(day: saved.day, order: saved.order);
    _touch(saved.tripId);
    _changes.add(null);
    return _stops[stop.id]!;
  }

  @override
  Future<Stop> moveStop(
    String stopId, {
    required int day,
    required int order,
  }) async {
    final saved = _stopOf(stopId);
    final trip = _tripOf(saved.tripId);
    _checkDay(trip, day);
    final days = _daysOf(trip.id);
    days[saved.day]!.removeWhere((stop) => stop.id == stopId);
    _insert(days, saved, day, order);
    _changeRoute(trip, days);
    return _stops[stopId]!;
  }

  @override
  Future<void> deleteStop(String stopId) async {
    final saved = _stopOf(stopId);
    final trip = _tripOf(saved.tripId);
    final days = _daysOf(trip.id);
    days[saved.day]!.removeWhere((stop) => stop.id == stopId);
    _stops.remove(stopId);
    _changeRoute(trip, days);
  }

  @override
  Future<Segment> updateSegment(Segment segment) async {
    final saved = _segments[segment.id];
    if (saved == null) throw StateError('없는 구간입니다: ${segment.id}');
    final updated = Segment(
      id: saved.id,
      tripId: saved.tripId,
      fromStopId: saved.fromStopId,
      toStopId: saved.toStopId,
      legs: List.unmodifiable(segment.legs),
      curvature: segment.curvature,
      type: segment.type,
    );
    _segments[saved.id] = updated;
    _touch(saved.tripId);
    _changes.add(null);
    return updated;
  }

  void dispose() => _changes.close();

  Trip _save(Trip trip) {
    _trips[trip.id] = trip;
    _changes.add(null);
    return trip;
  }

  Trip _tripOf(String tripId) =>
      _trips[tripId] ?? (throw StateError('없는 여행입니다: $tripId'));

  Stop _stopOf(String stopId) =>
      _stops[stopId] ?? (throw StateError('없는 장소입니다: $stopId'));

  void _checkDay(Trip trip, int day) =>
      RangeError.checkValueInInterval(day, 1, trip.nights + 1, 'day');

  TripRoute _routeOf(String tripId) => TripRoute(
    stops: _stops.values.where((stop) => stop.tripId == tripId),
    segments: _segments.values.where((s) => s.tripId == tripId),
  );

  /// 여행의 장소를 일차별 목록으로. 목록 안은 순서대로다.
  Map<int, List<Stop>> _daysOf(String tripId) {
    final days = <int, List<Stop>>{};
    for (final stop in _routeOf(tripId).stops) {
      (days[stop.day] ??= []).add(stop);
    }
    return days;
  }

  void _insert(Map<int, List<Stop>> days, Stop stop, int day, int order) {
    final list = days[day] ??= [];
    list.insert(order.clamp(0, list.length), stop.copyWith(day: day));
  }

  void _changeRoute(Trip trip, Map<int, List<Stop>> days) {
    _putRoute(trip.id, _numbered(days));
    _touch(trip.id);
    _changes.add(null);
  }

  /// 일차별 목록을 동선 순서로 늘어놓고, 순서를 일차마다 0부터 빈칸 없이 다시 매긴다.
  static List<Stop> _numbered(Map<int, List<Stop>> days) => [
    for (final day in days.keys.toList()..sort())
      for (final (order, stop) in days[day]!.indexed)
        stop.copyWith(order: order),
  ];

  /// 여행의 장소를 [stops](동선 순서, 순서 번호 매김 끝)로 바꾸고 구간을 다시 잇는다.
  void _putRoute(String tripId, List<Stop> stops) {
    final existing = _segments.values.where((s) => s.tripId == tripId).toList();
    _stops.removeWhere((_, stop) => stop.tripId == tripId);
    _segments.removeWhere((_, segment) => segment.tripId == tripId);
    for (final stop in stops) {
      _stops[stop.id] = stop;
    }
    for (final segment in linkStops(
      tripId: tripId,
      stops: stops,
      existing: existing,
    )) {
      _segments[segment.id] = segment;
    }
  }

  /// 장소나 구간이 바뀌면 여행도 고친 것으로 본다.
  void _touch(String tripId) {
    final trip = _trips[tripId];
    if (trip == null) return;
    _trips[tripId] = trip.copyWith(updatedAt: clock().toUtc());
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
