import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/dev/sample_trips.dart';
import 'package:mapmarker_app/features/trip_detail/transport_look.dart';
import 'package:mapmarker_app/l10n/l10n.dart';

final _l10n = lookupAppLocalizations(appLocale);

SampleTrips _samples() => sampleTrips(
  today: LocalDate(2026, 10, 15),
  now: DateTime(2026, 10, 15, 9),
  l10n: _l10n,
);

void main() {
  test('shows one trip for each phase today', () {
    for (final today in [
      LocalDate(2026, 10, 15),
      LocalDate(2027, 1, 1),
      LocalDate(2028, 2, 29),
    ]) {
      final trips = sampleTrips(
        today: today,
        now: DateTime(today.year, today.month, today.day, 9),
        l10n: _l10n,
      ).trips;

      expect(
        trips.map((trip) => trip.phaseOn(today)),
        unorderedEquals(TripPhase.values),
        reason: '$today',
      );
    }
  });

  test('uses default titles and distinct ids', () {
    final (:trips, :stops, :segments) = _samples();

    expect(trips.map((trip) => trip.title), [
      for (final trip in trips) _l10n.defaultTitleOf(trip),
    ]);
    final ids = [...trips.map((t) => t.id), ...stops.map((s) => s.id)];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('puts every stop in a day of its trip', () {
    final (:trips, :stops, :segments) = _samples();
    final tripsById = {for (final trip in trips) trip.id: trip};

    for (final stop in stops) {
      final trip = tripsById[stop.tripId];
      expect(trip, isNotNull, reason: stop.name);
      expect(
        stop.day,
        inInclusiveRange(1, trip!.nights + 1),
        reason: stop.name,
      );
    }
  });

  test('covers an empty trip, an empty day and a change of lodging', () async {
    final (:trips, :stops, :segments) = _samples();
    final repository = MemoryTripRepository(
      seed: trips,
      seedStops: stops,
      seedSegments: segments,
    );
    addTearDown(repository.dispose);
    final [jeju, gangneung, busan] = trips;

    final jejuRoute = await repository.watchRoute(jeju.id).first;
    expect({
      for (final s in jejuRoute.stops) s.kind,
    }, unorderedEquals(StopKind.values));
    expect(jejuRoute.segments, hasLength(jejuRoute.stops.length - 1));
    // 3일차는 제주시 숙소에서 나와 서귀포 숙소로 간다.
    final day3 = jejuRoute.view(day: 3).stops;
    expect(day3.first.name, '제주시 숙소');
    expect(day3.last.name, '서귀포 숙소');

    expect((await repository.watchRoute(gangneung.id).first).stops, isEmpty);

    final busanRoute = await repository.watchRoute(busan.id).first;
    expect(busanRoute.stops.where((s) => s.day == 2), isEmpty);
  });

  test(
    'shows every line style, a transfer, an undecided segment and curves',
    () async {
      final (:trips, :stops, :segments) = _samples();
      final repository = MemoryTripRepository(
        seed: trips,
        seedStops: stops,
        seedSegments: segments,
      );
      addTearDown(repository.dispose);

      final jeju = await repository.watchRoute(trips.first.id).first;
      final legs = [for (final s in jeju.segments) s.legs];

      // 미리 넣은 구간은 모두 이웃한 장소 사이라서 저장소에 남는다.
      expect(
        jeju.segments.map((s) => s.id),
        containsAll(segments.map((s) => s.id)),
      );
      final curvatures = [for (final s in jeju.segments) s.curvature];
      expect(curvatures.any((k) => k > 0), isTrue, reason: '한쪽으로 휜 곡선');
      expect(curvatures.any((k) => k < 0), isTrue, reason: '반대쪽으로 휜 곡선');
      // 이동 수단의 선 모양 3갈래. 가는 파선(숙소를 거침)은 이동 수단이 아니다.
      expect(
        {for (final l in legs) lineStyleOf(representativeMode(l))},
        unorderedEquals([
          MapLineStyle.solid,
          MapLineStyle.dashed,
          MapLineStyle.dotted,
        ]),
      );
      expect(legs.any((l) => l.length > 1), isTrue, reason: '갈아타기');
      expect(legs.any((l) => l.isEmpty), isTrue, reason: '미정');
    },
  );
}
