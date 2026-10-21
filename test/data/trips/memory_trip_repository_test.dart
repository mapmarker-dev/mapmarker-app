import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';

import '../../helpers/test_stops.dart';

Trip _trip(String id, {String title = '부산 2박 3일 봄 여행'}) {
  final placeholder = DateTime.utc(2000);
  return Trip(
    id: id,
    title: title,
    region: '부산',
    nights: 2,
    season: Season.spring,
    createdAt: placeholder,
    updatedAt: placeholder,
  );
}

void main() {
  late DateTime now;
  late MemoryTripRepository repository;

  setUp(() {
    now = DateTime.utc(2026, 10, 15, 9);
    repository = MemoryTripRepository(clock: () => now);
  });

  tearDown(() => repository.dispose());

  test('stamps created and updated times when creating', () async {
    final saved = await repository.createTrip(_trip('a'));

    expect(saved.createdAt, now);
    expect(saved.updatedAt, now);
  });

  test('refuses to create the same trip twice', () async {
    await repository.createTrip(_trip('a'));

    expect(repository.createTrip(_trip('a')), throwsStateError);
  });

  test('lists the most recently changed trip first', () async {
    await repository.createTrip(_trip('a'));
    now = now.add(const Duration(minutes: 1));
    await repository.createTrip(_trip('b'));

    expect((await repository.watchTrips().first).map((t) => t.id), ['b', 'a']);

    now = now.add(const Duration(minutes: 1));
    final a = (await repository.watchTrip('a').first)!;
    await repository.updateTrip(a.copyWith(title: '새 제목'));

    expect((await repository.watchTrips().first).map((t) => t.id), ['a', 'b']);
  });

  test('keeps the created time when updating', () async {
    final created = await repository.createTrip(_trip('a'));
    now = now.add(const Duration(hours: 1));

    final updated = await repository.updateTrip(
      created.copyWith(createdAt: DateTime.utc(1999)),
    );

    expect(updated.createdAt, created.createdAt);
    expect(updated.updatedAt, now);
  });

  test('refuses to update a trip that does not exist', () {
    expect(repository.updateTrip(_trip('missing')), throwsStateError);
  });

  test('emits the trip list again after each change', () async {
    final lists = repository.watchTrips().map((trips) => trips.length);
    final expectation = expectLater(lists, emitsInOrder([0, 1, 2]));

    await repository.createTrip(_trip('a'));
    await repository.createTrip(_trip('b'));
    await expectation;
  });

  test('emits null for a trip that does not exist', () async {
    expect(await repository.watchTrip('missing').first, isNull);
  });

  test('emits a trip again after it changes', () async {
    await repository.createTrip(_trip('a'));
    final titles = repository.watchTrip('a').map((trip) => trip?.title);
    final expectation = expectLater(
      titles,
      emitsInOrder(['부산 2박 3일 봄 여행', '새 제목']),
    );

    final a = (await repository.watchTrip('a').first)!;
    await repository.updateTrip(a.copyWith(title: '새 제목'));
    await expectation;
  });

  test('starts with the seed trips', () async {
    final seeded = MemoryTripRepository(seed: [_trip('a'), _trip('b')]);
    addTearDown(seeded.dispose);

    expect(await seeded.watchTrips().first, hasLength(2));
  });

  group('route', () {
    // 2박 3일 여행.
    setUp(() async => repository.createTrip(_trip('trip')));

    Future<TripRoute> route() => repository.watchRoute('trip').first;

    /// 일차별 장소. 예: `['1: a b', '2: c']`.
    Future<List<String>> days() async {
      final stops = (await route()).stops;
      return [
        for (final day in {for (final s in stops) s.day})
          '$day: ${stops.where((s) => s.day == day).map((s) => s.id).join(' ')}',
      ];
    }

    Future<List<String>> lines() async => [
      for (final s in (await route()).segments) '${s.fromStopId}>${s.toStopId}',
    ];

    Future<List<int>> orders() async => [
      for (final s in (await route()).stops) s.order,
    ];

    test('is empty for a trip without stops or a missing trip', () async {
      expect((await route()).stops, isEmpty);
      expect((await repository.watchRoute('missing').first).stops, isEmpty);
    });

    test('starts with the seed stops in order and linked', () async {
      final seeded = MemoryTripRepository(
        seed: [_trip('trip')],
        seedStops: [
          testStop('c', day: 2, order: 7),
          testStop('b', order: 5),
          testStop('a', order: 2),
        ],
      );
      addTearDown(seeded.dispose);

      final route = await seeded.watchRoute('trip').first;

      expect(route.stops.map((s) => '${s.id}${s.day}${s.order}'), [
        'a10',
        'b11',
        'c20',
      ]);
      expect(route.segments.map((s) => '${s.fromStopId}>${s.toStopId}'), [
        'a>b',
        'b>c',
      ]);
    });

    test('keeps seed segments only between neighbors', () async {
      const walk = [TransportLeg(TransportMode.walk)];
      final seeded = MemoryTripRepository(
        seed: [_trip('trip')],
        seedStops: [testStop('a'), testStop('b', order: 1)],
        seedSegments: const [
          Segment(
            id: 'ab',
            tripId: 'trip',
            fromStopId: 'a',
            toStopId: 'b',
            legs: walk,
          ),
          Segment(id: 'ba', tripId: 'trip', fromStopId: 'b', toStopId: 'a'),
        ],
      );
      addTearDown(seeded.dispose);

      final route = await seeded.watchRoute('trip').first;

      expect(route.segments.map((s) => s.id), ['ab']);
      expect(route.segments.single.legs, walk);
    });

    test('adds a stop at its place in the day and links it', () async {
      await repository.addStop(testStop('a'));
      await repository.addStop(testStop('c', order: 9));
      final b = await repository.addStop(testStop('b', order: 1));
      await repository.addStop(testStop('d', day: 2));

      expect(await days(), ['1: a b c', '2: d']);
      expect(await orders(), [0, 1, 2, 0]);
      expect(b.order, 1);
      expect(await lines(), ['a>b', 'b>c', 'c>d']);
    });

    test('refuses stops it cannot place', () async {
      await repository.addStop(testStop('a'));

      expect(repository.addStop(testStop('a')), throwsStateError);
      expect(
        repository.addStop(testStop('x', tripId: 'missing')),
        throwsStateError,
      );
      // 2박 3일이라 4일차는 없다. 0일차는 모델이 막는다.
      expect(repository.addStop(testStop('x', day: 4)), throwsRangeError);
    });

    test('updates a stop but keeps its place in the route', () async {
      await repository.addStop(testStop('a'));
      await repository.addStop(testStop('b', order: 1));

      final updated = await repository.updateStop(
        testStop('a', day: 3, order: 5).copyWith(name: '경복궁'),
      );

      expect(updated.name, '경복궁');
      expect(await days(), ['1: a b']);
      expect(repository.updateStop(testStop('missing')), throwsStateError);
      expect(
        repository.updateStop(testStop('a', tripId: 'other')),
        throwsArgumentError,
      );
    });

    test('moves a stop within a day and to another day', () async {
      for (final (i, id) in ['a', 'b', 'c'].indexed) {
        await repository.addStop(testStop(id, order: i));
      }

      await repository.moveStop('c', day: 1, order: 0);
      expect(await days(), ['1: c a b']);

      final moved = await repository.moveStop('a', day: 2, order: 9);
      expect(moved.day, 2);
      expect(moved.order, 0);
      expect(await days(), ['1: c b', '2: a']);
      expect(await orders(), [0, 1, 0]);
      expect(await lines(), ['c>b', 'b>a']);
      expect(repository.moveStop('a', day: 4, order: 0), throwsRangeError);
    });

    test('links the neighbors again after a stop is deleted', () async {
      for (final (i, id) in ['a', 'b', 'c'].indexed) {
        await repository.addStop(testStop(id, order: i));
      }

      await repository.deleteStop('b');

      expect(await days(), ['1: a c']);
      expect(await orders(), [0, 1]);
      expect(await lines(), ['a>c']);
      expect(repository.deleteStop('b'), throwsStateError);
    });

    test(
      'keeps the transport of segments that still join the same stops',
      () async {
        for (final (i, id) in ['a', 'b', 'c'].indexed) {
          await repository.addStop(testStop(id, order: i));
        }
        final ab = (await route()).segments.first;
        await repository.updateSegment(
          Segment(
            id: ab.id,
            tripId: 'ignored',
            fromStopId: 'ignored',
            toStopId: 'ignored',
            legs: const [TransportLeg(TransportMode.walk)],
            curvature: 0.2,
          ),
        );

        await repository.moveStop('c', day: 2, order: 0);

        final kept = (await route()).segments.first;
        expect(kept.id, ab.id);
        expect('${kept.fromStopId}>${kept.toStopId}', 'a>b');
        expect(kept.legs, const [TransportLeg(TransportMode.walk)]);
        expect(kept.curvature, 0.2);
        expect(
          repository.updateSegment(
            const Segment(
              id: 'x',
              tripId: 'trip',
              fromStopId: 'a',
              toStopId: 'b',
            ),
          ),
          throwsStateError,
        );
      },
    );

    test('marks the trip as changed when its route changes', () async {
      now = now.add(const Duration(hours: 1));
      await repository.addStop(testStop('a'));

      expect((await repository.watchTrip('trip').first)!.updatedAt, now);
    });

    test('emits the route again after each change', () async {
      final counts = repository.watchRoute('trip').map((r) => r.stops.length);
      final expectation = expectLater(counts, emitsInOrder([0, 1, 2, 1]));

      await repository.addStop(testStop('a'));
      await repository.addStop(testStop('b', order: 1));
      await repository.deleteStop('a');
      await expectation;
    });
  });
}
