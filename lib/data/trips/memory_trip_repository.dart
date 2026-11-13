import 'dart:async';

import '../models/candidate.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trashed_trip.dart';
import '../models/trip.dart';
import '../models/trip_route.dart';
import 'route_links.dart';
import 'trip_repository.dart';

/// 메모리에만 두는 저장소. 앱을 끄면 사라진다.
/// 휴지통의 여행은 [_trashedAt]에 넣은 시각이 있다. 보관 기간이 지나도 지우지 않는다(지우는 것은 서버의 일이다).
class MemoryTripRepository implements TripRepository {
  /// 휴지통 보관 기간. 서버(`trips/trash-retention.ts`)와 같은 값이고, 이 저장소의 지울 시각에만 쓴다.
  /// 화면은 서버가 준 지울 시각만 본다.
  static const trashRetention = Duration(days: 30);

  /// [seedStops]는 일차와 순서대로 넣고, 구간은 저장소가 잇는다.
  /// [seedSegments]는 이동 수단 등을 미리 넣을 구간이다. 이웃한 장소 쌍의 구간만 남는다.
  /// [seedCandidates]는 준 순서가 넣은 순서다.
  MemoryTripRepository({
    this.clock = DateTime.now,
    Iterable<Trip> seed = const [],
    Iterable<Stop> seedStops = const [],
    Iterable<Segment> seedSegments = const [],
    Iterable<Candidate> seedCandidates = const [],
  }) {
    for (final trip in seed) {
      _trips[trip.id] = trip;
    }
    for (final candidate in seedCandidates) {
      _candidates[candidate.id] = candidate;
    }
    for (final segment in seedSegments) {
      _segments[segment.id] = segment;
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

  /// 넣은 순서다(맵이 넣은 순서를 지킨다). 후보로 뺀 장소는 지웠다가 다시 넣어 맨 뒤로 간다.
  final _candidates = <String, Candidate>{};
  final _trashedAt = <String, DateTime>{};
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Trip>> watchTrips() => _watch(() {
    final trips =
        _trips.values.where((trip) => !_trashedAt.containsKey(trip.id)).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(trips);
  });

  @override
  Stream<Trip?> watchTrip(String id) =>
      _watch(() => _trashedAt.containsKey(id) ? null : _trips[id]);

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
    final saved = _tripOf(trip.id);
    return _save(
      trip.copyWith(createdAt: saved.createdAt, updatedAt: clock().toUtc()),
    );
  }

  @override
  Stream<TripRoute> watchRoute(String tripId) => _watch(
    () => _trashedAt.containsKey(tripId) ? TripRoute() : _routeOf(tripId),
  );

  @override
  Future<Stop> addStop(Stop stop) async {
    final trip = _tripOf(stop.tripId);
    _checkNewId(stop.id);
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
  Future<void> trashTrip(String tripId) async {
    if (!_trips.containsKey(tripId) || _trashedAt.containsKey(tripId)) return;
    _trashedAt[tripId] = clock().toUtc();
    _changes.add(null);
  }

  @override
  Future<List<TrashedTrip>> fetchTrash() async => [
    for (final MapEntry(key: id, value: deletedAt)
        in _trashedAt.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
      TrashedTrip(
        trip: _trips[id]!,
        deletedAt: deletedAt,
        purgeAt: deletedAt.add(trashRetention),
      ),
  ];

  @override
  Future<Trip> restoreTrip(String tripId) async {
    if (_trashedAt.remove(tripId) == null) {
      throw StateError('휴지통에 없는 여행입니다: $tripId');
    }
    _changes.add(null);
    return _trips[tripId]!;
  }

  @override
  Future<void> deleteTripForever(String tripId) async {
    if (_trashedAt.remove(tripId) == null) return;
    _trips.remove(tripId);
    _stops.removeWhere((_, stop) => stop.tripId == tripId);
    _segments.removeWhere((_, segment) => segment.tripId == tripId);
    _candidates.removeWhere((_, candidate) => candidate.tripId == tripId);
    _changes.add(null);
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
    if (saved == null || _trashedAt.containsKey(saved.tripId)) {
      throw StateError('없는 구간입니다: ${segment.id}');
    }
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

  @override
  Future<Candidate> addCandidate(Candidate candidate) async {
    final trip = _tripOf(candidate.tripId);
    _checkNewId(candidate.id);
    _candidates[candidate.id] = candidate;
    _touch(trip.id);
    _changes.add(null);
    return candidate;
  }

  @override
  Future<Candidate> updateCandidate(Candidate candidate) async {
    final saved = _candidateOf(candidate.id);
    if (candidate.tripId != saved.tripId) {
      throw ArgumentError.value(candidate.tripId, 'tripId', '다른 여행의 후보입니다');
    }
    _candidates[candidate.id] = candidate;
    _touch(saved.tripId);
    _changes.add(null);
    return candidate;
  }

  @override
  Future<void> deleteCandidate(String candidateId) async {
    final saved = _candidateOf(candidateId);
    _candidates.remove(candidateId);
    _touch(saved.tripId);
    _changes.add(null);
  }

  @override
  Future<Stop> promoteCandidate(Stop stop) async {
    final candidate = _candidateOf(stop.id);
    final trip = _tripOf(candidate.tripId);
    _checkDay(trip, stop.day);
    _candidates.remove(candidate.id);
    final days = _daysOf(trip.id);
    final placed = Stop(
      id: candidate.id,
      tripId: trip.id,
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      name: stop.name,
      kind: stop.kind,
      day: stop.day,
      order: 0,
      description: stop.description,
      memo: stop.memo,
      plannedTime: stop.plannedTime,
      timeZone: stop.timeZone,
      placeProvider: candidate.placeProvider,
      placeId: candidate.placeId,
    );
    _insert(days, placed, stop.day, stop.order);
    _changeRoute(trip, days);
    return _stops[stop.id]!;
  }

  @override
  Future<Candidate> demoteStop(String stopId) async {
    final saved = _stopOf(stopId);
    final trip = _tripOf(saved.tripId);
    final days = _daysOf(trip.id);
    days[saved.day]!.removeWhere((stop) => stop.id == stopId);
    _stops.remove(stopId);
    final candidate = Candidate.fromStop(saved);
    _candidates[stopId] = candidate;
    _changeRoute(trip, days);
    return candidate;
  }

  /// 메모리에 있는 것이 전부라서 다시 받을 것이 없다.
  @override
  Future<void> refreshTrips() async {}

  @override
  Future<void> refreshTrip(String tripId) async {}

  @override
  void refreshWatched() {}

  void dispose() => _changes.close();

  Trip _save(Trip trip) {
    _trips[trip.id] = trip;
    _changes.add(null);
    return trip;
  }

  /// 휴지통의 여행은 없는 여행이다.
  Trip _tripOf(String tripId) => switch (_trips[tripId]) {
    final trip? when !_trashedAt.containsKey(tripId) => trip,
    _ => throw StateError('없는 여행입니다: $tripId'),
  };

  /// 휴지통 여행의 장소는 없는 장소다.
  Stop _stopOf(String stopId) => switch (_stops[stopId]) {
    final stop? when !_trashedAt.containsKey(stop.tripId) => stop,
    _ => throw StateError('없는 장소입니다: $stopId'),
  };

  /// 휴지통 여행의 후보는 없는 후보다.
  Candidate _candidateOf(String candidateId) =>
      switch (_candidates[candidateId]) {
        final candidate? when !_trashedAt.containsKey(candidate.tripId) =>
          candidate,
        _ => throw StateError('없는 후보입니다: $candidateId'),
      };

  /// 장소와 후보는 같은 ID를 주고받아서, 새 장소·후보의 ID는 어느 쪽에도 없어야 한다(서버도 409).
  void _checkNewId(String id) {
    if (_stops.containsKey(id) || _candidates.containsKey(id)) {
      throw StateError('이미 있는 장소·후보입니다: $id');
    }
  }

  void _checkDay(Trip trip, int day) =>
      RangeError.checkValueInInterval(day, 1, trip.nights + 1, 'day');

  TripRoute _routeOf(String tripId) => TripRoute(
    stops: _stops.values.where((stop) => stop.tripId == tripId),
    segments: _segments.values.where((s) => s.tripId == tripId),
    candidates: _candidates.values.where((c) => c.tripId == tripId),
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
