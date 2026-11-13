import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
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

  group('trash', () {
    setUp(() async {
      await repository.createTrip(_trip('a'));
      await repository.addStop(testStop('s1', tripId: 'a'));
      await repository.addStop(testStop('s2', tripId: 'a', order: 1));
      now = now.add(const Duration(hours: 1));
      await repository.createTrip(_trip('b'));
    });

    test('moves a trip to the trash and hides it with its route', () async {
      now = DateTime.utc(2026, 11, 10, 8, 30);
      await repository.trashTrip('a');

      final trips = await repository.watchTrips().first;
      expect(trips.map((t) => t.id), ['b']);
      expect(await repository.watchTrip('a').first, isNull);
      expect((await repository.watchRoute('a').first).stops, isEmpty);
      final trash = await repository.fetchTrash();
      expect(trash.single.trip.id, 'a');
      expect(trash.single.deletedAt, DateTime.utc(2026, 11, 10, 8, 30));
      expect(trash.single.purgeAt, DateTime.utc(2026, 12, 10, 8, 30));
      expect(
        () => repository.addStop(testStop('s3', tripId: 'a')),
        throwsStateError,
      );
      // 이미 휴지통에 있거나 없는 여행이어도 된다.
      await repository.trashTrip('a');
      await repository.trashTrip('nope');
    });

    test('lists the trash with the latest trashed first', () async {
      await repository.trashTrip('a');
      now = now.add(const Duration(minutes: 1));
      await repository.trashTrip('b');

      final trash = await repository.fetchTrash();

      expect(trash.map((t) => t.trip.id), ['b', 'a']);
    });

    test('restores a trip to its old place with its route', () async {
      await repository.trashTrip('a');

      final restored = await repository.restoreTrip('a');

      expect(restored.id, 'a');
      final trips = await repository.watchTrips().first;
      expect(trips.map((t) => t.id), ['b', 'a']);
      expect((await repository.watchRoute('a').first).stops, hasLength(2));
      expect(await repository.fetchTrash(), isEmpty);
      expect(() => repository.restoreTrip('b'), throwsStateError);
    });

    test('deletes a trashed trip for good', () async {
      await repository.trashTrip('a');

      await repository.deleteTripForever('a');

      expect(await repository.fetchTrash(), isEmpty);
      expect(() => repository.restoreTrip('a'), throwsStateError);
      // 휴지통에 없는 여행은 지우지 않는다. 없는 여행은 지운 것으로 본다.
      await repository.deleteTripForever('b');
      await repository.deleteTripForever('nope');
      expect((await repository.watchTrips().first).map((t) => t.id), ['b']);
    });
  });

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

  group('candidates', () {
    // 2박 3일 여행.
    setUp(() async => repository.createTrip(_trip('trip')));

    Future<TripRoute> route() => repository.watchRoute('trip').first;

    Future<List<String>> candidateIds() async => [
      for (final c in (await route()).candidates) c.id,
    ];

    Future<List<String>> lines() async => [
      for (final s in (await route()).segments) '${s.fromStopId}>${s.toStopId}',
    ];

    Candidate candidate(String id, {String tripId = 'trip'}) => Candidate(
      id: id,
      tripId: tripId,
      latitude: 33.5,
      longitude: 126.9,
      name: id,
    );

    test(
      'keeps candidates in the order they were added, outside the route',
      () async {
        await repository.addStop(testStop('a'));
        await repository.addCandidate(candidate('x'));
        await repository.addCandidate(candidate('y'));

        expect(await candidateIds(), ['x', 'y']);
        expect((await route()).stops.map((s) => s.id), ['a']);
      },
    );

    test('updates and deletes a candidate in place', () async {
      await repository.addCandidate(candidate('x'));
      await repository.addCandidate(candidate('y'));

      await repository.updateCandidate(candidate('x').copyWith(name: '우도'));
      expect((await route()).candidateById('x')?.name, '우도');
      expect(await candidateIds(), ['x', 'y']);

      await repository.deleteCandidate('x');
      expect(await candidateIds(), ['y']);
    });

    test('refuses an ID a stop or candidate already has', () async {
      await repository.addStop(testStop('a'));
      await repository.addCandidate(candidate('x'));

      expect(() => repository.addCandidate(candidate('a')), throwsStateError);
      expect(() => repository.addCandidate(candidate('x')), throwsStateError);
      expect(() => repository.addStop(testStop('x')), throwsStateError);
      expect(
        () => repository.addCandidate(candidate('z', tripId: 'nope')),
        throwsStateError,
      );
    });

    test('promotes a candidate into its place with the same ID', () async {
      await repository.addStop(testStop('a'));
      await repository.addStop(testStop('b', order: 1));
      await repository.addCandidate(candidate('x'));
      now = now.add(const Duration(hours: 1));

      final placed = await repository.promoteCandidate(
        testStop('x', order: 1).copyWith(name: '우도', kind: StopKind.tour),
      );

      expect(placed.id, 'x');
      expect(placed.name, '우도');
      // 좌표는 후보의 것이다.
      expect(placed.latitude, 33.5);
      expect((await route()).stops.map((s) => s.id), ['a', 'x', 'b']);
      expect(await lines(), ['a>x', 'x>b']);
      expect(await candidateIds(), isEmpty);
      expect((await repository.watchTrip('trip').first)!.updatedAt, now);
    });

    test('refuses to promote what it cannot place', () async {
      await repository.addCandidate(candidate('x'));

      expect(
        () => repository.promoteCandidate(testStop('x', day: 4)),
        throwsRangeError,
      );
      expect(
        () => repository.promoteCandidate(testStop('nope')),
        throwsStateError,
      );
      expect(await candidateIds(), ['x']);
    });

    test(
      'demotes a stop to the end of the candidates and relinks its neighbors',
      () async {
        await repository.addCandidate(candidate('x'));
        await repository.addStop(testStop('a'));
        await repository.addStop(testStop('b', order: 1));
        await repository.addStop(testStop('c', order: 2));

        final demoted = await repository.demoteStop('b');

        expect(demoted.id, 'b');
        expect((await route()).stops.map((s) => s.id), ['a', 'c']);
        expect(await lines(), ['a>c']);
        expect(await candidateIds(), ['x', 'b']);
      },
    );

    test('a demoted stop comes back with the same ID', () async {
      await repository.addStop(testStop('a'));
      await repository.demoteStop('a');

      await repository.promoteCandidate(testStop('a'));

      expect((await route()).stops.single.id, 'a');
      expect(await candidateIds(), isEmpty);
    });

    test(
      'hides candidates of a trashed trip and deletes them for good with it',
      () async {
        await repository.addCandidate(candidate('x'));
        await repository.trashTrip('trip');

        expect((await route()).candidates, isEmpty);
        expect(() => repository.deleteCandidate('x'), throwsStateError);

        await repository.restoreTrip('trip');
        expect(await candidateIds(), ['x']);

        await repository.trashTrip('trip');
        await repository.deleteTripForever('trip');
        await repository.createTrip(_trip('trip'));
        expect(await candidateIds(), isEmpty);
      },
    );
  });
}
